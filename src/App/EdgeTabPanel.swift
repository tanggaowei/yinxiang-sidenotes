import Cocoa
import SwiftUI

class EdgeTabPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.animationBehavior = .none
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
    }

    override var canBecomeKey: Bool {
        return false
    }

    override var canBecomeMain: Bool {
        return false
    }
}
