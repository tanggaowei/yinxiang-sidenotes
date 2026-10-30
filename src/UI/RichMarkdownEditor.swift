import SwiftUI
import AppKit

// MARK: - Rich Markdown Text View Representable
struct RichMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    var noteColor: NoteColor
    var noteId: String
    var onTextChange: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autoresizingMask = [.width, .height]

        let contentSize = scrollView.contentSize
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NotionStyleTextView(frame: NSRect(origin: .zero, size: contentSize), textContainer: textContainer)
        textView.minSize = NSSize(width: 0.0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isContinuousSpellCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Base typing attributes to ensure new text inherits correct font & paragraph style
        let baseFont = NSFont.systemFont(ofSize: 13.5, weight: .regular)
        let baseParagraph = NSMutableParagraphStyle()
        baseParagraph.lineSpacing = 5
        baseParagraph.paragraphSpacing = 4
        textView.typingAttributes = [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: baseParagraph
        ]

        // Insets
        textView.textContainerInset = NSSize(width: 12, height: 8)

        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        // Initial text & formatting
        context.coordinator.updateTextIfChanged(newText: text, noteColor: noteColor, noteId: noteId)

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard (nsView.documentView as? NotionStyleTextView) != nil else { return }
        context.coordinator.parent = self
        context.coordinator.updateTextIfChanged(newText: text, noteColor: noteColor, noteId: noteId)
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichMarkdownEditor
        weak var textView: NotionStyleTextView?
        private var isFormatting = false
        private var currentNoteId: String = ""
        private var lastAppliedColor: NoteColor? = nil
        private var formatWorkItem: DispatchWorkItem?

        init(_ parent: RichMarkdownEditor) {
            self.parent = parent
        }

        func updateTextIfChanged(newText: String, noteColor: NoteColor, noteId: String) {
            guard let textView = textView else { return }

            // 1. If note changed completely (switched to another note in list)
            if currentNoteId != noteId {
                formatWorkItem?.cancel()
                currentNoteId = noteId
                lastAppliedColor = noteColor
                textView.string = newText
                applyMarkdownStyles(textView: textView, noteColor: noteColor)
                return
            }

            // 2. CRITICAL: If IME (Pinyin/CJK) composition is in progress, NEVER touch textView!
            if textView.hasMarkedText() {
                return
            }

            // 3. If user is currently focused and typing in this editor, do NOT overwrite text
            let isFocused = (textView.window?.firstResponder == textView)

            if textView.string != newText {
                if !isFocused {
                    formatWorkItem?.cancel()
                    let selectedRanges = textView.selectedRanges
                    textView.string = newText
                    applyMarkdownStyles(textView: textView, noteColor: noteColor)
                    textView.selectedRanges = selectedRanges
                }
            } else if lastAppliedColor != noteColor {
                lastAppliedColor = noteColor
                applyMarkdownStyles(textView: textView, noteColor: noteColor)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView, !isFormatting else { return }

            // CRITICAL: If IME composition (Pinyin) is still underway, DO NOT format or sync yet!
            // Formatting will strip marked text attributes and kill unfinished Pinyin.
            if textView.hasMarkedText() {
                return
            }

            handleTextCommitted(textView: textView)
        }

        func handleTextCommitted(textView: NotionStyleTextView) {
            guard !isFormatting else { return }
            if textView.hasMarkedText() { return }

            let updated = textView.string
            if parent.text != updated {
                parent.text = updated
                parent.onTextChange?()
            }

            // Debounce markdown styling (50ms) to allow IME window closure and caret positioning
            // to settle smoothly without frame tearing or flickering
            formatWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak textView] in
                guard let self = self, let textView = textView else { return }
                self.applyMarkdownStyles(textView: textView, noteColor: self.parent.noteColor)
            }
            formatWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: workItem)
        }

        // MARK: - Live Markdown Highlighting (Notion / Bear Style) with Differential Updates
        func applyMarkdownStyles(textView: NotionStyleTextView, noteColor: NoteColor) {
            // Guard against calling while user is in active IME composition
            if textView.hasMarkedText() { return }

            guard let textStorage = textView.textStorage else { return }
            let text = textStorage.string
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            if fullRange.length == 0 { return }

            isFormatting = true
            defer { isFormatting = false }

            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            // Base font & paragraph style
            let baseFont = NSFont.systemFont(ofSize: 13.5, weight: .regular)
            let baseColor = NSColor.labelColor

            let baseParagraph = NSMutableParagraphStyle()
            baseParagraph.lineSpacing = 5
            baseParagraph.paragraphSpacing = 4

            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: baseParagraph
            ]

            // 1. Build target attributed string purely in memory
            let target = NSMutableAttributedString(string: text, attributes: baseAttributes)
            let nsText = text as NSString
            let accentNS = noteColor.nsAccentColor(isDark: isDark)
            let dimSyntaxColor = NSColor.secondaryLabelColor.withAlphaComponent(0.4)

            // 2. Line-by-line block formatting (Headings, Checklists, Lists, Quotes)
            nsText.enumerateSubstrings(in: fullRange, options: .byLines) { line, lineRange, _, _ in
                guard let line = line else { return }

                // Headings
                if line.hasPrefix("# ") {
                    let markerRange = NSRange(location: lineRange.location, length: 2)
                    let textRange = NSRange(location: lineRange.location + 2, length: lineRange.length - 2)
                    let h1Font = NSFont.systemFont(ofSize: 18.5, weight: .bold)

                    target.addAttribute(.foregroundColor, value: accentNS.withAlphaComponent(0.45), range: markerRange)
                    target.addAttribute(.font, value: NSFont.systemFont(ofSize: 12, weight: .bold), range: markerRange)
                    target.addAttribute(.font, value: h1Font, range: textRange)
                    target.addAttribute(.foregroundColor, value: baseColor, range: textRange)
                } else if line.hasPrefix("## ") {
                    let markerRange = NSRange(location: lineRange.location, length: 3)
                    let textRange = NSRange(location: lineRange.location + 3, length: lineRange.length - 3)
                    let h2Font = NSFont.systemFont(ofSize: 16.0, weight: .semibold)

                    target.addAttribute(.foregroundColor, value: accentNS.withAlphaComponent(0.45), range: markerRange)
                    target.addAttribute(.font, value: NSFont.systemFont(ofSize: 11, weight: .semibold), range: markerRange)
                    target.addAttribute(.font, value: h2Font, range: textRange)
                    target.addAttribute(.foregroundColor, value: baseColor, range: textRange)
                } else if line.hasPrefix("### ") {
                    let markerRange = NSRange(location: lineRange.location, length: 4)
                    let textRange = NSRange(location: lineRange.location + 4, length: lineRange.length - 4)
                    let h3Font = NSFont.systemFont(ofSize: 14.5, weight: .semibold)

                    target.addAttribute(.foregroundColor, value: accentNS.withAlphaComponent(0.45), range: markerRange)
                    target.addAttribute(.font, value: NSFont.systemFont(ofSize: 10, weight: .semibold), range: markerRange)
                    target.addAttribute(.font, value: h3Font, range: textRange)
                    target.addAttribute(.foregroundColor, value: baseColor, range: textRange)
                }
                // Checklists
                else if line.contains("[ ]") {
                    if let boxRange = line.range(of: "[ ]") {
                        let nsBoxRange = NSRange(boxRange, in: line)
                        let boxTarget = NSRange(location: lineRange.location + nsBoxRange.location, length: nsBoxRange.length)
                        target.addAttribute(.foregroundColor, value: accentNS, range: boxTarget)
                        target.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), range: boxTarget)
                    }
                } else if line.contains("[x]") || line.contains("[X]") {
                    if let boxRange = line.range(of: "[x]", options: .caseInsensitive) {
                        let nsBoxRange = NSRange(boxRange, in: line)
                        let boxTarget = NSRange(location: lineRange.location + nsBoxRange.location, length: nsBoxRange.length)
                        target.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: boxTarget)
                        target.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13, weight: .bold), range: boxTarget)

                        // Strikethrough remaining text on this line
                        let afterBox = lineRange.location + nsBoxRange.location + nsBoxRange.length
                        if afterBox < lineRange.location + lineRange.length {
                            let textLength = (lineRange.location + lineRange.length) - afterBox
                            let strikeRange = NSRange(location: afterBox, length: textLength)
                            target.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: strikeRange)
                            target.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: strikeRange)
                        }
                    }
                }
                // Blockquotes
                else if line.hasPrefix("> ") {
                    let markerRange = NSRange(location: lineRange.location, length: 2)
                    let textRange = NSRange(location: lineRange.location + 2, length: lineRange.length - 2)
                    let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

                    target.addAttribute(.foregroundColor, value: accentNS, range: markerRange)
                    target.addAttribute(.font, value: italicFont, range: textRange)
                    target.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: textRange)
                }
                // Bullet List
                else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                    let markerRange = NSRange(location: lineRange.location, length: 2)
                    target.addAttribute(.foregroundColor, value: accentNS, range: markerRange)
                    target.addAttribute(.font, value: NSFont.systemFont(ofSize: 14, weight: .bold), range: markerRange)
                }
            }

            // 3. Inline formatting (Bold, Italic, Inline Code, Code Block, Links)
            // Bold: **text**
            applyRegex(pattern: #"\*\*([^\*]+)\*\*"#, in: nsText) { match in
                let full = match.range
                let inner = match.range(at: 1)
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location, length: 2))
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location + full.length - 2, length: 2))
                target.addAttribute(.font, value: NSFont.systemFont(ofSize: 13.5, weight: .bold), range: inner)
            }

            // Italic: *text* (excluding **)
            applyRegex(pattern: #"(?<!\*)\*([^\*\n]+)\*(?!\*)"#, in: nsText) { match in
                let full = match.range
                let inner = match.range(at: 1)
                let italicFont = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location, length: 1))
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location + full.length - 1, length: 1))
                target.addAttribute(.font, value: italicFont, range: inner)
            }

            // Inline code: `code`
            let codeBg = isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.06)
            applyRegex(pattern: #"`([^`\n]+)`"#, in: nsText) { match in
                let full = match.range
                let inner = match.range(at: 1)
                let monoFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .medium)
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location, length: 1))
                target.addAttribute(.foregroundColor, value: dimSyntaxColor, range: NSRange(location: full.location + full.length - 1, length: 1))
                target.addAttribute(.font, value: monoFont, range: inner)
                target.addAttribute(.foregroundColor, value: accentNS, range: inner)
                target.addAttribute(.backgroundColor, value: codeBg, range: full)
            }

            // Multi-line Code Block: ```...```
            let blockBg = isDark ? NSColor.black.withAlphaComponent(0.25) : NSColor.black.withAlphaComponent(0.04)
            applyRegex(pattern: #"```[\w]*\n[\s\S]*?```"#, in: nsText) { match in
                let full = match.range
                let monoFont = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
                target.addAttribute(.font, value: monoFont, range: full)
                target.addAttribute(.backgroundColor, value: blockBg, range: full)
            }

            // Links: [text](url)
            applyRegex(pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, in: nsText) { match in
                let textRange = match.range(at: 1)
                target.addAttribute(.foregroundColor, value: NSColor.linkColor, range: textRange)
                target.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
            }

            // 4. Differential attribute update to textStorage:
            // Only update ranges where attributes genuinely differ. Avoids wiping fullRange attributes
            // which triggers destructive layout invalidation and CJK/IME font-fallback flickering!
            textStorage.beginEditing()
            target.enumerateAttributes(in: fullRange, options: []) { targetAttributes, targetRange, _ in
                textStorage.enumerateAttributes(in: targetRange, options: []) { currentAttributes, subRange, _ in
                    if !self.areAttributesCompatible(currentAttributes, targetAttributes) {
                        textStorage.setAttributes(targetAttributes, range: subRange)
                    }
                }
            }
            textStorage.endEditing()
        }

        // Check if font is compatible, accounting for macOS CJK CoreText Font Fallback
        // (e.g. .PingFangSC substituted for .AppleSystemUIFont at the same size and weight)
        private func isFontCompatible(_ current: NSFont, target: NSFont) -> Bool {
            if current.isEqual(target) { return true }
            if abs(current.pointSize - target.pointSize) > 0.01 { return false }

            let currentTraits = NSFontManager.shared.traits(of: current)
            let targetTraits = NSFontManager.shared.traits(of: target)
            if currentTraits.contains(.boldFontMask) != targetTraits.contains(.boldFontMask) {
                return false
            }
            if currentTraits.contains(.italicFontMask) != targetTraits.contains(.italicFontMask) {
                return false
            }

            let isCurrentMono = currentTraits.contains(.fixedPitchFontMask) || current.isFixedPitch
            let isTargetMono = targetTraits.contains(.fixedPitchFontMask) || target.isFixedPitch
            if isCurrentMono != isTargetMono {
                return false
            }

            return true
        }

        private func areAttributesCompatible(_ current: [NSAttributedString.Key: Any], _ target: [NSAttributedString.Key: Any]) -> Bool {
            for (key, targetVal) in target {
                guard let currentVal = current[key] else { return false }
                if key == .font, let currentFont = currentVal as? NSFont, let targetFont = targetVal as? NSFont {
                    if !isFontCompatible(currentFont, target: targetFont) {
                        return false
                    }
                } else if let objC = currentVal as? NSObject, let objT = targetVal as? NSObject {
                    if !objC.isEqual(objT) {
                        return false
                    }
                } else {
                    return false
                }
            }

            for (key, _) in current {
                if target[key] == nil {
                    // Attributes that must be cleared if not present in target
                    if key == .strikethroughStyle || key == .underlineStyle || key == .backgroundColor {
                        return false
                    }
                }
            }

            return true
        }

        private func applyRegex(pattern: String, in text: NSString, handler: (NSTextCheckingResult) -> Void) {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
            let matches = regex.matches(in: text as String, options: [], range: NSRange(location: 0, length: text.length))
            for match in matches {
                handler(match)
            }
        }
    }
}

