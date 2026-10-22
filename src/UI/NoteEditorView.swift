import SwiftUI

struct NoteEditorView: View {
    @Binding var note: Note
    let onBack: () -> Void
    let onUpdate: (Note) -> Void
    let onDelete: () -> Void

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var currentColor: NoteColor = .gray
    @FocusState private var isContentFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Top Nav
            HStack {
                Button(action: {
                    saveCurrentNote()
                    onBack()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("返回")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                // Color picker
                HStack(spacing: 4) {
                    ForEach(NoteColor.allCases) { color in
                        Circle()
                            .fill(color.accentColor)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.4), lineWidth: currentColor == color ? 1.5 : 0)
                            )
                            .onTapGesture {
                                currentColor = color
                                saveCurrentNote()
                            }
                    }
                }

                Spacer()

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider().opacity(0.5)

            // Title input
            TextField("笔记标题", text: $title)
                .font(.system(size: 15, weight: .semibold))
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 6)
                .onChange(of: title) {
                    saveCurrentNote()
                }

            // Body Markdown editor
            TextEditor(text: $content)
                .font(.system(size: 13, design: .default))
                .lineSpacing(4)
                .padding(.horizontal, 10)
                .focused($isContentFocused)
                .onChange(of: content) {
                    saveCurrentNote()
                }
                .background(Color.clear)

            Divider().opacity(0.4)

            // Markdown Formatting Toolbar
            HStack(spacing: 12) {
                FormatButton(icon: "number", tooltip: "标题 (Header)") {
                    insertText("\n# ")
                }
                FormatButton(icon: "bold", tooltip: "粗体 (Bold)") {
                    insertText("**粗体文字**")
                }
                FormatButton(icon: "italic", tooltip: "斜体 (Italic)") {
                    insertText("*斜体文字*")
                }
                FormatButton(icon: "checklist", tooltip: "待办清单 (Checklist)") {
                    insertText("\n- [ ] ")
                }
                FormatButton(icon: "list.bullet", tooltip: "无序列表 (List)") {
                    insertText("\n- ")
                }
                FormatButton(icon: "chevron.left.forwardslash.chevron.right", tooltip: "代码 (Code)") {
                    insertText("\n```\n代码内容\n```\n")
                }

                Spacer()

                Text(note.isDirty ? "已就地保存" : "已同步")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.4))
        }
        .background(currentColor.cardBackground)
        .onAppear {
            self.title = note.title
            self.content = note.content
            self.currentColor = note.color
        }
    }

    private func insertText(_ text: String) {
        content.append(text)
        saveCurrentNote()
        isContentFocused = true
    }

    private func saveCurrentNote() {
        var updated = note
        updated.title = title
        updated.content = content
        updated.color = currentColor
        onUpdate(updated)
    }
}

struct FormatButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(BorderlessButtonStyle())
        .help(tooltip)
    }
}
