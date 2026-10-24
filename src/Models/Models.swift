import Foundation
import SwiftUI

// MARK: - Color Palette Helpers
extension NSColor {
    static func hex(_ hex: UInt32, alpha: CGFloat = 1.0) -> NSColor {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
    }

    static func dynamic(light: UInt32, dark: UInt32, alpha: CGFloat = 1.0) -> NSColor {
        NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            let r = CGFloat((hex >> 16) & 0xFF) / 255.0
            let g = CGFloat((hex >> 8) & 0xFF) / 255.0
            let b = CGFloat(hex & 0xFF) / 255.0
            return NSColor(srgbRed: r, green: g, blue: b, alpha: alpha)
        }
    }
}

// MARK: - Note Color Theme
enum NoteColor: String, Codable, CaseIterable, Identifiable {
    case gray = "gray"
    case orange = "orange"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case red = "red"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gray: return "极简石墨"
        case .orange: return "琥珀原纸"
        case .green: return "鼠尾草绿"
        case .blue: return "冰川晨蓝"
        case .purple: return "丁香浅紫"
        case .red: return "珊瑚柔粉"
        }
    }

    var accentColor: Color {
        switch self {
        case .gray:
            return Color(nsColor: .dynamic(light: 0x64748B, dark: 0x94A3B8))
        case .orange:
            return Color(nsColor: .dynamic(light: 0xD97706, dark: 0xFBBF24))
        case .green:
            return Color(nsColor: .dynamic(light: 0x16A34A, dark: 0x4ADE80))
        case .blue:
            return Color(nsColor: .dynamic(light: 0x2563EB, dark: 0x60A5FA))
        case .purple:
            return Color(nsColor: .dynamic(light: 0x9333EA, dark: 0xC084FC))
        case .red:
            return Color(nsColor: .dynamic(light: 0xE11D48, dark: 0xFB7185))
        }
    }

    var cardBackground: Color {
        switch self {
        case .gray:
            return Color(nsColor: .dynamic(light: 0xF8F9FB, dark: 0x202227))
        case .orange:
            return Color(nsColor: .dynamic(light: 0xFFFDF7, dark: 0x26221B))
        case .green:
            return Color(nsColor: .dynamic(light: 0xF4FAF6, dark: 0x1B2520))
        case .blue:
            return Color(nsColor: .dynamic(light: 0xF3F8FD, dark: 0x1B2432))
        case .purple:
            return Color(nsColor: .dynamic(light: 0xF9F5FD, dark: 0x251D2E))
        case .red:
            return Color(nsColor: .dynamic(light: 0xFDF4F5, dark: 0x291C22))
        }
    }

    var cardBorder: Color {
        switch self {
        case .gray:
            return Color(nsColor: .dynamic(light: 0xE2E6ED, dark: 0x333842))
        case .orange:
            return Color(nsColor: .dynamic(light: 0xF4E4CA, dark: 0x453A2A))
        case .green:
            return Color(nsColor: .dynamic(light: 0xD7EEDB, dark: 0x2A4535))
        case .blue:
            return Color(nsColor: .dynamic(light: 0xD4E6FA, dark: 0x2B3F5B))
        case .purple:
            return Color(nsColor: .dynamic(light: 0xEBDDF9, dark: 0x442F5B))
        case .red:
            return Color(nsColor: .dynamic(light: 0xFBD9DE, dark: 0x4C2936))
        }
    }

    var toolbarBackground: Color {
        switch self {
        case .gray:
            return Color(nsColor: .dynamic(light: 0xF0F2F6, dark: 0x1A1C20, alpha: 0.9))
        case .orange:
            return Color(nsColor: .dynamic(light: 0xFBF3E4, dark: 0x201B14, alpha: 0.9))
        case .green:
            return Color(nsColor: .dynamic(light: 0xECF6EF, dark: 0x152019, alpha: 0.9))
        case .blue:
            return Color(nsColor: .dynamic(light: 0xEBF3FC, dark: 0x151E2B, alpha: 0.9))
        case .purple:
            return Color(nsColor: .dynamic(light: 0xF3EBFB, dark: 0x1F1627, alpha: 0.9))
        case .red:
            return Color(nsColor: .dynamic(light: 0xFBEBEF, dark: 0x23151B, alpha: 0.9))
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
