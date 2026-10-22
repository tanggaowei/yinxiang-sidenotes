import Cocoa

class StatusItemManager: NSObject {
    static let shared = StatusItemManager()

    private var statusItem: NSStatusItem?
    private var onTogglePanel: (() -> Void)?
    private var onNewNote: (() -> Void)?
    private var onSyncNow: (() -> Void)?
    private var onOpenPreferences: (() -> Void)?

    private override init() {
        super.init()
    }

    func setup(
        onToggle: @escaping () -> Void,
        onNewNote: @escaping () -> Void,
        onSyncNow: @escaping () -> Void,
        onOpenPreferences: @escaping () -> Void
    ) {
        self.onTogglePanel = onToggle
        self.onNewNote = onNewNote
        self.onSyncNow = onSyncNow
        self.onOpenPreferences = onOpenPreferences

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = item

        if let button = item.button {
            if #available(macOS 11.0, *) {
                let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "印象笔记 SideNotes")
                image?.isTemplate = true
                button.image = image
            } else {
                button.title = "📝"
            }
            button.target = self
            button.action = #selector(handleStatusItemClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let currentEvent = NSApp.currentEvent
        if currentEvent?.type == .rightMouseUp || currentEvent?.modifierFlags.contains(.control) == true {
            showContextMenu()
        } else {
            onTogglePanel?()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }

        let menu = NSMenu()

        let toggleItem = NSMenuItem(title: "显示/隐藏 SideNotes", action: #selector(menuToggle), keyEquivalent: "s")
        toggleItem.keyEquivalentModifierMask = [.command, .option]
        toggleItem.target = self
        menu.addItem(toggleItem)

        let newItem = NSMenuItem(title: "新建笔记", action: #selector(menuNewNote), keyEquivalent: "n")
        newItem.keyEquivalentModifierMask = [.command]
        newItem.target = self
        menu.addItem(newItem)

        menu.addItem(NSMenuItem.separator())

        let syncItem = NSMenuItem(title: "立即同步印象笔记", action: #selector(menuSyncNow), keyEquivalent: "r")
        syncItem.keyEquivalentModifierMask = [.command]
        syncItem.target = self
        menu.addItem(syncItem)

        let prefItem = NSMenuItem(title: "偏好设置...", action: #selector(menuPreferences), keyEquivalent: ",")
        prefItem.keyEquivalentModifierMask = [.command]
        prefItem.target = self
        menu.addItem(prefItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出 SideNotes", action: #selector(menuQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil // reset so single-click still toggles
    }

    @objc private func menuToggle() {
        onTogglePanel?()
    }

    @objc private func menuNewNote() {
        onNewNote?()
    }

    @objc private func menuSyncNow() {
        onSyncNow?()
    }

    @objc private func menuPreferences() {
        onOpenPreferences?()
    }

    @objc private func menuQuit() {
        NSApp.terminate(nil)
    }
}
