import Foundation

class StorageManager {
    static let shared = StorageManager()

    private let fileManager = FileManager.default
    private let appSupportURL: URL
    private let settingsFileURL: URL
    private let dataFileURL: URL

    private init() {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        appSupportURL = base.appendingPathComponent("YinxiangSideNotes", isDirectory: true)
        settingsFileURL = appSupportURL.appendingPathComponent("settings.json")
        dataFileURL = appSupportURL.appendingPathComponent("notes_data.json")

        createDirectoryIfNeeded()
    }

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: appSupportURL.path) {
            try? fileManager.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        }
    }

    // MARK: - Settings
    func loadSettings() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsFileURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            let defaultSettings = AppSettings()
            saveSettings(defaultSettings)
            return defaultSettings
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            try? data.write(to: settingsFileURL, options: .atomic)
        }
    }

    // MARK: - Notes & Notebooks Data
    struct StoredData: Codable {
        var notebooks: [Notebook]
        var notes: [Note]
    }

    func loadData() -> (notebooks: [Notebook], notes: [Note]) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: dataFileURL),
              let stored = try? decoder.decode(StoredData.self, from: data) else {
            // First time initialization with sample data
            let initial = generateInitialData()
            saveData(notebooks: initial.notebooks, notes: initial.notes)
            return initial
        }
        return (stored.notebooks, stored.notes)
    }

    func saveData(notebooks: [Notebook], notes: [Note]) {
        let stored = StoredData(notebooks: notebooks, notes: notes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(stored) {
            try? data.write(to: dataFileURL, options: .atomic)
        }
    }

    private func generateInitialData() -> (notebooks: [Notebook], notes: [Note]) {
        let defaultNotebook = Notebook(guid: "default-sidenotes-nb", name: "SideNotes", isDefault: true)
        let workNotebook = Notebook(guid: "default-work-nb", name: "工作待办", isDefault: false)

        let note1 = Note(
            guid: UUID().uuidString,
            title: "👋 欢迎使用印象笔记 SideNotes",
            content: """
            这是专门为 macOS 设计的极轻量侧边停靠笔记。
            
            特性亮点：
            - 贴靠在屏幕右侧或左侧，随叫随到
            - 支持与印象笔记（国内版/国际版）双向实时同步
            - 点击图钉 📌 可锁定窗口常驻屏幕
            - 支持 Markdown 语法与待办复选框
            """,
            notebookGuid: defaultNotebook.guid,
            updatedAt: Date(),
            color: .blue,
            isPinned: true
        )

        let note2 = Note(
            guid: UUID().uuidString,
            title: "📝 今日待办清单",
            content: """
            - [x] 下载并体验印象笔记 SideNotes
            - [ ] 在设置中填入印象笔记 Developer Token
            - [ ] 同步并管理已有的印象笔记笔记本
            - [ ] 享受轻量极致的随时记录体验
            """,
            notebookGuid: defaultNotebook.guid,
            updatedAt: Date().addingTimeInterval(-3600),
            color: .green,
            isPinned: false
        )

        let note3 = Note(
            guid: UUID().uuidString,
            title: "💡 快捷键与操作技巧",
            content: """
            ### 快捷使用提示
            - 状态栏图标：点击菜单栏的 📝 图标快速唤出/隐藏侧边栏
            - 切换笔记本：点击顶部的笔记本名称随时切换或新建
            - 颜色标记：给每张笔记赋予不同的心情主题色
            """,
            notebookGuid: defaultNotebook.guid,
            updatedAt: Date().addingTimeInterval(-7200),
            color: .orange,
            isPinned: false
        )

        return ([defaultNotebook, workNotebook], [note1, note2, note3])
    }
}
