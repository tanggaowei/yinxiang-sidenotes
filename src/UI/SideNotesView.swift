import SwiftUI

struct SideNotesView: View {
    @StateObject var viewModel = NoteViewModel()
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
                        viewModel.selectedNote = nil
                    },
                    onUpdate: { updated in
                        viewModel.updateNote(updated)
                    },
                    onDelete: {
                        viewModel.deleteNote(selected)
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

                    Divider().opacity(0.4)

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
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: viewModel.selectedNote?.id)
    }

    // MARK: - Top Toolbar
    private var topBar: some View {
        HStack(spacing: 6) {
            // Notebook Picker Menu
            Menu {
                Section("所有笔记本") {
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
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)

                    Text(viewModel.currentNotebook?.name ?? "SideNotes")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                .cornerRadius(6)
            }
            .menuStyle(BorderlessButtonMenuStyle())

            Spacer()

            // Sync Button
            Button(action: {
                viewModel.syncWithYinxiang()
            }) {
                syncIcon
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("同步印象笔记")

            // Dock Side Toggle
            Button(action: {
                let nextSide: DockSide = (windowManager.dockSide == .right) ? .left : .right
                windowManager.setDockSide(nextSide)
                var s = viewModel.settings
                s.dockSide = nextSide
                viewModel.saveSettings(s)
            }) {
                Image(systemName: windowManager.dockSide == .right ? "sidebar.right" : "sidebar.left")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(windowManager.dockSide == .right ? "当前停靠右侧 (点击切换到左侧)" : "当前停靠左侧 (点击切换到右侧)")

            // Pin Button
            Button(action: {
                let nextPinned = !windowManager.isPinned
                windowManager.setPinned(nextPinned)
                var s = viewModel.settings
                s.isPinned = nextPinned
                viewModel.saveSettings(s)
            }) {
                Image(systemName: windowManager.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundColor(windowManager.isPinned ? .orange : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help(windowManager.isPinned ? "已置顶 (窗口保持常驻)" : "未置顶 (失焦自动收起)")

            // Settings Button
            Button(action: {
                viewModel.isSettingsOpen = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("偏好设置")

            // New Note Button
            Button(action: {
                withAnimation {
                    viewModel.createNewNote()
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("新建笔记")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            TextField("搜索笔记标题或内容...", text: $viewModel.searchQuery)
                .font(.system(size: 12))
                .textFieldStyle(PlainTextFieldStyle())

            if !viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Sync Status Banner
    @ViewBuilder
    private var syncStatusBanner: some View {
        switch viewModel.syncState {
        case .syncing(let msg):
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.5)
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
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
            .padding(.vertical, 4)
            .background(Color.red.opacity(0.1))
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
            .padding(.vertical, 4)
            .background(Color.green.opacity(0.1))
        case .idle, .offline:
            EmptyView()
        }
    }

    // MARK: - Cards Deck
    private var cardsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                let notes = viewModel.filteredNotes

                if notes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "note.text")
                            .font(.system(size: 28))
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(.top, 40)

                        Text(viewModel.searchQuery.isEmpty ? "暂无笔记，点击右上角 + 开始记录" : "未找到匹配的笔记")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(notes) { note in
                        NoteCardView(
                            note: note,
                            isSelected: viewModel.selectedNote?.id == note.id,
                            onSelect: {
                                withAnimation {
                                    viewModel.selectedNote = note
                                }
                            },
                            onDelete: {
                                withAnimation {
                                    viewModel.deleteNote(note)
                                }
                            },
                            onTogglePin: {
                                withAnimation {
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var syncIcon: some View {
        switch viewModel.syncState {
        case .syncing:
            ProgressView()
                .scaleEffect(0.6)
        case .failed:
            Image(systemName: "exclamationmark.icloud.fill")
                .foregroundColor(.red)
        case .success:
            Image(systemName: "checkmark.icloud.fill")
                .foregroundColor(.green)
        case .idle, .offline:
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }

    // MARK: - Create Notebook Sheet
    private var createNotebookSheet: some View {
        VStack(spacing: 14) {
            Text("新建印象笔记笔记本")
                .font(.system(size: 13, weight: .bold))

            TextField("笔记本名称 (如: 随手记 / 灵感集)", text: $newNotebookInput)
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
        .padding(20)
        .frame(width: 280)
    }
}
