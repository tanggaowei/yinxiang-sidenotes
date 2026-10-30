import SwiftUI

struct NoteEditorView: View {
    @Binding var note: Note
    let onBack: () -> Void
    let onUpdate: (Note) -> Void
    let onDelete: () -> Void

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var currentColor: NoteColor = .gray
    @State private var isPinned: Bool = false
    @State private var showCopiedAlert = false
    @State private var autoSaveWorkItem: DispatchWorkItem? = nil

    private var lineCount: Int {
        content.isEmpty ? 0 : content.components(separatedBy: .newlines).count
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: note.updatedAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Nav Bar
            HStack(spacing: 6) {
                // Back Button
                Button(action: {
                    autoSaveWorkItem?.cancel()
                    saveCurrentNote()
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .fixedSize()
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
                .layoutPriority(1)
                .help("返回便签列表 (自动保存)")

                Spacer()

                // Color Palette Selector
                HStack(spacing: 5) {
                    ForEach(NoteColor.allCases) { color in
                        ZStack {
                            if currentColor == color {
                                Circle()
                                    .stroke(color.accentColor, lineWidth: 1.8)
                                    .frame(width: 15, height: 15)
                            }

                            Circle()
                                .fill(color.accentColor)
                                .frame(width: 9.5, height: 9.5)
                        }
                        .frame(width: 16, height: 16)
                        .contentShape(Circle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                currentColor = color
                            }
                            saveCurrentNote()
                        }
                        .help("切换为 \(color.displayName)")
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(12)

                Spacer()

                // Actions: Pin, Copy, Delete
                HStack(spacing: 2) {
                    // Pin Button
                    Button(action: {
                        isPinned.toggle()
                        saveCurrentNote()
                    }) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11))
                            .foregroundColor(isPinned ? .orange : .secondary)
                            .frame(width: 24, height: 24)
                            .background(isPinned ? Color.orange.opacity(0.12) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(isPinned ? "取消置顶" : "置顶便签")

                    // Copy Content Button
                    Button(action: copyContentToClipboard) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11))
                            .foregroundColor(showCopiedAlert ? .green : .secondary)
                            .frame(width: 24, height: 24)
                            .background(showCopiedAlert ? Color.green.opacity(0.12) : Color.clear)
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(showCopiedAlert ? "已复制到剪贴板！" : "拷贝全文")

                    // Delete Button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("删除此便签")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(currentColor.toolbarBackground)

            Divider()
                .opacity(0.35)

            // MARK: - Title & Meta Info
            VStack(alignment: .leading, spacing: 4) {
                TextField("便签标题...", text: $title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(.top, 10)
                    .padding(.horizontal, 16)
                    .onChange(of: title) {
                        scheduleAutoSave()
                    }

                // Subline metadata
                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.85))

                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("\(content.count) 字 / \(lineCount) 行")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.85))

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }

            // MARK: - Notion-Style Live Rich Markdown Editor
            RichMarkdownEditor(
                text: $content,
                noteColor: currentColor,
                noteId: note.id,
                onTextChange: {
                    scheduleAutoSave()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
                .opacity(0.35)

            // MARK: - Formatting Toolbar & Status
            HStack(spacing: 6) {
                Group {
                    EditorToolButton(icon: "number", label: "H1", tooltip: "一级标题 (# )") {
                        insertPrefix("\n# ")
                    }
                    EditorToolButton(icon: "number", label: "H2", tooltip: "二级标题 (## )") {
                        insertPrefix("\n## ")
                    }
                    EditorToolButton(icon: "bold", label: "B", tooltip: "粗体 (**文字**)") {
                        wrapSelection(prefix: "**", suffix: "**", placeholder: "粗体文字")
                    }
                    EditorToolButton(icon: "italic", label: "I", tooltip: "斜体 (*文字*)") {
                        wrapSelection(prefix: "*", suffix: "*", placeholder: "斜体文字")
                    }
                    EditorToolButton(icon: "checkmark.square", label: nil, tooltip: "待办清单 (- [ ])") {
                        insertPrefix("\n- [ ] ")
                    }
                    EditorToolButton(icon: "list.bullet", label: nil, tooltip: "无序列表 (- )") {
                        insertPrefix("\n- ")
                    }
                    EditorToolButton(icon: "chevron.left.forwardslash.chevron.right", label: nil, tooltip: "代码块 (```)") {
                        insertPrefix("\n```\n代码内容\n```\n")
                    }
                    EditorToolButton(icon: "link", label: nil, tooltip: "插入超链接") {
                        wrapSelection(prefix: "[链接描述](", suffix: ")", placeholder: "https://")
                    }
                }

                Spacer()

                // Status chip
                HStack(spacing: 4) {
                    Circle()
                        .fill(note.isDirty ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                    Text(note.isDirty ? "本地就绪" : "已同步")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(note.isDirty ? .orange : .secondary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(currentColor.toolbarBackground)
        }
        .background(currentColor.cardBackground)
        .onAppear {
            self.title = note.title
            self.content = note.content
            self.currentColor = note.color
            self.isPinned = note.isPinned
        }
        .onDisappear {
            autoSaveWorkItem?.cancel()
            saveCurrentNote()
        }
    }

    // MARK: - Insertion Helpers
    private func insertPrefix(_ text: String) {
        content.append(text)
        saveCurrentNote()
    }

    private func wrapSelection(prefix: String, suffix: String, placeholder: String) {
        content.append("\(prefix)\(placeholder)\(suffix)")
        saveCurrentNote()
    }

    private func copyContentToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let fullText = title.isEmpty ? content : "\(title)\n\n\(content)"
        pasteboard.setString(fullText, forType: .string)

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation {
                self.showCopiedAlert = false
            }
        }
    }

    private func scheduleAutoSave() {
        autoSaveWorkItem?.cancel()
        let item = DispatchWorkItem {
            saveCurrentNote()
        }
        autoSaveWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    private func saveCurrentNote() {
        autoSaveWorkItem?.cancel()
        var updated = note
        updated.title = title
        updated.content = content
        updated.color = currentColor
        updated.isPinned = isPinned
        updated.updatedAt = Date()
        onUpdate(updated)
    }
}

// MARK: - Refined Toolbar Button
struct EditorToolButton: View {
    let icon: String?
    let label: String?
    let tooltip: String
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                }
                if let label = label {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .foregroundColor(isHovered ? .primary : .secondary)
            .frame(height: 22)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isHovered ? Color.primary.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { isHovered = $0 }
        .help(tooltip)
    }
}
