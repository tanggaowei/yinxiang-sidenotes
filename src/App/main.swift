import Cocoa
import SwiftUI

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
}
