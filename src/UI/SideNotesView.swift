import SwiftUI

struct SideNotesView: View {
    @ObservedObject var viewModel: NoteViewModel
    @ObservedObject var windowManager = WindowManager.shared

    @State private var showingCreateNotebookAlert = false
    @State private var newNotebookInput = ""

    var body: some View {
        ZStack {
            if let selected = viewModel.selectedNote {
                // Expanded Note Editor
                NoteEditorView(
                    note: Binding(
                        get: { selected },
                        set: { viewModel.updateNote($0) }
                    ),
                    onBack: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            viewModel.selectedNote = nil
                        }
                    },
                    onUpdate: { updated in
                        viewModel.updateNote(updated)
                    },
                    onDelete: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            viewModel.deleteNote(selected)
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: windowManager.dockSide == .right ? .leading : .trailing).combined(with: .opacity),
                    removal: .move(edge: windowManager.dockSide == .right ? .leading : .trailing).combined(with: .opacity)
                ))
            } else {
                // Card Deck List View
                VStack(spacing: 0) {
                    // 1. Top Bar
                    topBar

                    Divider().opacity(0.35)

                    // 2. Search & Filter Bar
                    searchBar

                    // 3. Sync Status Banner (if active)
                    syncStatusBanner

                    // 4. Note Cards Deck
                    cardsList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $viewModel.isSettingsOpen) {
            SettingsView(viewModel: viewModel) {
                viewModel.isSettingsOpen = false
            }
        }
        .sheet(isPresented: $showingCreateNotebookAlert) {
            createNotebookSheet
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.85), value: viewModel.selectedNote?.id)
    }

    // MARK: - Top Toolbar
    private var topBar: some View {
        HStack(spacing: 6) {
            // Notebook Picker Menu
            Menu {
                Section("印象笔记笔记本") {
                    ForEach(viewModel.notebooks) { nb in
                        Button(action: {
                            viewModel.selectNotebook(nb)
                        }) {
                            HStack {
                                Text(nb.name)
                                if nb.guid == viewModel.currentNotebook?.guid {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                Divider()

                Button(action: {
                    newNotebookInput = ""
                    showingCreateNotebookAlert = true
                }) {
                    Label("新建笔记本...", systemImage: "folder.badge.plus")
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)

                    Text(viewModel.currentNotebook?.name ?? "SideNotes")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)

                    Text("(\(viewModel.filteredNotes.count))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
            }
            .menuStyle(BorderlessButtonMenuStyle())

            Spacer()

            // Header Action Buttons
            HStack(spacing: 3) {
                // Sync Button
                IconButton(
                    icon: syncIconName,
                    tooltip: "立即同步印象笔记",
                    isActive: false,
                    isSpinning: isSyncing
                ) {
                    viewModel.syncWithYinxiang()
                }

                // Dock Side Toggle
                IconButton(
                    icon: windowManager.dockSide == .right ? "sidebar.right" : "sidebar.left",
                    tooltip: windowManager.dockSide == .right ? "切换停靠到屏幕左侧" : "切换停靠到屏幕右侧",
                    isActive: false
                ) {
                    let nextSide: DockSide = (windowManager.dockSide == .right) ? .left : .right
                    windowManager.setDockSide(nextSide)
                    var s = viewModel.settings
                    s.dockSide = nextSide
                    viewModel.saveSettings(s)
                }

                // Pin Button
                IconButton(
                    icon: windowManager.isPinned ? "pin.fill" : "pin",
                    tooltip: windowManager.isPinned ? "已置顶 (点击解除)" : "点击置顶窗口",
                    isActive: windowManager.isPinned,
                    activeColor: .orange
                ) {
                    let nextPinned = !windowManager.isPinned
                    windowManager.setPinned(nextPinned)
                    var s = viewModel.settings
                    s.isPinned = nextPinned
                    viewModel.saveSettings(s)
                }

                // Settings Button
                IconButton(
                    icon: "gearshape",
                    tooltip: "偏好设置",
                    isActive: false
                ) {
                    viewModel.isSettingsOpen = true
                }
            }

            // New Note Button (Distinct Accent Pill)
            Button(action: {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    viewModel.createNewNote()
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                    Text("便签")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .dynamic(light: 0x1E293B, dark: 0x38BDF8)))
                )
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
            .help("新建便签 (⌘N)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var isSyncing: Bool {
        if case .syncing = viewModel.syncState { return true }
        return false
    }

    private var syncIconName: String {
        switch viewModel.syncState {
        case .syncing:
            return "arrow.triangle.2.circlepath"
        case .failed:
            return "exclamationmark.icloud"
        case .success:
            return "checkmark.icloud"
        case .idle, .offline:
            return "arrow.triangle.2.circlepath"
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)

            TextField("搜索便签标题或内容...", text: $viewModel.searchQuery)
                .font(.system(size: 12))
                .textFieldStyle(PlainTextFieldStyle())

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Sync Status Banner
    @ViewBuilder
    private var syncStatusBanner: some View {
        switch viewModel.syncState {
        case .syncing(let msg):
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.55)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.08))
            .transition(.move(edge: .top).combined(with: .opacity))
        case .failed(let err):
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                Text(err)
                    .font(.system(size: 11))
                    .foregroundColor(.red)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.red.opacity(0.08))
            .transition(.move(edge: .top).combined(with: .opacity))
        case .success(let msg):
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.green)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color.green.opacity(0.08))
            .transition(.move(edge: .top).combined(with: .opacity))
        case .idle, .offline:
            EmptyView()
        }
    }

    // MARK: - Cards Deck
    private var cardsList: some View {
        ScrollView {
            LazyVStack(spacing: 9) {
                let notes = viewModel.filteredNotes

                if notes.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.searchQuery.isEmpty ? "note.text.badge.plus" : "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, 50)

                        Text(viewModel.searchQuery.isEmpty ? "当前笔记本尚无便签" : "未找到与「\(viewModel.searchQuery)」匹配的便签")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        if viewModel.searchQuery.isEmpty {
                            Button(action: {
                                withAnimation {
                                    viewModel.createNewNote()
                                }
                            }) {
                                Text("新建第一条便签")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(Color.accentColor)
                                    .cornerRadius(7)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 4)
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(notes) { note in
                        NoteCardView(
                            note: note,
                            isSelected: viewModel.selectedNote?.id == note.id,
                            onSelect: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    viewModel.selectedNote = note
                                }
                            },
                            onDelete: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    viewModel.deleteNote(note)
                                }
                            },
                            onTogglePin: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                    viewModel.togglePinNote(note)
                                }
                            },
                            onSetColor: { color in
                                viewModel.setNoteColor(note, color: color)
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Create Notebook Sheet
    private var createNotebookSheet: some View {
        VStack(spacing: 16) {
            Text("新建印象笔记笔记本")
                .font(.system(size: 14, weight: .semibold))

            TextField("笔记本名称 (如: 随手记 / 工作备忘)", text: $newNotebookInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            HStack {
                Button("取消") {
                    showingCreateNotebookAlert = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("创建") {
                    viewModel.createNewNotebook(name: newNotebookInput)
                    showingCreateNotebookAlert = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newNotebookInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 290)
    }
}

// MARK: - Reusable Icon Button
struct IconButton: View {
    let icon: String
    let tooltip: String
    let isActive: Bool
    var activeColor: Color = .accentColor
    var isSpinning: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isActive ? activeColor : (isHovered ? .primary : .secondary))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? activeColor.opacity(0.12) : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}
