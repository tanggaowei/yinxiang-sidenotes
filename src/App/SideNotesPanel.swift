import Cocoa
import SwiftUI

@objc private protocol PanelTextEditActionSelectors {
    func undo(_ sender: Any?)
    func redo(_ sender: Any?)
}

class SideNotesPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.animationBehavior = .none
        self.isMovable = false
        self.isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override func becomeKey() {
        super.becomeKey()
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        if flags == .command {
            if super.performKeyEquivalent(with: event) {
                return true
            }

            guard let chars = event.charactersIgnoringModifiers else {
                return false
            }

            switch chars.lowercased() {
            case "x":
                return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
            case "c":
                return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
            case "v":
                return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "z":
                return NSApp.sendAction(#selector(PanelTextEditActionSelectors.undo(_:)), to: nil, from: self)
            default:
                break
            }
        } else if flags == [.command, .shift] {
            if super.performKeyEquivalent(with: event) {
                return true
            }

            guard let chars = event.charactersIgnoringModifiers else {
                return false
            }

            if chars.lowercased() == "z" {
                return NSApp.sendAction(#selector(PanelTextEditActionSelectors.redo(_:)), to: nil, from: self)
            }
        }

        return super.performKeyEquivalent(with: event)
    }
}
