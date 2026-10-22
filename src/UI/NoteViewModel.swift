import Foundation
import SwiftUI
import Combine

class NoteViewModel: ObservableObject {
    @Published var notebooks: [Notebook] = []
    @Published var currentNotebook: Notebook?
    @Published var allNotes: [Note] = []
    @Published var selectedNote: Note? = nil
    @Published var searchQuery: String = ""
    @Published var syncState: SyncState = .idle
    @Published var settings: AppSettings = AppSettings()
    @Published var isSettingsOpen: Bool = false
    @Published var isCreatingNotebookOpen: Bool = false
    @Published var newNotebookName: String = ""

    private var autoSaveCancellable: AnyCancellable?
    private let storage = StorageManager.shared
    private let syncEngine = YinxiangSyncEngine.shared

    init() {
        self.settings = storage.loadSettings()
        loadLocalData()

        if settings.autoSyncOnLaunch && !settings.evernoteToken.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.syncWithYinxiang()
            }
        }
    }

    func loadLocalData() {
        let (storedNotebooks, storedNotes) = storage.loadData()
        self.notebooks = storedNotebooks
        self.allNotes = storedNotes

        // Set default notebook
        if let found = notebooks.first(where: { $0.guid == settings.selectedNotebookGuid }) {
            self.currentNotebook = found
        } else if let def = notebooks.first(where: { $0.isDefault }) {
            self.currentNotebook = def
        } else {
            self.currentNotebook = notebooks.first
        }
    }

    func saveLocalData() {
        storage.saveData(notebooks: notebooks, notes: allNotes)
    }

    // MARK: - Computed Filtered Notes
    var filteredNotes: [Note] {
        guard let current = currentNotebook else { return [] }
        var list = allNotes.filter { $0.notebookGuid == current.guid }

        if !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchQuery.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) || $0.content.lowercased().contains(q)
            }
        }

        // Pinned notes first, then latest updated
        return list.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    // MARK: - Notebook Actions
    func selectNotebook(_ nb: Notebook) {
        self.currentNotebook = nb
        self.settings.selectedNotebookGuid = nb.guid
        storage.saveSettings(self.settings)
        self.selectedNote = nil

        // Sync notes for newly selected notebook if token exists
        if !settings.evernoteToken.isEmpty {
            syncNotesForCurrentNotebook()
        }
    }

    func createNewNotebook(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Local creation
        let newNb = Notebook(guid: UUID().uuidString, name: trimmed, isDefault: false)
        self.notebooks.append(newNb)
        self.selectNotebook(newNb)
        self.saveLocalData()

        // Sync to cloud
        if !settings.evernoteToken.isEmpty {
            Task {
                do {
                    let cloudNb = try await syncEngine.createNotebook(
                        token: settings.evernoteToken,
                        china: settings.serviceType.isChina,
                        name: trimmed
                    )
                    await MainActor.run {
                        if let idx = self.notebooks.firstIndex(where: { $0.id == newNb.id }) {
                            self.notebooks[idx] = cloudNb
                            if self.currentNotebook?.id == newNb.id {
                                self.currentNotebook = cloudNb
                            }
                            self.saveLocalData()
                        }
                    }
                } catch {
                    print("Failed to create notebook in cloud: \(error)")
                }
            }
        }
    }

    // MARK: - Note Actions
    func createNewNote() {
        guard let current = currentNotebook else { return }

        let newNote = Note(
            guid: UUID().uuidString,
            title: "新笔记",
            content: "",
            notebookGuid: current.guid,
            updatedAt: Date(),
            color: .gray,
            isPinned: false,
            isDirty: true
        )

        self.allNotes.insert(newNote, at: 0)
        self.selectedNote = newNote
        self.saveLocalData()
    }

    func updateNote(_ note: Note) {
        guard let idx = allNotes.firstIndex(where: { $0.id == note.id }) else { return }
        var updated = note
        updated.updatedAt = Date()
        updated.isDirty = true
        allNotes[idx] = updated

        if selectedNote?.id == note.id {
            selectedNote = updated
        }

        saveLocalData()

        // Debounced sync if token available
        debounceSaveToCloud(updated)
    }

    func deleteNote(_ note: Note) {
        allNotes.removeAll(where: { $0.id == note.id })
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
        saveLocalData()

        if !settings.evernoteToken.isEmpty {
            Task {
                try? await syncEngine.deleteNote(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    guid: note.guid
                )
            }
        }
    }

    func setNoteColor(_ note: Note, color: NoteColor) {
        var copy = note
        copy.color = color
        updateNote(copy)
    }

    func togglePinNote(_ note: Note) {
        var copy = note
        copy.isPinned.toggle()
        updateNote(copy)
    }

    // MARK: - Cloud Sync
    private var saveTask: Task<Void, Never>?

    private func debounceSaveToCloud(_ note: Note) {
        guard !settings.evernoteToken.isEmpty else { return }

        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s debounce
            guard !Task.isCancelled else { return }

            do {
                let saved = try await syncEngine.saveNote(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    note: note
                )
                await MainActor.run {
                    if let idx = self.allNotes.firstIndex(where: { $0.id == note.id }) {
                        self.allNotes[idx].guid = saved.guid
                        self.allNotes[idx].updatedAt = saved.updated
                        self.allNotes[idx].isDirty = false
                        if self.selectedNote?.id == note.id {
                            self.selectedNote = self.allNotes[idx]
                        }
                        self.saveLocalData()
                    }
                }
            } catch {
                print("Auto-save to cloud failed: \(error)")
            }
        }
    }

    func syncWithYinxiang() {
        guard !settings.evernoteToken.isEmpty else {
            self.syncState = .failed(error: "请在设置中配置 Token")
            return
        }

        self.syncState = .syncing(message: "正在连接印象笔记...")

        Task {
            do {
                // 1. Fetch Notebooks
                let cloudNotebooks = try await syncEngine.listNotebooks(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina
                )

                await MainActor.run {
                    self.syncState = .syncing(message: "同步笔记本列表...")
                    if !cloudNotebooks.isEmpty {
                        self.notebooks = cloudNotebooks
                    }
                }

                // 2. Ensure default "SideNotes" notebook exists
                let sideNotesNb = try await syncEngine.getOrCreateDefaultNotebook(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    name: "SideNotes"
                )

                await MainActor.run {
                    if !self.notebooks.contains(where: { $0.guid == sideNotesNb.guid }) {
                        self.notebooks.append(sideNotesNb)
                    }
                    if self.currentNotebook == nil {
                        self.currentNotebook = sideNotesNb
                    }
                }

                // 3. Fetch notes for current notebook
                let targetNbGuid = await MainActor.run { self.currentNotebook?.guid ?? sideNotesNb.guid }
                let cloudNotes = try await syncEngine.fetchNotes(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    notebookGuid: targetNbGuid
                )

                await MainActor.run {
                    // Merge cloud notes into local notes
                    for cn in cloudNotes {
                        if let idx = self.allNotes.firstIndex(where: { $0.guid == cn.guid }) {
                            // Preserve local color and pin if already set
                            var updated = cn
                            updated.color = self.allNotes[idx].color
                            updated.isPinned = self.allNotes[idx].isPinned
                            self.allNotes[idx] = updated
                        } else {
                            self.allNotes.append(cn)
                        }
                    }
                    self.saveLocalData()
                    self.syncState = .success(message: "同步成功 (\(cloudNotes.count)条笔记)")

                    // Reset sync state after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if case .success = self.syncState {
                            self.syncState = .idle
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncState = .failed(error: error.localizedDescription)
                }
            }
        }
    }

    private func syncNotesForCurrentNotebook() {
        guard let current = currentNotebook, !settings.evernoteToken.isEmpty else { return }

        self.syncState = .syncing(message: "拉取笔记...")
        Task {
            do {
                let cloudNotes = try await syncEngine.fetchNotes(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    notebookGuid: current.guid
                )
                await MainActor.run {
                    for cn in cloudNotes {
                        if let idx = self.allNotes.firstIndex(where: { $0.guid == cn.guid }) {
                            var updated = cn
                            updated.color = self.allNotes[idx].color
                            updated.isPinned = self.allNotes[idx].isPinned
                            self.allNotes[idx] = updated
                        } else {
                            self.allNotes.append(cn)
                        }
                    }
                    self.saveLocalData()
                    self.syncState = .success(message: "已同步最新笔记")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if case .success = self.syncState {
                            self.syncState = .idle
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.syncState = .failed(error: error.localizedDescription)
                }
            }
        }
    }

    func saveSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        storage.saveSettings(newSettings)
    }
}
