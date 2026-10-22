import Cocoa
import SwiftUI

@objc private protocol TextEditActionSelectors {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
    func pasteAsPlainText(_ sender: Any?)
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager = WindowManager.shared
    private var storage = StorageManager.shared
    private var noteViewModel = NoteViewModel()

    private static var sharedDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        sharedDelegate = delegate
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as accessory app (no Dock icon, status bar resident)
        NSApp.setActivationPolicy(.accessory)

        // Setup standard main menu (Crucial for Edit shortcuts like Cmd+C, Cmd+V, Cmd+X, Cmd+A, Cmd+Z)
        setupMainMenu()

        let settings = storage.loadSettings()

        // Wrap SwiftUI root view
        let rootView = AnyView(
            SideNotesView(viewModel: self.noteViewModel)
        )

        // Setup floating edge panel
        windowManager.setup(
            rootView: rootView,
            initialDock: settings.dockSide,
            initialPinned: settings.isPinned
        )

        // Setup macOS Menu Bar Status Item
        StatusItemManager.shared.setup(
            onToggle: { [weak self] in
                self?.windowManager.togglePanel()
            },
            onNewNote: { [weak self] in
                self?.windowManager.showPanel()
                self?.noteViewModel.createNewNote()
            },
            onSyncNow: { [weak self] in
                self?.noteViewModel.syncWithYinxiang()
            },
            onOpenPreferences: { [weak self] in
                self?.windowManager.showPanel()
                self?.noteViewModel.isSettingsOpen = true
            }
        )

        // Setup Global HotKey: Command + Option + S
        HotKeyManager.shared.register { [weak self] in
            self?.windowManager.togglePanel()
        }

        // Show panel on launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.windowManager.showPanel(animated: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        windowManager.showPanel(animated: true)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        noteViewModel.saveLocalData()
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 印象笔记 SideNotes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "隐藏 印象笔记 SideNotes", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = NSMenuItem(title: "隐藏其他", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)
        appMenu.addItem(withTitle: "显示全部", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "退出 印象笔记 SideNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. Edit menu (Core for standard shortcuts Cmd+C, Cmd+V, Cmd+X, Cmd+A, Cmd+Z)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")

        editMenu.addItem(withTitle: "撤销", action: #selector(TextEditActionSelectors.undo(_:)), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "重做", action: #selector(TextEditActionSelectors.redo(_:)), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let pasteAndMatchStyleItem = NSMenuItem(title: "粘贴并匹配样式", action: #selector(TextEditActionSelectors.pasteAsPlainText(_:)), keyEquivalent: "v")
        pasteAndMatchStyleItem.keyEquivalentModifierMask = [.command, .option, .shift]
        editMenu.addItem(pasteAndMatchStyleItem)
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
