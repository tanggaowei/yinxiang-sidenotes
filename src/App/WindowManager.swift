import Cocoa
import SwiftUI

class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()

    @Published var isVisible: Bool = false
    @Published var dockSide: DockSide = .right
    @Published var isPinned: Bool = false

    private var panel: SideNotesPanel?
    private var visualEffectView: NSVisualEffectView?
    private var hostingView: NSHostingView<AnyView>?
    private var edgeTabPanel: EdgeTabPanel?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?

    private let panelWidth: CGFloat = 360
    private let tabWidth: CGFloat = 8
    private let tabHeight: CGFloat = 50

    private override init() {
        super.init()
    }

    func setup(rootView: AnyView, initialDock: DockSide, initialPinned: Bool) {
        self.dockSide = initialDock
        self.isPinned = initialPinned

        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame

        let initialFrame = calculateFrame(dockSide: initialDock, isVisible: false, screenFrame: visibleFrame)
        let panel = SideNotesPanel(contentRect: initialFrame)
        self.panel = panel

        // Visual effect background (Frosted glass)
        let visualEffect = NSVisualEffectView(frame: NSRect(origin: .zero, size: initialFrame.size))
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .sidebar
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        self.visualEffectView = visualEffect

        // Setup corner mask depending on dock side
        updateVisualEffectMask(dockSide: initialDock, view: visualEffect)

        // Hosting view for SwiftUI
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = visualEffect.bounds
        hosting.autoresizingMask = [.width, .height]
        self.hostingView = hosting

        visualEffect.addSubview(hosting)
        panel.contentView = visualEffect

        // Setup Edge Dock Handle (贴边小把手)
        setupEdgeTab(initialDock: initialDock, screenFrame: visibleFrame)

        // Setup click monitors
        setupClickMonitors()
    }

    private func setupEdgeTab(initialDock: DockSide, screenFrame: NSRect) {
        let tabFrame = calculateTabFrame(dockSide: initialDock, screenFrame: screenFrame)
        let tabPanel = EdgeTabPanel(contentRect: tabFrame)
        self.edgeTabPanel = tabPanel

        updateEdgeTabView(dockSide: initialDock)

        // If main panel is not visible initially, show the tab handle
        if !isVisible {
            tabPanel.orderFrontRegardless()
        }
    }

    private func updateEdgeTabView(dockSide: DockSide) {
        guard let tabPanel = edgeTabPanel else { return }
        let tabView = AnyView(
            EdgeTabView(dockSide: dockSide) { [weak self] in
                self?.showPanel(animated: true)
            }
        )
        let hosting = NSHostingView(rootView: tabView)
        hosting.frame = NSRect(origin: .zero, size: tabPanel.frame.size)
        hosting.autoresizingMask = [.width, .height]
        tabPanel.contentView = hosting
    }

    private func calculateTabFrame(dockSide: DockSide, screenFrame: NSRect) -> NSRect {
        let width = tabWidth
        let height = tabHeight
        let y = screenFrame.midY - (height / 2)

        let x: CGFloat = (dockSide == .right) ? (screenFrame.maxX - width) : screenFrame.origin.x
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func updateVisualEffectMask(dockSide: DockSide, view: NSVisualEffectView) {
        view.wantsLayer = true
        view.layer?.cornerRadius = 16
        if #available(macOS 10.15, *) {
            if dockSide == .right {
                // Round only top-left and bottom-left
                view.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            } else {
                // Round only top-right and bottom-right
                view.layer?.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            }
        }
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.2).cgColor
    }

    private func calculateFrame(dockSide: DockSide, isVisible: Bool, screenFrame: NSRect) -> NSRect {
        let width = panelWidth
        let height = screenFrame.height
        let y = screenFrame.origin.y

        let x: CGFloat
        if dockSide == .right {
            x = isVisible ? (screenFrame.maxX - width) : screenFrame.maxX
        } else {
            x = isVisible ? screenFrame.origin.x : (screenFrame.origin.x - width)
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    func showPanel(animated: Bool = true) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let targetFrame = calculateFrame(dockSide: self.dockSide, isVisible: true, screenFrame: visibleFrame)

        // Hide edge tab while panel is open
        edgeTabPanel?.orderOut(nil)

        if !panel.isVisible {
            // Position just off-screen first
            let offscreenFrame = calculateFrame(dockSide: self.dockSide, isVisible: false, screenFrame: visibleFrame)
            panel.setFrame(offscreenFrame, display: false)
            panel.orderFrontRegardless()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: {
                panel.makeKeyAndOrderFront(nil)
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            panel.makeKeyAndOrderFront(nil)
        }

        self.isVisible = true
    }

    func hidePanel(animated: Bool = true) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let targetFrame = calculateFrame(dockSide: self.dockSide, isVisible: false, screenFrame: visibleFrame)

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(targetFrame, display: true)
            } completionHandler: { [weak self] in
                panel.orderOut(nil)
                // Show edge tab handle once panel is fully hidden
                self?.edgeTabPanel?.orderFrontRegardless()
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            panel.orderOut(nil)
            // Show edge tab handle immediately
            edgeTabPanel?.orderFrontRegardless()
        }

        self.isVisible = false
    }

    func togglePanel() {
        if isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func setDockSide(_ newSide: DockSide) {
        guard newSide != self.dockSide else { return }
        self.dockSide = newSide

        if let visual = visualEffectView {
            updateVisualEffectMask(dockSide: newSide, view: visual)
        }

        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let targetFrame = calculateFrame(dockSide: newSide, isVisible: self.isVisible, screenFrame: visibleFrame)
        panel?.setFrame(targetFrame, display: true, animate: true)

        // Update Edge Tab
        updateEdgeTabView(dockSide: newSide)
        let tabFrame = calculateTabFrame(dockSide: newSide, screenFrame: visibleFrame)
        edgeTabPanel?.setFrame(tabFrame, display: true)
    }

    func setPinned(_ pinned: Bool) {
        self.isPinned = pinned
    }

    private func setupClickMonitors() {
        // Hide on global click outside if not pinned
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible, !self.isPinned else { return }
            guard let panel = self.panel else { return }

            let clickLocation = NSEvent.mouseLocation
            if !panel.frame.contains(clickLocation) {
                self.hidePanel()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