// MARK: - Notion-Style Custom NSTextView with Interactive Checkbox Click
class NotionStyleTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        let clickPoint = convert(event.locationInWindow, from: nil)
        let charIndex = characterIndexForInsertion(at: clickPoint)

        // Check if user clicked on a checkbox [ ] or [x]
        if let (range, isChecked) = findCheckboxRange(near: charIndex) {
            let replacement = isChecked ? "[ ]" : "[x]"
            if shouldChangeText(in: range, replacementString: replacement) {
                textStorage?.replaceCharacters(in: range, with: replacement)
                didChangeText()
                return
            }
        }

        super.mouseDown(with: event)
    }

    private func findCheckboxRange(near charIndex: Int) -> (NSRange, Bool)? {
        guard let textStorage = textStorage else { return nil }
        let text = textStorage.string as NSString
        let totalLen = text.length
        if totalLen == 0 { return nil }

        // Find the line range containing this click
        let lineRange = text.lineRange(for: NSRange(location: min(charIndex, totalLen - 1), length: 0))
        let line = text.substring(with: lineRange)

        if let boxRange = line.range(of: "[ ]") {
            let nsBox = NSRange(boxRange, in: line)
            let absRange = NSRange(location: lineRange.location + nsBox.location, length: nsBox.length)
            // Allow clicking within 2 characters of the box
            if charIndex >= absRange.location - 1 && charIndex <= absRange.location + absRange.length + 1 {
                return (absRange, false)
            }
        }

        if let boxRange = line.range(of: "[x]", options: .caseInsensitive) {
            let nsBox = NSRange(boxRange, in: line)
            let absRange = NSRange(location: lineRange.location + nsBox.location, length: nsBox.length)
            if charIndex >= absRange.location - 1 && charIndex <= absRange.location + absRange.length + 1 {
                return (absRange, true)
            }
        }

        return nil
    }
}

// MARK: - Extension for NSColor Accent
extension NoteColor {
    func nsAccentColor(isDark: Bool) -> NSColor {
        switch self {
        case .gray:
            return isDark ? .hex(0x94A3B8) : .hex(0x64748B)
        case .orange:
            return isDark ? .hex(0xFBBF24) : .hex(0xD97706)
        case .green:
            return isDark ? .hex(0x4ADE80) : .hex(0x16A34A)
        case .blue:
            return isDark ? .hex(0x60A5FA) : .hex(0x2563EB)
        case .purple:
            return isDark ? .hex(0xC084FC) : .hex(0x9333EA)
        case .red:
            return isDark ? .hex(0xFB7185) : .hex(0xE11D48)
        }
    }
}
