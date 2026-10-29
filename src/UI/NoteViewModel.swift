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

        // Migrate local placeholder notebook GUIDs if needed
        if let current = currentNotebook, current.guid != "default-sidenotes-nb", current.name == "SideNotes" {
            for i in 0..<self.allNotes.count {
                if self.allNotes[i].notebookGuid == "default-sidenotes-nb" {
                    self.allNotes[i].notebookGuid = current.guid
                }
            }
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
        let tempGuid = UUID().uuidString
        let newNb = Notebook(guid: tempGuid, name: trimmed, isDefault: false)
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
                        if let idx = self.notebooks.firstIndex(where: { $0.id == tempGuid }) {
                            self.notebooks[idx] = cloudNb
                            if self.currentNotebook?.guid == tempGuid {
                                self.currentNotebook = cloudNb
                                self.settings.selectedNotebookGuid = cloudNb.guid
                                self.storage.saveSettings(self.settings)
                            }
                            // Migrate any notes that were assigned to tempGuid
                            for nIdx in 0..<self.allNotes.count {
                                if self.allNotes[nIdx].notebookGuid == tempGuid {
                                    self.allNotes[nIdx].notebookGuid = cloudNb.guid
                                    self.allNotes[nIdx].isDirty = true
                                }
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

            // Retrieve the latest snapshot of this note before calling the cloud API
            guard let latestNote = await MainActor.run(body: {
                self.allNotes.first(where: { $0.id == note.id })
            }) else { return }

            do {
                let saved = try await syncEngine.saveNote(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    note: latestNote
                )
                await MainActor.run {
                    if let idx = self.allNotes.firstIndex(where: { $0.id == latestNote.id }) {
                        self.allNotes[idx].guid = saved.guid
                        self.allNotes[idx].updatedAt = saved.updated
                        self.allNotes[idx].isDirty = false

                        // Update metadata of selectedNote without overwriting in-flight content
                        if var sel = self.selectedNote, sel.id == latestNote.id {
                            sel.guid = saved.guid
                            sel.updatedAt = saved.updated
                            sel.isDirty = false
                            self.selectedNote = sel
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

                // 2. Ensure default "SideNotes" notebook exists
                let sideNotesNb = try await syncEngine.getOrCreateDefaultNotebook(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    name: "SideNotes"
                )

                // 3. Resolve active notebook and migrate local placeholder notebook GUIDs
                let targetNbGuid: String = await MainActor.run {
                    var mergedNotebooks = cloudNotebooks
                    if !mergedNotebooks.contains(where: { $0.guid == sideNotesNb.guid }) {
                        mergedNotebooks.insert(sideNotesNb, at: 0)
                    }
                    self.notebooks = mergedNotebooks

                    let oldCurrent = self.currentNotebook
                    let isOldLocalGuid = oldCurrent?.guid.contains("default-") == true ||
                                         oldCurrent?.guid.contains("-nb") == true

                    if let oldCurrent = oldCurrent,
                       let matched = mergedNotebooks.first(where: { $0.guid == oldCurrent.guid }) {
                        self.currentNotebook = matched
                    } else if let oldCurrent = oldCurrent,
                              let matchedByName = mergedNotebooks.first(where: { $0.name == oldCurrent.name }) {
                        // Map local placeholder (e.g. "SideNotes" or "工作待办") to matching cloud notebook
                        self.currentNotebook = matchedByName
                    } else if let sideNotesMatch = mergedNotebooks.first(where: { $0.guid == sideNotesNb.guid }) {
                        self.currentNotebook = sideNotesMatch
                    } else if let def = mergedNotebooks.first(where: { $0.isDefault }) {
                        self.currentNotebook = def
                    } else {
                        self.currentNotebook = mergedNotebooks.first
                    }

                    if let current = self.currentNotebook {
                        self.settings.selectedNotebookGuid = current.guid
                        self.storage.saveSettings(self.settings)

                        // If migrating from local placeholder guid (e.g. "default-sidenotes-nb"),
                        // update notebookGuid on all existing local notes so they stay with this notebook
                        if let oldGuid = oldCurrent?.guid, oldGuid != current.guid, isOldLocalGuid {
                            for idx in 0..<self.allNotes.count {
                                if self.allNotes[idx].notebookGuid == oldGuid {
                                    self.allNotes[idx].notebookGuid = current.guid
                                    self.allNotes[idx].isDirty = true
                                }
                            }
                        }
                    }

                    return self.currentNotebook?.guid ?? sideNotesNb.guid
                }

                // 4. Upload any local dirty notes for this notebook
                let dirtyNotes = await MainActor.run {
                    self.allNotes.filter { $0.notebookGuid == targetNbGuid && $0.isDirty }
                }

                for note in dirtyNotes {
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
                            }
                        }
                    } catch {
                        print("Failed to sync local note to cloud: \(error)")
                    }
                }

                // 5. Fetch notes from cloud for current notebook
                let knownNotes = await MainActor.run {
                    Dictionary(
                        self.allNotes.filter { $0.notebookGuid == targetNbGuid && !$0.isDirty }
                            .map { ($0.guid, $0.updatedAt.timeIntervalSince1970 * 1000.0) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }

                let cloudNotes = try await syncEngine.fetchNotes(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    notebookGuid: targetNbGuid,
                    knownNotes: knownNotes
                )

                await MainActor.run {
                    self.applyCloudSync(cloudNotes: cloudNotes, notebookGuid: targetNbGuid)
                    self.syncState = .success(message: "同步成功 (\(cloudNotes.count)条云端笔记)")

                    // Reset sync state after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                        if case .success = self?.syncState {
                            self?.syncState = .idle
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

        // If current notebook is still a local placeholder, run full sync instead
        if current.guid.contains("default-") || current.guid.contains("-nb") {
            syncWithYinxiang()
            return
        }

        self.syncState = .syncing(message: "正在拉取笔记...")
        Task {
            do {
                // Upload any dirty notes first
                let dirtyNotes = await MainActor.run {
                    self.allNotes.filter { $0.notebookGuid == current.guid && $0.isDirty }
                }
                for note in dirtyNotes {
                    if let saved = try? await syncEngine.saveNote(
                        token: settings.evernoteToken,
                        china: settings.serviceType.isChina,
                        note: note
                    ) {
                        await MainActor.run {
                            if let idx = self.allNotes.firstIndex(where: { $0.id == note.id }) {
                                self.allNotes[idx].guid = saved.guid
                                self.allNotes[idx].updatedAt = saved.updated
                                self.allNotes[idx].isDirty = false
                                if self.selectedNote?.id == note.id {
                                    self.selectedNote = self.allNotes[idx]
                                }
                            }
                        }
                    }
                }

                let knownNotes = await MainActor.run {
                    Dictionary(
                        self.allNotes.filter { $0.notebookGuid == current.guid && !$0.isDirty }
                            .map { ($0.guid, $0.updatedAt.timeIntervalSince1970 * 1000.0) },
                        uniquingKeysWith: { first, _ in first }
                    )
                }

                let cloudNotes = try await syncEngine.fetchNotes(
                    token: settings.evernoteToken,
                    china: settings.serviceType.isChina,
                    notebookGuid: current.guid,
                    knownNotes: knownNotes
                )
                await MainActor.run {
                    self.applyCloudSync(cloudNotes: cloudNotes, notebookGuid: current.guid)
                    self.syncState = .success(message: "已同步最新笔记")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                        if case .success = self?.syncState {
                            self?.syncState = .idle
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

    // Merge cloud notes into local storage and remove notes deleted in cloud
    @MainActor
    private func applyCloudSync(cloudNotes: [Note], notebookGuid: String) {
        let cloudGuids = Set(cloudNotes.map { $0.guid })

        // 1. Remove local notes that were deleted in cloud:
        // (Must belong to this notebook, not be marked dirty with unsynced local edits, and absent from cloud)
        self.allNotes.removeAll { localNote in
            if localNote.notebookGuid == notebookGuid && !localNote.isDirty && !cloudGuids.contains(localNote.guid) {
                return true
            }
            return false
        }

        // 2. Deselect note if it was deleted
        if let sel = self.selectedNote,
           sel.notebookGuid == notebookGuid && !sel.isDirty && !cloudGuids.contains(sel.guid) {
            self.selectedNote = nil
        }

        // 3. Update existing notes or append new notes
        for cn in cloudNotes {
            if let idx = self.allNotes.firstIndex(where: { $0.guid == cn.guid }) {
                // If local note has unsaved changes, do not overwrite local content
                if !self.allNotes[idx].isDirty {
                    var updated = self.allNotes[idx]
                    updated.title = cn.title
                    updated.updatedAt = cn.updatedAt
                    updated.notebookGuid = cn.notebookGuid
                    // Only update content if cloud note was fetched/modified
                    if cn.notModified != true {
                        updated.content = cn.content
                    }
                    self.allNotes[idx] = updated
                }
            } else {
                // Brand new note from cloud
                self.allNotes.append(cn)
            }
        }

        // 4. If current selected note was updated, keep selectedNote in sync
        if let sel = self.selectedNote,
           let updatedSelected = self.allNotes.first(where: { $0.id == sel.id }) {
            self.selectedNote = updatedSelected
        }

        self.saveLocalData()
    }

    func saveSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        storage.saveSettings(newSettings)
    }
}
