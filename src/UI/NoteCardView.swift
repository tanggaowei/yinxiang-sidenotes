import SwiftUI

struct NoteCardView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onSetColor: (NoteColor) -> Void

    @State private var isHovered = false
    @State private var showCopiedAlert = false

    private var formattedDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(note.updatedAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: note.updatedAt)
        } else if calendar.isDateInYesterday(note.updatedAt) {
            return "昨天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: note.updatedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // MARK: - Header (Pin, Title, Date)
            HStack(alignment: .center, spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                }

                Text(note.title.isEmpty ? "无标题便签" : note.title)
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(note.title.isEmpty ? .secondary : .primary)
                    .lineLimit(1)

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            // MARK: - Body Preview
            if !note.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(note.content)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            } else {
                Text("点击记录内容...")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary.opacity(0.4))
            }

            // MARK: - Hover Action Bar
            if isHovered {
                HStack(spacing: 6) {
                    // Quick Color Picker
                    HStack(spacing: 4) {
                        ForEach(NoteColor.allCases) { color in
                            Circle()
                                .fill(color.accentColor)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.4), lineWidth: note.color == color ? 1.5 : 0)
                                )
                                .onTapGesture {
                                    onSetColor(color)
                                }
                        }
                    }

                    Spacer()

                    // Copy action
                    Button(action: copyCardContent) {
                        Image(systemName: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(showCopiedAlert ? .green : .secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(showCopiedAlert ? "已拷贝" : "拷贝便签内容")

                    // Pin action
                    Button(action: onTogglePin) {
                        Image(systemName: note.isPinned ? "pin.slash.fill" : "pin")
                            .font(.system(size: 10))
                            .foregroundColor(note.isPinned ? .orange : .secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(note.isPinned ? "取消置顶" : "置顶")

                    // Delete action
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                            .background(Color.primary.opacity(0.04))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("删除")
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(note.color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? note.color.accentColor : note.color.cardBorder,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(isHovered ? 0.09 : 0.03),
                    radius: isHovered ? 5 : 2,
                    x: 0,
                    y: isHovered ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button(action: onTogglePin) {
                Label(note.isPinned ? "取消置顶" : "置顶笔记", systemImage: note.isPinned ? "pin.slash" : "pin")
            }

            Button(action: copyCardContent) {
                Label("拷贝内容", systemImage: "doc.on.doc")
            }

            Menu("便签色板") {
                ForEach(NoteColor.allCases) { color in
                    Button(action: { onSetColor(color) }) {
                        Text(color.displayName)
                    }
                }
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("删除便签", systemImage: "trash")
            }
        }
    }

    private func copyCardContent() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let full = note.title.isEmpty ? note.content : "\(note.title)\n\n\(note.content)"
        pasteboard.setString(full, forType: .string)

        withAnimation {
            showCopiedAlert = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                self.showCopiedAlert = false
            }
        }
    }
}
