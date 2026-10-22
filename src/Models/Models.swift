import Foundation
import SwiftUI

// MARK: - Note Color Theme
enum NoteColor: String, Codable, CaseIterable, Identifiable {
    case gray = "gray"
    case red = "red"
    case orange = "orange"
    case green = "green"
    case blue = "blue"
    case purple = "purple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gray: return "默认灰"
        case .red: return "珊瑚红"
        case .orange: return "琥珀橙"
        case .green: return "薄荷绿"
        case .blue: return "海沫蓝"
        case .purple: return "丁香紫"
        }
    }

    var accentColor: Color {
        switch self {
        case .gray: return Color.secondary.opacity(0.6)
        case .red: return Color.red.opacity(0.8)
        case .orange: return Color.orange.opacity(0.85)
        case .green: return Color.green.opacity(0.8)
        case .blue: return Color.blue.opacity(0.85)
        case .purple: return Color.purple.opacity(0.85)
        }
    }

    var cardBackground: Color {
        switch self {
        case .gray: return Color(NSColor.controlBackgroundColor).opacity(0.65)
        case .red: return Color.red.opacity(0.12)
        case .orange: return Color.orange.opacity(0.12)
        case .green: return Color.green.opacity(0.12)
        case .blue: return Color.blue.opacity(0.12)
        case .purple: return Color.purple.opacity(0.12)
        }
    }
}

// MARK: - Notebook Model
struct Notebook: Codable, Identifiable, Hashable {
    var id: String { guid }
    let guid: String
    var name: String
    var isDefault: Bool

    enum CodingKeys: String, CodingKey {
        case guid
        case name
        case isDefault = "defaultNotebook"
    }

    init(guid: String, name: String, isDefault: Bool = false) {
        self.guid = guid
        self.name = name
        self.isDefault = isDefault
    }
}

// MARK: - Note Model
struct Note: Codable, Identifiable, Hashable {
    var id: String { guid }
    var guid: String
    var title: String
    var content: String
    var notebookGuid: String
    var updatedAt: Date
    var color: NoteColor
    var isPinned: Bool
    var isDirty: Bool // local changes pending sync
    var notModified: Bool? = false

    init(
        guid: String = UUID().uuidString,
        title: String = "",
        content: String = "",
        notebookGuid: String = "",
        updatedAt: Date = Date(),
        color: NoteColor = .gray,
        isPinned: Bool = false,
        isDirty: Bool = false,
        notModified: Bool? = false
    ) {
        self.guid = guid
        self.title = title
        self.content = content
        self.notebookGuid = notebookGuid
        self.updatedAt = updatedAt
        self.color = color
        self.isPinned = isPinned
        self.isDirty = isDirty
        self.notModified = notModified
    }
}

// MARK: - App Settings
enum DockSide: String, Codable, CaseIterable {
    case right = "right"
    case left = "left"

    var title: String {
        switch self {
        case .right: return "屏幕右侧 (默认)"
        case .left: return "屏幕左侧"
        }
    }
}

enum ServiceType: String, Codable, CaseIterable {
    case yinxiangChina = "china"
    case evernoteInternational = "international"

    var title: String {
        switch self {
        case .yinxiangChina: return "印象笔记 (国内版 app.yinxiang.com)"
        case .evernoteInternational: return "Evernote (国际版 www.evernote.com)"
        }
    }

    var isChina: Bool {
        return self == .yinxiangChina
    }
}

struct AppSettings: Codable {
    var dockSide: DockSide = .right
    var isPinned: Bool = true
    var evernoteToken: String = ""
    var serviceType: ServiceType = .yinxiangChina
    var selectedNotebookGuid: String = ""
    var panelWidth: CGFloat = 360
    var autoSyncOnLaunch: Bool = true
}

// MARK: - Sync Status
enum SyncState: Equatable {
    case idle
    case syncing(message: String)
    case success(message: String)
    case failed(error: String)
    case offline
}
