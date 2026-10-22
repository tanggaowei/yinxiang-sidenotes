import SwiftUI

struct NoteCardView: View {
    let note: Note
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void
    let onSetColor: (NoteColor) -> Void

    @State private var isHovered = false

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
            formatter.dateFormat = "MM-dd"
            return formatter.string(from: note.updatedAt)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Title & Pin/Date
            HStack(alignment: .center) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(note.color.accentColor)
                }

                Text(note.title.isEmpty ? "无标题笔记" : note.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                Text(formattedDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            // Body preview (first 2-3 lines)
            if !note.content.isEmpty {
                Text(note.content)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .lineSpacing(2)
            }

            // Hover Action Bar
            if isHovered {
                HStack(spacing: 8) {
                    // Color dots
                    HStack(spacing: 4) {
                        ForEach(NoteColor.allCases) { color in
                            Circle()
                                .fill(color.accentColor)
                                .frame(width: 8, height: 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(0.3), lineWidth: note.color == color ? 1.5 : 0)
                                )
                                .onTapGesture {
                                    onSetColor(color)
                                }
                        }
                    }

                    Spacer()

                    // Pin Button
                    Button(action: onTogglePin) {
                        Image(systemName: note.isPinned ? "pin.slash" : "pin")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    // Delete Button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(note.color.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? note.color.accentColor : Color.primary.opacity(0.06),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .shadow(color: Color.black.opacity(isHovered ? 0.08 : 0.03), radius: isHovered ? 4 : 2, x: 0, y: 1)
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

            Menu("标记颜色") {
                ForEach(NoteColor.allCases) { color in
                    Button(action: { onSetColor(color) }) {
                        Text(color.displayName)
                    }
                }
            }

            Divider()

            Button(role: .destructive, action: onDelete) {
                Label("删除笔记", systemImage: "trash")
            }
        }
    }
}
