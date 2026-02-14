import SwiftUI
import AppKit

final class NotionMarkdownTextView: NSTextView {
    // Visual signature for list marker rendering: dot + short bar.
    // Keep stable unless policy is intentionally revised.
    static let bulletVisualSignature = "dot-bar-v1"
    static let markerColumnOffset: CGFloat = 22
    static let bulletIconSize: CGFloat = 14
    static let toggleIconSize: CGFloat = 18
    static let checkboxIconSize: CGFloat = 17
    static let bulletVerticalOffset: CGFloat = 0.15
    static let toggleVerticalOffset: CGFloat = 0.10
    static let checkboxVerticalOffset: CGFloat = 0.80
    static let taskTextGapMin: CGFloat = 8
    static let taskTextGapMax: CGFloat = 26
    static let bulletGuideWidth: CGFloat = 6.5
    static let bulletGuideHeight: CGFloat = 1.6
    static let bulletGuideGap: CGFloat = 3.8

    struct SlashCommandItem {
        let title: String
        let template: String
    }

    static let slashCommandItems: [SlashCommandItem] = [
        .init(title: "텍스트", template: ""),
        .init(title: "제목1", template: "# "),
        .init(title: "제목2", template: "## "),
        .init(title: "제목3", template: "### "),
        .init(title: "글머리 기호 목록", template: "- "),
        .init(title: "번호 매기기 목록", template: "1. "),
        .init(title: "할 일 목록", template: "- [ ] "),
        .init(title: "토글 목록", template: "> "),
        .init(title: "페이지", template: "# 새 페이지\n\n"),
        .init(title: "콜아웃", template: "> 💡 "),
        .init(title: "인용", template: "\" "),
        .init(title: "코드 블록", template: "```\n\n```"),
        .init(title: "구분선", template: "---"),
        .init(title: "표", template: "| Column 1 | Column 2 | Column 3 |\n| --- | --- | --- |\n| | | |"),
    ]

    enum DecorationKind {
        case bullet
        case toggle
        case checkbox
    }

    struct LineDecoration {
        let kind: DecorationKind
        let markerLocation: Int
        let isCollapsed: Bool
        let isChecked: Bool

        init(kind: DecorationKind, markerLocation: Int, isCollapsed: Bool, isChecked: Bool = false) {
            self.kind = kind
            self.markerLocation = markerLocation
            self.isCollapsed = isCollapsed
            self.isChecked = isChecked
        }
    }

    var lineDecorations: [LineDecoration] = [] {
        didSet { needsDisplay = true }
    }

    var onToggleClick: ((Int) -> Void)?
    var onCheckboxClick: ((Int) -> Void)?
    var onToggleShortcutAtCaret: (() -> Bool)?

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard layoutManager != nil, textStorage != nil else { return }
        for decoration in lineDecorations {
            guard let frame = decorationFrame(for: decoration) else { continue }
            drawDecoration(decoration, in: frame)
        }
    }

    override func mouseDown(with event: NSEvent) {
        if handleDecorationClick(event) {
            return
        }
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if isToggleShortcutEvent(event), onToggleShortcutAtCaret?() == true {
            return
        }
        super.keyDown(with: event)
    }

    func toggleMarkdownWrap(_ marker: String) {
        let sel = selectedRange()
        let nsText = string as NSString

        if sel.length > 0 {
            let selected = nsText.substring(with: sel)
            let markerLen = (marker as NSString).length

            // Check if already wrapped
            if selected.hasPrefix(marker) && selected.hasSuffix(marker) && selected.count > markerLen * 2 {
                let inner = String(selected.dropFirst(markerLen).dropLast(markerLen))
                guard shouldChangeText(in: sel, replacementString: inner) else { return }
                textStorage?.replaceCharacters(in: sel, with: inner)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location, length: (inner as NSString).length))
            } else {
                let wrapped = marker + selected + marker
                guard shouldChangeText(in: sel, replacementString: wrapped) else { return }
                textStorage?.replaceCharacters(in: sel, with: wrapped)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location + markerLen, length: sel.length))
            }
        } else {
            let markerLen = (marker as NSString).length
            let insert = marker + marker
            guard shouldChangeText(in: sel, replacementString: insert) else { return }
            textStorage?.replaceCharacters(in: sel, with: insert)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + markerLen, length: 0))
        }
    }

    func showSlashCommandMenu() {
        guard let layoutManager, let textContainer else { return }
        let sel = selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: sel.location, length: 0), actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let origin = textContainerOrigin
        let menuPoint = NSPoint(x: rect.minX + origin.x, y: rect.maxY + origin.y + 4)

        let menu = NSMenu(title: "블록 삽입")
        for slashItem in Self.slashCommandItems {
            let item = NSMenuItem(title: slashItem.title, action: #selector(slashCommandAction(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = slashItem.template
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: menuPoint, in: self)
    }

    @objc private func slashCommandAction(_ sender: NSMenuItem) {
        guard let template = sender.representedObject as? String else { return }
        let sel = selectedRange()
        // Delete the "/" character that triggered the menu
        let deleteRange = NSRange(location: max(0, sel.location - 1), length: sel.location > 0 ? 1 : 0)
        let nsText = string as NSString
        if deleteRange.length > 0, nsText.substring(with: deleteRange) == "/" {
            guard shouldChangeText(in: deleteRange, replacementString: template) else { return }
            textStorage?.replaceCharacters(in: deleteRange, with: template)
            didChangeText()
            // Position cursor: for code blocks, between the fences
            if template.hasPrefix("```") {
                setSelectedRange(NSRange(location: deleteRange.location + 4, length: 0))
            } else if template.contains("\n") {
                setSelectedRange(NSRange(location: deleteRange.location + (template as NSString).length, length: 0))
            } else {
                setSelectedRange(NSRange(location: deleteRange.location + (template as NSString).length, length: 0))
            }
        }
    }

    func insertLinkTemplate() {
        let sel = selectedRange()
        let nsText = string as NSString

        if sel.length > 0 {
            let selected = nsText.substring(with: sel)
            let template = "[\(selected)]()"
            guard shouldChangeText(in: sel, replacementString: template) else { return }
            textStorage?.replaceCharacters(in: sel, with: template)
            didChangeText()
            // Place cursor inside the URL parentheses
            setSelectedRange(NSRange(location: sel.location + (selected as NSString).length + 3, length: 0))
        } else {
            let template = "[]()"
            guard shouldChangeText(in: sel, replacementString: template) else { return }
            textStorage?.replaceCharacters(in: sel, with: template)
            didChangeText()
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
        }
    }

    private func handleDecorationClick(_ event: NSEvent) -> Bool {
        let local = convert(event.locationInWindow, from: nil)

        for decoration in lineDecorations where decoration.kind == .toggle || decoration.kind == .checkbox {
            guard let frame = decorationFrame(for: decoration) else { continue }
            let hitRect = frame.insetBy(dx: -10, dy: -7)

            if hitRect.contains(local) {
                if decoration.kind == .toggle {
                    onToggleClick?(decoration.markerLocation)
                } else {
                    onCheckboxClick?(decoration.markerLocation)
                }
                return true
            }
        }

        return false
    }

    private func isToggleShortcutEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasToggleModifier = flags.contains(.command) || flags.contains(.option)
        if !hasToggleModifier { return false }

        // Return / Enter on ANSI keyboards
        if event.keyCode == 36 || event.keyCode == 76 {
            return true
        }
        return event.charactersIgnoringModifiers == "\r" || event.charactersIgnoringModifiers == "\n"
    }

    private func decorationFrame(for decoration: LineDecoration) -> NSRect? {
        guard let layoutManager else { return nil }
        guard decoration.markerLocation >= 0, decoration.markerLocation < string.utf16.count else { return nil }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: decoration.markerLocation, length: 1),
            actualCharacterRange: nil
        )
        if glyphRange.location == NSNotFound { return nil }

        let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        let iconSize: CGFloat
        let verticalOffset: CGFloat
        switch decoration.kind {
        case .toggle:
            iconSize = Self.toggleIconSize
            verticalOffset = Self.toggleVerticalOffset
        case .checkbox:
            iconSize = Self.checkboxIconSize
            verticalOffset = Self.checkboxVerticalOffset
        case .bullet:
            iconSize = Self.bulletIconSize
            verticalOffset = Self.bulletVerticalOffset
        }

        let origin = textContainerOrigin
        return NSRect(
            x: origin.x + usedRect.minX - Self.markerColumnOffset,
            y: origin.y + usedRect.midY - (iconSize / 2) + verticalOffset,
            width: iconSize,
            height: iconSize
        )
    }

    private func drawDecoration(_ decoration: LineDecoration, in frame: NSRect) {
        let symbolColor = NSColor(calibratedRed: 0.44, green: 0.49, blue: 0.56, alpha: 0.96)

        switch decoration.kind {
        case .bullet:
            let dotRect = frame.insetBy(dx: frame.width * 0.30, dy: frame.height * 0.30)
            let path = NSBezierPath(ovalIn: dotRect)
            symbolColor.setFill()
            path.fill()

            let barRect = NSRect(
                x: dotRect.maxX + Self.bulletGuideGap,
                y: frame.midY - (Self.bulletGuideHeight / 2),
                width: Self.bulletGuideWidth,
                height: Self.bulletGuideHeight
            )
            let barPath = NSBezierPath(
                roundedRect: barRect,
                xRadius: Self.bulletGuideHeight / 2,
                yRadius: Self.bulletGuideHeight / 2
            )
            symbolColor.withAlphaComponent(0.78).setFill()
            barPath.fill()
        case .toggle:
            let triangle = NSBezierPath()
            if decoration.isCollapsed {
                triangle.move(to: NSPoint(x: frame.minX + 4.5, y: frame.minY + 2.8))
                triangle.line(to: NSPoint(x: frame.minX + 4.5, y: frame.maxY - 2.8))
                triangle.line(to: NSPoint(x: frame.maxX - 2.8, y: frame.midY))
            } else {
                triangle.move(to: NSPoint(x: frame.minX + 2.8, y: frame.maxY - 4.5))
                triangle.line(to: NSPoint(x: frame.maxX - 2.8, y: frame.maxY - 4.5))
                triangle.line(to: NSPoint(x: frame.midX, y: frame.minY + 3.4))
            }
            triangle.close()
            symbolColor.setFill()
            triangle.fill()
        case .checkbox:
            let boxRect = frame.insetBy(dx: 1.2, dy: 1.2)
            let box = NSBezierPath(roundedRect: boxRect, xRadius: 2.5, yRadius: 2.5)
            symbolColor.setStroke()
            box.lineWidth = 1.45
            box.stroke()
            if decoration.isChecked {
                let check = NSBezierPath()
                check.move(to: NSPoint(x: boxRect.minX + 2.3, y: boxRect.midY - 0.8))
                check.line(to: NSPoint(x: boxRect.midX - 0.6, y: boxRect.minY + 2.6))
                check.line(to: NSPoint(x: boxRect.maxX - 2.0, y: boxRect.maxY - 2.5))
                check.lineWidth = 1.65
                check.lineCapStyle = .round
                check.lineJoinStyle = .round
                symbolColor.setStroke()
                check.stroke()
            }
        }
    }
}

struct PlainMarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let fontName: String
    let fontSize: Double
    let lineSpacing: Double

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let textView = NotionMarkdownTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.usesFontPanel = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: 24, height: 14)
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.insertionPointColor = NSColor.textColor
        textView.onToggleClick = { [weak coordinator = context.coordinator] location in
            coordinator?.toggleCollapse(at: location)
        }
        textView.onCheckboxClick = { [weak coordinator = context.coordinator] location in
            coordinator?.toggleCheckbox(at: location)
        }
        textView.onToggleShortcutAtCaret = { [weak coordinator = context.coordinator] in
            coordinator?.toggleAtCurrentCaret() ?? false
        }
        textView.delegate = context.coordinator
        textView.string = text

        context.coordinator.applyTypography(to: textView)
        context.coordinator.textView = textView
        scrollView.documentView = textView

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = nsView.documentView as? NSTextView else { return }

        if textView.string != text {
            context.coordinator.isProgrammaticChange = true
            textView.string = text
            context.coordinator.isProgrammaticChange = false
        }
        context.coordinator.applyTypographyIfNeeded(to: textView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        private enum ContinuationMode {
            case task(indent: String, marker: String)
            case list(indent: String, marker: String)
            case ordered(indent: String, number: Int, delimiter: String)
            case quote(indent: String, marker: String)
            case toggleChild(indent: String)
        }

        private static let taskLineContinuationRegex = try! NSRegularExpression(
            pattern: "^(\\s*)([-*+]|\\d+[\\.)])(\\s+)\\[(?: |x|X)?\\](\\s*)(.*)$"
        )
        private static let bulletLineContinuationRegex = try! NSRegularExpression(
            pattern: "^(\\s*)([-*+])(\\s+)(.*)$"
        )
        private static let orderedLineContinuationRegex = try! NSRegularExpression(
            pattern: "^(\\s*)(\\d+)([\\.)])(\\s+)(.*)$"
        )
        private static let quoteLineContinuationRegex = try! NSRegularExpression(
            pattern: "^(\\s*)(>+)(\\s*)(.*)$"
        )
        private static let notionQuoteLineContinuationRegex = try! NSRegularExpression(
            pattern: "^(\\s*)(\")(\\s*)(.*)$"
        )
        private static let quickTodoLineRegex = try! NSRegularExpression(
            pattern: "^(\\s*)\\[(?:\\s|x|X)?\\]$"
        )
        private static let listBoundaryRegex = try! NSRegularExpression(
            pattern: "^([-*+]|\\d+[\\.)])\\s+"
        )

        // Block-level regexes (cached)
        private static let headingRegex = try! NSRegularExpression(pattern: "^(#{1,6})(\\s+)(.+)$")
        private static let listRegex = try! NSRegularExpression(pattern: "^(\\s*)([-*+]|\\d+\\.)(\\s+)(.*)$")
        private static let taskListRegex = try! NSRegularExpression(pattern: "^(\\s*)([-*+]|\\d+\\.)(\\s+)(\\[(?: |x|X)?\\])(\\s*)(.*)$")
        private static let setextUnderlineRegex = try! NSRegularExpression(pattern: "^(=+|-+)\\s*$")
        private static let horizontalRuleRegex = try! NSRegularExpression(pattern: "^\\s*([*\\-_])(?:\\s*\\1){2,}\\s*$")
        private static let tableSeparatorRegex = try! NSRegularExpression(pattern: "^\\s*\\|?(\\s*:?-{3,}:?\\s*\\|)+\\s*:?-{3,}:?\\s*\\|?\\s*$")
        private static let footnoteDefinitionRegex = try! NSRegularExpression(pattern: "^(\\s*)(\\[\\^[^\\]]+\\]:)(\\s*)(.*)$")
        private static let notionQuoteRegex = try! NSRegularExpression(pattern: "^(\\s*)(\")(\\s+)(.*)$")
        private static let toggleRegex = try! NSRegularExpression(pattern: "^(\\s*)(>)(\\s+)(.*)$")
        private static let quoteRegex = try! NSRegularExpression(pattern: "^(\\s*>+)(\\s*)(.*)$")

        // Inline regexes (cached)
        private static let inlineCodeRegex = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
        private static let imageRegex = try! NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^\\)\\n]+)\\)")
        private static let linkRegex = try! NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^\\)\\n]+)\\)")
        private static let autoLinkRegex = try! NSRegularExpression(pattern: "<(https?://[^>\\s]+)>")
        private static let boldItalicRegex = try! NSRegularExpression(pattern: "(\\*\\*\\*|___)(?=\\S)(.+?)(?<=\\S)\\1")
        private static let boldRegex = try! NSRegularExpression(pattern: "(\\*\\*|__)(?=\\S)(.+?)(?<=\\S)\\1")
        private static let italicRegex = try! NSRegularExpression(pattern: "(\\*|_)(?=\\S)(.+?)(?<=\\S)\\1")
        private static let strikeRegex = try! NSRegularExpression(pattern: "(~~)(?=\\S)(.+?)(?<=\\S)~~")
        private static let footnoteRefRegex = try! NSRegularExpression(pattern: "\\[\\^[^\\]]+\\]")
        private static let orderedMarkerRegex = try! NSRegularExpression(pattern: "^(\\d+)([\\.)])$")

        var parent: PlainMarkdownEditor
        weak var textView: NSTextView?
        var isProgrammaticChange = false
        private var isApplyingPresentation = false
        private var lastTypographyKey = ""
        private var collapsedToggleMarkers: Set<Int> = []
        private var pendingEditRange: NSRange?
        private var pendingEditDelta: Int = 0

        init(_ parent: PlainMarkdownEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard !isProgrammaticChange, let textView = notification.object as? NSTextView else {
                return
            }
            let value = textView.string

            // Keep IME (e.g. Korean/Japanese) composition stable.
            // Re-applying presentation while marked text exists can make in-progress input invisible.
            if textView.hasMarkedText() {
                if parent.text != value {
                    parent.text = value
                }
                return
            }

            // Adjust collapsed toggle markers based on the edit
            if let editRange = pendingEditRange {
                adjustCollapsedMarkers(editLocation: editRange.location, oldLength: editRange.length, delta: pendingEditDelta)
                pendingEditRange = nil
                pendingEditDelta = 0
            }

            if parent.text != value {
                parent.text = value
            }
            pruneCollapsedMarkers(maxLength: (textView.string as NSString).length)
            applyTypographyIfNeeded(to: textView, force: true)
        }

        private func adjustCollapsedMarkers(editLocation: Int, oldLength: Int, delta: Int) {
            guard !collapsedToggleMarkers.isEmpty else { return }
            var adjusted = Set<Int>()
            for marker in collapsedToggleMarkers {
                if marker < editLocation {
                    adjusted.insert(marker)
                } else if marker >= editLocation + oldLength {
                    adjusted.insert(marker + delta)
                }
                // markers inside the deleted range are discarded
            }
            collapsedToggleMarkers = adjusted
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingPresentation, let textView = notification.object as? NSTextView else {
                return
            }
            if textView.hasMarkedText() {
                return
            }
            applyTypographyIfNeeded(to: textView, force: true)
        }

        private static let autoPairs: [String: String] = [
            "(": ")", "[": "]", "{": "}", "`": "`"
        ]
        private static let closingChars: Set<String> = [")", "]", "}", "`"]

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            guard let replacement = replacementString else { return true }

            // Track edit for collapsed toggle marker adjustment
            pendingEditRange = affectedCharRange
            pendingEditDelta = (replacement as NSString).length - affectedCharRange.length

            // Notion-like shortcut: [] + space => - [ ] and [x] + space => - [x]
            if replacement == " " && affectedCharRange.length == 0 {
                let nsText = textView.string as NSString
                let caretLocation = affectedCharRange.location
                let lineRange = nsText.lineRange(for: NSRange(location: caretLocation, length: 0))
                let contentRange = lineContentRange(lineRange: lineRange, text: nsText)
                if caretLocation == NSMaxRange(contentRange) {
                    let typedRange = NSRange(location: lineRange.location, length: caretLocation - lineRange.location)
                    let typedPrefix = nsText.substring(with: typedRange)
                    let local = NSRange(location: 0, length: (typedPrefix as NSString).length)

                    if let match = Self.quickTodoLineRegex.firstMatch(in: typedPrefix, options: [], range: local) {
                        let indent = string(typedPrefix, range: match.range(at: 1))
                        let trimmed = typedPrefix.trimmingCharacters(in: .whitespaces)
                        let state = trimmed.lowercased().contains("x") ? "x" : " "
                        let todoLine = "\(indent)- [\(state)] "
                        let todoLength = (todoLine as NSString).length

                        pendingEditRange = typedRange
                        pendingEditDelta = todoLength - typedRange.length

                        guard textView.shouldChangeText(in: typedRange, replacementString: todoLine) else { return false }
                        textView.textStorage?.replaceCharacters(in: typedRange, with: todoLine)
                        textView.didChangeText()
                        textView.setSelectedRange(NSRange(location: typedRange.location + todoLength, length: 0))
                        return false
                    }
                }
            }

            // Slash command: show menu when "/" is typed at start of an empty line
            if replacement == "/" && affectedCharRange.length == 0 {
                let nsText = textView.string as NSString
                let lineRange = nsText.lineRange(for: NSRange(location: affectedCharRange.location, length: 0))
                let lineContent = lineContentRange(lineRange: lineRange, text: nsText)
                let line = nsText.substring(with: lineContent).trimmingCharacters(in: .whitespaces)
                if line.isEmpty {
                    // Allow the "/" to be typed first, then show menu
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        guard let notionView = self?.textView as? NotionMarkdownTextView else { return }
                        notionView.showSlashCommandMenu()
                    }
                    pendingEditRange = nil
                    return true
                }
            }

            // Auto-pairing: wrap selection with pair
            if affectedCharRange.length > 0, let closing = Self.autoPairs[replacement] {
                let nsText = textView.string as NSString
                let selected = nsText.substring(with: affectedCharRange)
                let wrapped = replacement + selected + closing
                pendingEditRange = affectedCharRange
                pendingEditDelta = (wrapped as NSString).length - affectedCharRange.length
                guard textView.shouldChangeText(in: affectedCharRange, replacementString: wrapped) else { return false }
                textView.textStorage?.replaceCharacters(in: affectedCharRange, with: wrapped)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: affectedCharRange.length))
                return false
            }

            // Auto-pairing: insert pair
            if affectedCharRange.length == 0, let closing = Self.autoPairs[replacement] {
                let insert = replacement + closing
                pendingEditRange = affectedCharRange
                pendingEditDelta = (insert as NSString).length - affectedCharRange.length
                guard textView.shouldChangeText(in: affectedCharRange, replacementString: insert) else { return false }
                textView.textStorage?.replaceCharacters(in: affectedCharRange, with: insert)
                textView.didChangeText()
                textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
                return false
            }

            // Skip over closing character
            if affectedCharRange.length == 0, Self.closingChars.contains(replacement) {
                let nsText = textView.string as NSString
                if affectedCharRange.location < nsText.length {
                    let nextChar = nsText.substring(with: NSRange(location: affectedCharRange.location, length: 1))
                    if nextChar == replacement {
                        textView.setSelectedRange(NSRange(location: affectedCharRange.location + 1, length: 0))
                        return false
                    }
                }
            }

            return true
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                if hasToggleShortcutModifierEvent(), handleToggleShortcutLineBreak(in: textView) {
                    return true
                }
                return handleAutoContinuationNewline(in: textView)
            }
            if commandSelector == #selector(NSResponder.insertLineBreak(_:))
                || commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))
            {
                if hasToggleShortcutModifierEvent(), handleToggleShortcutLineBreak(in: textView) {
                    return true
                }
                return handleAutoContinuationNewline(in: textView)
            }
            // Delete both chars of auto-pair when backspacing between them
            if commandSelector == #selector(NSResponder.deleteBackward(_:)) {
                let sel = textView.selectedRange()
                if sel.length == 0, sel.location > 0, sel.location < (textView.string as NSString).length {
                    let nsText = textView.string as NSString
                    let before = nsText.substring(with: NSRange(location: sel.location - 1, length: 1))
                    let after = nsText.substring(with: NSRange(location: sel.location, length: 1))
                    if Self.autoPairs[before] == after {
                        let deleteRange = NSRange(location: sel.location - 1, length: 2)
                        guard textView.shouldChangeText(in: deleteRange, replacementString: "") else { return false }
                        textView.textStorage?.replaceCharacters(in: deleteRange, with: "")
                        textView.didChangeText()
                        textView.setSelectedRange(NSRange(location: sel.location - 1, length: 0))
                        return true
                    }
                }
            }
            return false
        }

        private func hasToggleShortcutModifierEvent() -> Bool {
            guard let event = NSApp.currentEvent, event.type == .keyDown else {
                return false
            }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags.contains(.command) || flags.contains(.option)
        }

        private func handleToggleShortcutLineBreak(in textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }

            let nsText = textView.string as NSString
            let caretLocation = min(selection.location, nsText.length)
            let lineRange = nsText.lineRange(for: NSRange(location: caretLocation, length: 0))
            let lineContent = lineContentRange(lineRange: lineRange, text: nsText)
            let line = nsText.substring(with: lineContent)
            let local = NSRange(location: 0, length: (line as NSString).length)

            // Policy: Cmd/Alt+Enter should toggle current block state.
            // For task list lines, toggle checkbox first.
            if let task = Self.taskListRegex.firstMatch(in: line, options: [], range: local) {
                let checkboxLocation = lineRange.location + task.range(at: 4).location
                toggleCheckbox(at: checkboxLocation)
                return true
            }

            guard let match = Self.toggleRegex.firstMatch(in: line, options: [], range: local) else {
                let currentIndent = leadingIndentCount(in: line)
                guard currentIndent > 0 else { return false }
                guard let ancestorMarker = nearestToggleAncestorMarker(
                    currentLineStart: lineRange.location,
                    currentIndent: currentIndent,
                    text: nsText
                ) else { return false }
                toggleCollapse(at: ancestorMarker)
                return true
            }

            let markerLocation = lineRange.location + match.range(at: 2).location
            toggleCollapse(at: markerLocation)
            return true
        }

        func toggleCollapse(at markerLocation: Int) {
            if collapsedToggleMarkers.contains(markerLocation) {
                collapsedToggleMarkers.remove(markerLocation)
            } else {
                collapsedToggleMarkers.insert(markerLocation)
            }
            guard let textView else { return }
            applyTypographyIfNeeded(to: textView, force: true)
        }

        func toggleAtCurrentCaret() -> Bool {
            guard let textView else { return false }
            return handleToggleShortcutLineBreak(in: textView)
        }

        func toggleCheckbox(at markerLocation: Int) {
            guard let textView, let storage = textView.textStorage else { return }
            let nsText = storage.string as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: markerLocation, length: 0))
            let line = nsText.substring(with: lineRange)
            let localRange = NSRange(location: 0, length: (line as NSString).length)

            guard let match = Self.taskListRegex.firstMatch(in: line, options: [], range: localRange) else { return }
            let checkboxRange = match.range(at: 4)
            let checkboxToken = (line as NSString).substring(with: checkboxRange)
            let isChecked = checkboxToken.contains("x") || checkboxToken.contains("X")
            let replacement = isChecked ? "[ ]" : "[x]"
            let absoluteCheckboxRange = NSRange(location: lineRange.location + checkboxRange.location, length: checkboxRange.length)

            guard textView.shouldChangeText(in: absoluteCheckboxRange, replacementString: replacement) else { return }
            storage.replaceCharacters(in: absoluteCheckboxRange, with: replacement)
            textView.didChangeText()
            parent.text = textView.string
            applyTypographyIfNeeded(to: textView, force: true)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let urlString = link as? String, let url = URL(string: urlString) {
                return NSWorkspace.shared.open(url)
            }
            if let url = link as? URL {
                return NSWorkspace.shared.open(url)
            }
            return false
        }

        func applyTypography(to textView: NSTextView) {
            guard !isApplyingPresentation else { return }
            guard let storage = textView.textStorage else { return }
            isApplyingPresentation = true
            defer { isApplyingPresentation = false }

            let selected = textView.selectedRanges
            let activeLineRange = activeLineRange(in: textView, text: storage.string as NSString)

            let font = NSFont(name: parent.fontName, size: parent.fontSize) ?? NSFont.systemFont(ofSize: parent.fontSize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = parent.lineSpacing
            paragraph.paragraphSpacing = max(3.0, parent.lineSpacing * 0.65)
            paragraph.hyphenationFactor = 0.22
            paragraph.lineBreakStrategy = [.hangulWordPriority, .pushOut]

            let baseColor = NSColor(calibratedRed: 0.23, green: 0.21, blue: 0.18, alpha: 0.98)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: baseColor,
                .paragraphStyle: paragraph
            ]

            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: NSRange(location: 0, length: storage.length))
            let decorations = applyMarkdownPresentation(
                in: storage,
                baseFont: font,
                activeLineRange: activeLineRange
            )
            storage.endEditing()

            if let notionTextView = textView as? NotionMarkdownTextView {
                notionTextView.lineDecorations = decorations
            }
            textView.selectedRanges = selected
            textView.typingAttributes = normalizedTypingAttributes(
                for: textView,
                storage: storage,
                baseFont: font,
                baseColor: baseColor,
                fallbackParagraph: paragraph
            )
            lastTypographyKey = typographyKey(for: storage.string)
        }

        func applyTypographyIfNeeded(to textView: NSTextView, force: Bool = false) {
            let key = typographyKey(for: textView.string)
            if force || key != lastTypographyKey {
                applyTypography(to: textView)
            } else if textView.typingAttributes.isEmpty {
                // NSTextView can lose typing attributes after external updates.
                applyTypography(to: textView)
            }
        }

        private func typographyKey(for text: String) -> String {
            "\(parent.fontName)|\(parent.fontSize)|\(parent.lineSpacing)|\(text.utf16.count)|\(text.hashValue)"
        }

        private func applyMarkdownPresentation(
            in storage: NSTextStorage,
            baseFont: NSFont,
            activeLineRange: NSRange?
        ) -> [NotionMarkdownTextView.LineDecoration] {
            let nsText = storage.string as NSString
            let fullLength = nsText.length
            if fullLength == 0 {
                return []
            }

            let headingRegex = Self.headingRegex
            let listRegex = Self.listRegex
            let taskListRegex = Self.taskListRegex
            let setextUnderlineRegex = Self.setextUnderlineRegex
            let horizontalRuleRegex = Self.horizontalRuleRegex
            let tableSeparatorRegex = Self.tableSeparatorRegex
            let footnoteDefinitionRegex = Self.footnoteDefinitionRegex
            let notionQuoteRegex = Self.notionQuoteRegex
            let toggleRegex = Self.toggleRegex
            let quoteRegex = Self.quoteRegex
            let inlineCodeRegex = Self.inlineCodeRegex
            let imageRegex = Self.imageRegex
            let linkRegex = Self.linkRegex
            let autoLinkRegex = Self.autoLinkRegex
            let boldItalicRegex = Self.boldItalicRegex
            let boldRegex = Self.boldRegex
            let italicRegex = Self.italicRegex
            let strikeRegex = Self.strikeRegex
            let footnoteRefRegex = Self.footnoteRefRegex

            var location = 0
            var insideFence = false
            var insideFrontMatter = false
            var previousLineContentRange: NSRange?
            var previousLineHadText = false
            var decorations: [NotionMarkdownTextView.LineDecoration] = []
            var collapsedToggleIndent: Int?

            while location < fullLength {
                let lineRange = nsText.lineRange(for: NSRange(location: location, length: 0))
                let lineText = nsText.substring(with: lineRange)
                let lineWithoutNewline = lineText.replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                let contentRange = lineContentRange(lineRange: lineRange, text: nsText)
                let trimmed = lineWithoutNewline.trimmingCharacters(in: .whitespaces)
                let isActiveLine = isSameLine(lineRange, activeLineRange)
                // Prevent accidental setext heading conversion while the user is typing
                // a fresh single "-" list marker.
                let suppressTransientSetext = isActiveLine && (trimmed == "-" || trimmed == "=")
                let localRange = NSRange(location: 0, length: (lineWithoutNewline as NSString).length)
                let currentIndent = leadingIndentCount(in: lineWithoutNewline)
                let isToggleHeaderLine = toggleRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) != nil
                let isNotionQuoteLine = notionQuoteRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) != nil

                if let indent = collapsedToggleIndent {
                    if isBoundaryForCollapsedToggle(
                        line: lineWithoutNewline,
                        trimmed: trimmed,
                        currentIndent: currentIndent,
                        collapsedIndent: indent,
                        isToggleHeaderLine: isToggleHeaderLine,
                        isNotionQuoteLine: isNotionQuoteLine
                    ) {
                        collapsedToggleIndent = nil
                    } else {
                        storage.addAttributes(collapsedLineAttributes(baseFont: baseFont), range: lineRange)
                        previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                        previousLineHadText = !trimmed.isEmpty
                        location = NSMaxRange(lineRange)
                        continue
                    }
                }

                if location == 0, trimmed == "---" {
                    insideFrontMatter = true
                    storage.addAttributes(frontMatterAttributes(baseFont: baseFont), range: contentRange)
                    previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                    previousLineHadText = !trimmed.isEmpty
                    location = NSMaxRange(lineRange)
                    continue
                }

                if insideFrontMatter {
                    storage.addAttributes(frontMatterAttributes(baseFont: baseFont), range: contentRange)
                    if trimmed == "---" || trimmed == "..." {
                        insideFrontMatter = false
                    }
                    previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                    previousLineHadText = !trimmed.isEmpty
                    location = NSMaxRange(lineRange)
                    continue
                }

                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    insideFence.toggle()
                    let fenceRange = contentRange
                    let fenceMarker = trimmed.hasPrefix("```") ? "```" : "~~~"
                    let fenceAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(11, baseFont.pointSize * 0.80),
                            weight: .medium
                        ),
                        .foregroundColor: NSColor(calibratedRed: 0.50, green: 0.54, blue: 0.60, alpha: 1)
                    ]
                    storage.addAttributes(fenceAttributes, range: fenceRange)

                    // Highlight language identifier (e.g., ```python)
                    let langPart = String(trimmed.dropFirst(fenceMarker.count)).trimmingCharacters(in: .whitespaces)
                    if !langPart.isEmpty && insideFence {
                        let langStart = lineWithoutNewline.range(of: langPart)
                        if let swiftRange = langStart {
                            let nsRange = NSRange(swiftRange, in: lineWithoutNewline)
                            let absLangRange = absoluteRange(local: nsRange, lineStart: lineRange.location)
                            storage.addAttributes(
                                [
                                    .font: NSFont.monospacedSystemFont(ofSize: max(11, baseFont.pointSize * 0.80), weight: .semibold),
                                    .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.45, blue: 0.62, alpha: 1)
                                ],
                                range: absLangRange
                            )
                        }
                    }

                    previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                    previousLineHadText = !trimmed.isEmpty
                    location = NSMaxRange(lineRange)
                    continue
                }

                if insideFence {
                    let codeRange = contentRange
                    let codeAttributes: [NSAttributedString.Key: Any] = [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(12, baseFont.pointSize * 0.86),
                            weight: .regular
                        ),
                        .foregroundColor: NSColor(calibratedRed: 0.18, green: 0.24, blue: 0.32, alpha: 1),
                        .backgroundColor: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1)
                    ]
                    storage.addAttributes(codeAttributes, range: codeRange)
                    previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                    previousLineHadText = !trimmed.isEmpty
                    location = NSMaxRange(lineRange)
                    continue
                }

                if localRange.length > 0 {
                    if let heading = headingRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerRange = heading.range(at: 1)
                        let spacerRange = heading.range(at: 2)
                        let titleRange = heading.range(at: 3)
                        let level = markerRange.length

                        let hiddenMarkerRange = NSRange(
                            location: markerRange.location,
                            length: markerRange.length + spacerRange.length
                        )
                        let hiddenAbsolute = absoluteRange(local: hiddenMarkerRange, lineStart: lineRange.location)
                        let titleAbsolute = absoluteRange(local: titleRange, lineStart: lineRange.location)
                        let titleLineAbsolute = lineContentRange(lineRange: lineRange, text: nsText)

                        if isActiveLine {
                            let visibleMarkerAttributes: [NSAttributedString.Key: Any] = [
                                .font: NSFont.systemFont(
                                    ofSize: max(11, baseFont.pointSize * 0.73),
                                    weight: .semibold
                                ),
                                .foregroundColor: NSColor(calibratedRed: 0.54, green: 0.58, blue: 0.65, alpha: 0.82),
                                .kern: -0.2
                            ]
                            storage.addAttributes(visibleMarkerAttributes, range: hiddenAbsolute)
                        } else {
                            let hiddenAttributes: [NSAttributedString.Key: Any] = [
                                .font: NSFont.systemFont(ofSize: 0.5),
                                .foregroundColor: NSColor(calibratedWhite: 0.55, alpha: 0.12),
                                .kern: -baseFont.pointSize * 0.46
                            ]
                            storage.addAttributes(hiddenAttributes, range: hiddenAbsolute)
                        }

                        let titleScale = headingScale(for: level)

                        let titleAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: baseFont.pointSize * titleScale, weight: .semibold),
                            .foregroundColor: headingColor(for: level),
                            .paragraphStyle: headingParagraph(for: level)
                        ]
                        storage.addAttributes([.paragraphStyle: headingParagraph(for: level)], range: titleLineAbsolute)
                        storage.addAttributes(titleAttributes, range: titleAbsolute)
                    }

                    if let setext = setextUnderlineRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange),
                       let previousLine = previousLineContentRange,
                       previousLineHadText,
                       !suppressTransientSetext
                    {
                        let underlineToken = (lineWithoutNewline as NSString).substring(with: setext.range(at: 1))
                        let level = underlineToken.hasPrefix("=") ? 1 : 2
                        let markerAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: max(9, baseFont.pointSize * 0.56), weight: .regular),
                            .foregroundColor: isActiveLine
                                ? NSColor(calibratedRed: 0.56, green: 0.60, blue: 0.67, alpha: 0.84)
                                : NSColor(calibratedRed: 0.70, green: 0.73, blue: 0.78, alpha: 0.48),
                            .kern: 0.8
                        ]
                        storage.addAttributes(markerAttributes, range: contentRange)
                        storage.addAttributes(
                            [
                                .font: NSFont.systemFont(ofSize: baseFont.pointSize * headingScale(for: level), weight: .semibold),
                                .foregroundColor: headingColor(for: level),
                                .paragraphStyle: headingParagraph(for: level)
                            ],
                            range: previousLine
                        )
                    } else if horizontalRuleRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) != nil {
                        let hrAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: max(9, baseFont.pointSize * 0.54), weight: .regular),
                            .foregroundColor: isActiveLine
                                ? NSColor(calibratedRed: 0.56, green: 0.60, blue: 0.67, alpha: 0.76)
                                : NSColor(calibratedRed: 0.73, green: 0.75, blue: 0.79, alpha: 0.50),
                            .kern: 1.1
                        ]
                        storage.addAttributes(hrAttributes, range: contentRange)
                    }

                    if let task = taskListRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerSpaceAbsolute = absoluteRange(
                            local: NSRange(
                                location: task.range(at: 2).location,
                                length: task.range(at: 2).length + task.range(at: 3).length
                            ),
                            lineStart: lineRange.location
                        )
                        let checkboxAbsolute = absoluteRange(local: task.range(at: 4), lineStart: lineRange.location)
                        let contentAbsolute = absoluteRange(local: task.range(at: 6), lineStart: lineRange.location)
                        let checkboxToken = (lineWithoutNewline as NSString).substring(with: task.range(at: 4))
                        let isChecked = checkboxToken.contains("x") || checkboxToken.contains("X")

                        storage.addAttributes(
                            [.paragraphStyle: listParagraph(for: baseFont, taskLine: true)],
                            range: contentRange
                        )

                        storage.addAttributes(
                            hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.34),
                            range: markerSpaceAbsolute
                        )

                        let checkboxAttributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.monospacedSystemFont(
                                ofSize: max(12, baseFont.pointSize * 0.86),
                                weight: .semibold
                            ),
                            .foregroundColor: isChecked
                                ? (isActiveLine
                                    ? NSColor(calibratedRed: 0.23, green: 0.49, blue: 0.37, alpha: 0.98)
                                    : NSColor(calibratedRed: 0.40, green: 0.57, blue: 0.48, alpha: 0.84))
                                : (isActiveLine
                                    ? NSColor(calibratedRed: 0.31, green: 0.43, blue: 0.62, alpha: 0.95)
                                    : NSColor(calibratedRed: 0.50, green: 0.56, blue: 0.66, alpha: 0.78))
                        ]
                        storage.addAttributes(checkboxAttributes, range: checkboxAbsolute)

                        // Hide checkbox text and add clickable decoration
                        storage.addAttributes(
                            hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.30),
                            range: checkboxAbsolute
                        )
                        decorations.append(
                            .init(kind: .checkbox, markerLocation: checkboxAbsolute.location, isCollapsed: false, isChecked: isChecked)
                        )

                        if isChecked, contentAbsolute.length > 0 {
                            storage.addAttributes(
                                [
                                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                                    .strikethroughColor: NSColor(calibratedWhite: 0.58, alpha: 0.82),
                                    .foregroundColor: NSColor(calibratedRed: 0.37, green: 0.41, blue: 0.47, alpha: 0.92)
                                ],
                                range: contentAbsolute
                            )
                        }
                    } else if let list = listRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerAbsolute = absoluteRange(local: list.range(at: 2), lineStart: lineRange.location)
                        let markerToken = (lineWithoutNewline as NSString).substring(with: list.range(at: 2))
                        let isOrderedMarker = parseOrderedMarker(markerToken) != nil
                        let markerSpaceAbsolute = absoluteRange(
                            local: NSRange(
                                location: list.range(at: 2).location,
                                length: list.range(at: 2).length + list.range(at: 3).length
                            ),
                            lineStart: lineRange.location
                        )
                        storage.addAttributes(
                            [.paragraphStyle: listParagraph(for: baseFont, taskLine: false)],
                            range: contentRange
                        )

                        if isOrderedMarker {
                            storage.addAttributes(
                                [
                                    .font: NSFont.systemFont(ofSize: max(12, baseFont.pointSize * 0.88), weight: .semibold),
                                    .foregroundColor: NSColor(calibratedRed: 0.47, green: 0.51, blue: 0.58, alpha: 0.86)
                                ],
                                range: markerAbsolute
                            )
                        } else {
                            storage.addAttributes(
                                hiddenMarkerAttributes(
                                    baseFont: baseFont,
                                    collapseFactor: 0.30,
                                    activeLine: isActiveLine
                                ),
                                range: markerSpaceAbsolute
                            )
                            decorations.append(
                                .init(kind: .bullet, markerLocation: markerAbsolute.location, isCollapsed: false)
                            )
                            storage.addAttributes(
                                hiddenMarkerAttributes(
                                    baseFont: baseFont,
                                    collapseFactor: 0.30,
                                    activeLine: isActiveLine
                                ),
                                range: markerAbsolute
                            )
                        }
                    }

                    if let footnoteDef = footnoteDefinitionRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerAbsolute = absoluteRange(local: footnoteDef.range(at: 2), lineStart: lineRange.location)
                        storage.addAttributes(
                            [
                                .font: NSFont.monospacedSystemFont(
                                    ofSize: max(11, baseFont.pointSize * 0.78),
                                    weight: .medium
                                ),
                                .foregroundColor: NSColor(calibratedRed: 0.44, green: 0.50, blue: 0.59, alpha: 0.92)
                            ],
                            range: markerAbsolute
                        )
                    }

                    if let notionQuote = notionQuoteRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerSpaceAbsolute = absoluteRange(
                            local: NSRange(
                                location: notionQuote.range(at: 2).location,
                                length: notionQuote.range(at: 2).length + notionQuote.range(at: 3).length
                            ),
                            lineStart: lineRange.location
                        )
                        let contentAbsolute = absoluteRange(local: notionQuote.range(at: 4), lineStart: lineRange.location)
                        let quoteLineRange = lineContentRange(lineRange: lineRange, text: nsText)
                        let notionQuoteParagraph = quoteParagraph(for: baseFont, activeLine: isActiveLine)

                        storage.addAttributes([.paragraphStyle: notionQuoteParagraph], range: quoteLineRange)
                        storage.addAttributes(
                            hiddenMarkerAttributes(
                                baseFont: baseFont,
                                collapseFactor: 0.26,
                                activeLine: isActiveLine
                            ),
                            range: markerSpaceAbsolute
                        )
                        storage.addAttributes(
                            [
                                .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .regular),
                                .foregroundColor: NSColor(calibratedRed: 0.33, green: 0.31, blue: 0.28, alpha: 0.94),
                                .paragraphStyle: notionQuoteParagraph
                            ],
                            range: contentAbsolute
                        )
                        storage.addAttributes(
                            [
                                .backgroundColor: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 0.52)
                            ],
                            range: quoteLineRange
                        )
                    } else if let toggle = toggleRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerAbsolute = absoluteRange(local: toggle.range(at: 2), lineStart: lineRange.location)
                        let toggleIndent = leadingIndentCount(in: string(lineWithoutNewline, range: toggle.range(at: 1)))
                        let isCollapsed = collapsedToggleMarkers.contains(markerAbsolute.location)
                        let markerSpaceAbsolute = absoluteRange(
                            local: NSRange(
                                location: toggle.range(at: 2).location,
                                length: toggle.range(at: 2).length + toggle.range(at: 3).length
                            ),
                            lineStart: lineRange.location
                        )
                        let contentAbsolute = absoluteRange(local: toggle.range(at: 4), lineStart: lineRange.location)
                        let toggleLineRange = lineContentRange(lineRange: lineRange, text: nsText)
                        let toggleParagraph = toggleParagraph(for: baseFont)

                        storage.addAttributes([.paragraphStyle: toggleParagraph], range: toggleLineRange)
                        storage.addAttributes(
                            hiddenMarkerAttributes(
                                baseFont: baseFont,
                                collapseFactor: 0.30,
                                activeLine: isActiveLine
                            ),
                            range: markerSpaceAbsolute
                        )
                        storage.addAttributes(
                            [
                                .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold),
                                .foregroundColor: NSColor(calibratedRed: 0.24, green: 0.23, blue: 0.20, alpha: 0.98),
                                .paragraphStyle: toggleParagraph
                            ],
                            range: contentAbsolute
                        )
                        storage.addAttributes(
                            [
                                .backgroundColor: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.97, alpha: isActiveLine ? 0.72 : 0.46)
                            ],
                            range: toggleLineRange
                        )
                        decorations.append(
                            .init(kind: .toggle, markerLocation: markerAbsolute.location, isCollapsed: isCollapsed)
                        )
                        if isCollapsed {
                            collapsedToggleIndent = toggleIndent
                        }
                    } else if let quote = quoteRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) {
                        let markerAbsolute = absoluteRange(local: quote.range(at: 1), lineStart: lineRange.location)
                        let contentAbsolute = absoluteRange(local: quote.range(at: 3), lineStart: lineRange.location)
                        let quoteLineRange = lineContentRange(lineRange: lineRange, text: nsText)
                        let quoteParagraph = quoteParagraph(for: baseFont, activeLine: isActiveLine)

                        storage.addAttributes([.paragraphStyle: quoteParagraph], range: quoteLineRange)
                        storage.addAttributes(
                            [
                                .foregroundColor: NSColor(calibratedWhite: 0.70, alpha: 0.75)
                            ],
                            range: markerAbsolute
                        )
                        storage.addAttributes(
                            [
                                .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .regular),
                                .foregroundColor: NSColor(calibratedRed: 0.33, green: 0.31, blue: 0.28, alpha: 0.94),
                                .paragraphStyle: quoteParagraph
                            ],
                            range: contentAbsolute
                        )
                        storage.addAttributes(
                            [
                                .backgroundColor: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.42)
                            ],
                            range: quoteLineRange
                        )
                    }

                    if tableSeparatorRegex.firstMatch(in: lineWithoutNewline, options: [], range: localRange) != nil {
                        storage.addAttributes(
                            [
                                .font: NSFont.monospacedSystemFont(
                                    ofSize: max(10, baseFont.pointSize * 0.70),
                                    weight: .medium
                                ),
                                .foregroundColor: NSColor(calibratedRed: 0.58, green: 0.62, blue: 0.68, alpha: 0.84)
                            ],
                            range: contentRange
                        )
                    } else if looksLikeTableRow(trimmed: trimmed) {
                        storage.addAttributes(
                            [
                                .font: NSFont.monospacedSystemFont(
                                    ofSize: max(11, baseFont.pointSize * 0.82),
                                    weight: .regular
                                ),
                                .backgroundColor: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.55)
                            ],
                            range: contentRange
                        )
                    }

                    applyInlineMarkdownPresentation(
                        storage: storage,
                        lineWithoutNewline: lineWithoutNewline,
                        localRange: localRange,
                        lineStart: lineRange.location,
                        baseFont: baseFont,
                        isActiveLine: isActiveLine,
                        inlineCodeRegex: inlineCodeRegex,
                        imageRegex: imageRegex,
                        linkRegex: linkRegex,
                        autoLinkRegex: autoLinkRegex,
                        boldItalicRegex: boldItalicRegex,
                        boldRegex: boldRegex,
                        italicRegex: italicRegex,
                        strikeRegex: strikeRegex,
                        footnoteRefRegex: footnoteRefRegex
                    )
                }

                if lineWithoutNewline.hasPrefix("    ") || lineWithoutNewline.hasPrefix("\t") {
                    storage.addAttributes(
                        [
                            .font: NSFont.monospacedSystemFont(
                                ofSize: max(11, baseFont.pointSize * 0.84),
                                weight: .regular
                            ),
                            .backgroundColor: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 0.68)
                        ],
                        range: contentRange
                    )
                }

                previousLineContentRange = contentRange.length > 0 ? contentRange : nil
                previousLineHadText = !trimmed.isEmpty
                location = NSMaxRange(lineRange)
            }

            return decorations
        }

        private func applyInlineMarkdownPresentation(
            storage: NSTextStorage,
            lineWithoutNewline: String,
            localRange: NSRange,
            lineStart: Int,
            baseFont: NSFont,
            isActiveLine: Bool,
            inlineCodeRegex: NSRegularExpression,
            imageRegex: NSRegularExpression,
            linkRegex: NSRegularExpression,
            autoLinkRegex: NSRegularExpression,
            boldItalicRegex: NSRegularExpression,
            boldRegex: NSRegularExpression,
            italicRegex: NSRegularExpression,
            strikeRegex: NSRegularExpression,
            footnoteRefRegex: NSRegularExpression
        ) {
            var protectedRanges: [NSRange] = []

            let fadedSymbolColor = isActiveLine
                ? NSColor(calibratedWhite: 0.56, alpha: 1)
                : NSColor(calibratedWhite: 0.72, alpha: 0.66)

            inlineCodeRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullLocal = match.range(at: 0)
                if fullLocal.length < 2 { return }

                let leftTick = NSRange(location: fullLocal.location, length: 1)
                let rightTick = NSRange(location: fullLocal.location + fullLocal.length - 1, length: 1)
                let contentLocal = NSRange(location: fullLocal.location + 1, length: fullLocal.length - 2)

                let fullAbs = absoluteRange(local: fullLocal, lineStart: lineStart)
                let leftAbs = absoluteRange(local: leftTick, lineStart: lineStart)
                let rightAbs = absoluteRange(local: rightTick, lineStart: lineStart)
                let contentAbs = absoluteRange(local: contentLocal, lineStart: lineStart)

                if isActiveLine {
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: leftAbs)
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: rightAbs)
                } else {
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.18), range: leftAbs)
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.18), range: rightAbs)
                }
                storage.addAttributes(
                    [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(11, baseFont.pointSize * 0.84),
                            weight: .medium
                        ),
                        .foregroundColor: NSColor(calibratedRed: 0.17, green: 0.23, blue: 0.31, alpha: 1),
                        .backgroundColor: NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1)
                    ],
                    range: contentAbs
                )
                protectedRanges.append(fullAbs)
            }

            imageRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullAbs = absoluteRange(local: match.range(at: 0), lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let altAbs = absoluteRange(local: match.range(at: 1), lineStart: lineStart)
                let urlAbs = absoluteRange(local: match.range(at: 2), lineStart: lineStart)

                if !isActiveLine {
                    let fullLocal = match.range(at: 0)
                    let leftMarker = NSRange(location: fullLocal.location, length: 2)
                    let midMarker = NSRange(
                        location: match.range(at: 1).location + match.range(at: 1).length,
                        length: 2
                    )
                    let rightMarker = NSRange(location: fullLocal.location + fullLocal.length - 1, length: 1)
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.22),
                        range: absoluteRange(local: leftMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.20),
                        range: absoluteRange(local: midMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.20),
                        range: absoluteRange(local: rightMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.24),
                        range: urlAbs
                    )
                }

                storage.addAttributes(
                    [
                        .foregroundColor: NSColor(calibratedRed: 0.56, green: 0.47, blue: 0.33, alpha: 0.92)
                    ],
                    range: fullAbs
                )
                storage.addAttributes(
                    [
                        .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
                    ],
                    range: altAbs
                )
                storage.addAttributes(
                    [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(10, baseFont.pointSize * 0.74),
                            weight: .regular
                        ),
                        .foregroundColor: NSColor(calibratedRed: 0.50, green: 0.56, blue: 0.65, alpha: 0.90)
                    ],
                    range: urlAbs
                )
                protectedRanges.append(fullAbs)
            }

            linkRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullAbs = absoluteRange(local: match.range(at: 0), lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let labelAbs = absoluteRange(local: match.range(at: 1), lineStart: lineStart)
                let urlAbs = absoluteRange(local: match.range(at: 2), lineStart: lineStart)

                if !isActiveLine {
                    let fullLocal = match.range(at: 0)
                    let leftMarker = NSRange(location: fullLocal.location, length: 1)
                    let midMarker = NSRange(
                        location: match.range(at: 1).location + match.range(at: 1).length,
                        length: 2
                    )
                    let rightMarker = NSRange(location: fullLocal.location + fullLocal.length - 1, length: 1)
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.20),
                        range: absoluteRange(local: leftMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.20),
                        range: absoluteRange(local: midMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.20),
                        range: absoluteRange(local: rightMarker, lineStart: lineStart)
                    )
                    storage.addAttributes(
                        hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.25),
                        range: urlAbs
                    )
                }

                storage.addAttributes(
                    [
                        .foregroundColor: NSColor(calibratedRed: 0.21, green: 0.42, blue: 0.73, alpha: 0.96)
                    ],
                    range: fullAbs
                )
                let urlString = (lineWithoutNewline as NSString).substring(with: match.range(at: 2))
                storage.addAttributes(
                    [
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .underlineColor: NSColor(calibratedRed: 0.21, green: 0.42, blue: 0.73, alpha: 0.85),
                        .font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .medium),
                        .link: urlString,
                        .cursor: NSCursor.pointingHand
                    ],
                    range: labelAbs
                )
                storage.addAttributes(
                    [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(10, baseFont.pointSize * 0.74),
                            weight: .regular
                        ),
                        .foregroundColor: NSColor(calibratedRed: 0.49, green: 0.55, blue: 0.64, alpha: 0.90)
                    ],
                    range: urlAbs
                )
                protectedRanges.append(fullAbs)
            }

            autoLinkRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullAbs = absoluteRange(local: match.range(at: 0), lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }
                let autoUrlString = (lineWithoutNewline as NSString).substring(with: match.range(at: 1))
                storage.addAttributes(
                    [
                        .foregroundColor: NSColor(calibratedRed: 0.21, green: 0.42, blue: 0.73, alpha: 0.96),
                        .underlineStyle: NSUnderlineStyle.single.rawValue,
                        .link: autoUrlString,
                        .cursor: NSCursor.pointingHand
                    ],
                    range: fullAbs
                )
                protectedRanges.append(fullAbs)
            }

            strikeRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullLocal = match.range(at: 0)
                let contentLocal = match.range(at: 2)
                if fullLocal.length < 4 { return }

                let fullAbs = absoluteRange(local: fullLocal, lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let leftAbs = absoluteRange(local: NSRange(location: fullLocal.location, length: 2), lineStart: lineStart)
                let rightAbs = absoluteRange(local: NSRange(location: fullLocal.location + fullLocal.length - 2, length: 2), lineStart: lineStart)
                let contentAbs = absoluteRange(local: contentLocal, lineStart: lineStart)

                if isActiveLine {
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: leftAbs)
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: rightAbs)
                } else {
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.18), range: leftAbs)
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.18), range: rightAbs)
                }
                storage.addAttributes(
                    [
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .strikethroughColor: NSColor(calibratedWhite: 0.56, alpha: 0.84),
                        .foregroundColor: NSColor(calibratedRed: 0.38, green: 0.42, blue: 0.48, alpha: 0.94)
                    ],
                    range: contentAbs
                )
                protectedRanges.append(fullAbs)
            }

            boldItalicRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullLocal = match.range(at: 0)
                let markerLocal = match.range(at: 1)
                let contentLocal = match.range(at: 2)
                if fullLocal.length < markerLocal.length * 2 + 1 { return }

                let fullAbs = absoluteRange(local: fullLocal, lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let rightLocal = NSRange(
                    location: fullLocal.location + fullLocal.length - markerLocal.length,
                    length: markerLocal.length
                )
                let leftAbs = absoluteRange(local: markerLocal, lineStart: lineStart)
                let rightAbs = absoluteRange(local: rightLocal, lineStart: lineStart)
                let contentAbs = absoluteRange(local: contentLocal, lineStart: lineStart)

                let semibold = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
                let boldItalic = NSFontManager.shared.convert(semibold, toHaveTrait: .italicFontMask)

                if isActiveLine {
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: leftAbs)
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: rightAbs)
                } else {
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.17), range: leftAbs)
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.17), range: rightAbs)
                }
                storage.addAttributes([.font: boldItalic], range: contentAbs)
                protectedRanges.append(fullAbs)
            }

            boldRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullLocal = match.range(at: 0)
                let markerLocal = match.range(at: 1)
                let contentLocal = match.range(at: 2)
                if fullLocal.length < markerLocal.length * 2 + 1 { return }

                let fullAbs = absoluteRange(local: fullLocal, lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let rightLocal = NSRange(
                    location: fullLocal.location + fullLocal.length - markerLocal.length,
                    length: markerLocal.length
                )
                let leftAbs = absoluteRange(local: markerLocal, lineStart: lineStart)
                let rightAbs = absoluteRange(local: rightLocal, lineStart: lineStart)
                let contentAbs = absoluteRange(local: contentLocal, lineStart: lineStart)

                if isActiveLine {
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: leftAbs)
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: rightAbs)
                } else {
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.17), range: leftAbs)
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.17), range: rightAbs)
                }
                storage.addAttributes(
                    [.font: NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)],
                    range: contentAbs
                )
                protectedRanges.append(fullAbs)
            }

            italicRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullLocal = match.range(at: 0)
                let markerLocal = match.range(at: 1)
                let contentLocal = match.range(at: 2)
                if fullLocal.length < markerLocal.length * 2 + 1 { return }

                let fullAbs = absoluteRange(local: fullLocal, lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                let rightLocal = NSRange(
                    location: fullLocal.location + fullLocal.length - markerLocal.length,
                    length: markerLocal.length
                )
                let leftAbs = absoluteRange(local: markerLocal, lineStart: lineStart)
                let rightAbs = absoluteRange(local: rightLocal, lineStart: lineStart)
                let contentAbs = absoluteRange(local: contentLocal, lineStart: lineStart)
                let italic = NSFontManager.shared.convert(baseFont, toHaveTrait: .italicFontMask)

                if isActiveLine {
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: leftAbs)
                    storage.addAttributes([.foregroundColor: fadedSymbolColor], range: rightAbs)
                } else {
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.16), range: leftAbs)
                    storage.addAttributes(hiddenMarkerAttributes(baseFont: baseFont, collapseFactor: 0.16), range: rightAbs)
                }
                storage.addAttributes([.font: italic], range: contentAbs)
                protectedRanges.append(fullAbs)
            }

            footnoteRefRegex.enumerateMatches(in: lineWithoutNewline, options: [], range: localRange) { match, _, _ in
                guard let match else { return }
                let fullAbs = absoluteRange(local: match.range(at: 0), lineStart: lineStart)
                if intersectsProtected(fullAbs, protectedRanges) { return }

                storage.addAttributes(
                    [
                        .font: NSFont.monospacedSystemFont(
                            ofSize: max(9, baseFont.pointSize * 0.64),
                            weight: .medium
                        ),
                        .baselineOffset: baseFont.pointSize * 0.24,
                        .foregroundColor: NSColor(calibratedRed: 0.42, green: 0.49, blue: 0.60, alpha: 0.90)
                    ],
                    range: fullAbs
                )
            }
        }

        private func handleAutoContinuationNewline(in textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }

            let nsText = textView.string as NSString
            let caretLocation = min(selection.location, nsText.length)
            let lineRange = nsText.lineRange(for: NSRange(location: caretLocation, length: 0))
            let lineContent = lineContentRange(lineRange: lineRange, text: nsText)
            guard caretLocation == NSMaxRange(lineContent) else { return false }

            let line = nsText.substring(with: lineContent)
            if let (mode, content) = detectContinuationMode(line: line) {
                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Second Enter on an empty list/quote marker exits the block.
                    applyContinuationEdit(
                        in: textView,
                        range: lineContent,
                        replacement: "",
                        newCaretLocation: lineContent.location
                    )
                    return true
                }

                let prefix = continuationPrefix(for: mode)
                let insertion = "\n" + prefix
                applyContinuationEdit(
                    in: textView,
                    range: NSRange(location: caretLocation, length: 0),
                    replacement: insertion,
                    newCaretLocation: caretLocation + insertion.utf16.count
                )
                return true
            }

            // If we're inside a toggle block child line, keep writing at the same indent.
            let indentPrefix = leadingWhitespacePrefix(in: line)
            if !indentPrefix.isEmpty,
               isInsideToggleChild(
                currentLineStart: lineRange.location,
                currentIndent: leadingIndentCount(in: line),
                text: nsText
               )
            {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Empty child line + Enter exits the toggle child context.
                    applyContinuationEdit(
                        in: textView,
                        range: lineContent,
                        replacement: "",
                        newCaretLocation: lineContent.location
                    )
                    return true
                }

                let insertion = "\n" + indentPrefix
                applyContinuationEdit(
                    in: textView,
                    range: NSRange(location: caretLocation, length: 0),
                    replacement: insertion,
                    newCaretLocation: caretLocation + insertion.utf16.count
                )
                return true
            }

            return false
        }

        private func applyContinuationEdit(
            in textView: NSTextView,
            range: NSRange,
            replacement: String,
            newCaretLocation: Int
        ) {
            guard textView.shouldChangeText(in: range, replacementString: replacement) else { return }
            textView.textStorage?.replaceCharacters(in: range, with: replacement)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: newCaretLocation, length: 0))
            applyTypographyIfNeeded(to: textView, force: true)
        }

        private func detectContinuationMode(line: String) -> (ContinuationMode, String)? {
            let local = NSRange(location: 0, length: (line as NSString).length)

            if let match = Self.taskLineContinuationRegex.firstMatch(in: line, options: [], range: local) {
                let indent = string(line, range: match.range(at: 1))
                let marker = string(line, range: match.range(at: 2))
                let content = string(line, range: match.range(at: 5))

                if let ordered = parseOrderedMarker(marker) {
                    return (.ordered(indent: indent, number: ordered.number, delimiter: ordered.delimiter), content)
                }
                return (.task(indent: indent, marker: marker), content)
            }

            if let match = Self.orderedLineContinuationRegex.firstMatch(in: line, options: [], range: local) {
                let indent = string(line, range: match.range(at: 1))
                let number = Int(string(line, range: match.range(at: 2))) ?? 1
                let delimiter = string(line, range: match.range(at: 3))
                let content = string(line, range: match.range(at: 5))
                return (.ordered(indent: indent, number: number, delimiter: delimiter), content)
            }

            if let match = Self.bulletLineContinuationRegex.firstMatch(in: line, options: [], range: local) {
                let indent = string(line, range: match.range(at: 1))
                let marker = string(line, range: match.range(at: 2))
                let content = string(line, range: match.range(at: 4))
                return (.list(indent: indent, marker: marker), content)
            }

            if let match = Self.quoteLineContinuationRegex.firstMatch(in: line, options: [], range: local) {
                let indent = string(line, range: match.range(at: 1))
                let marker = string(line, range: match.range(at: 2))
                let content = string(line, range: match.range(at: 4))
                if marker == ">" {
                    return (.toggleChild(indent: indent), content)
                }
                return (.quote(indent: indent, marker: marker), content)
            }

            if let match = Self.notionQuoteLineContinuationRegex.firstMatch(in: line, options: [], range: local) {
                let indent = string(line, range: match.range(at: 1))
                let marker = string(line, range: match.range(at: 2))
                let content = string(line, range: match.range(at: 4))
                return (.quote(indent: indent, marker: marker), content)
            }

            return nil
        }

        private func continuationPrefix(for mode: ContinuationMode) -> String {
            switch mode {
            case let .task(indent, marker):
                return "\(indent)\(marker) [ ] "
            case let .list(indent, marker):
                return "\(indent)\(marker) "
            case let .ordered(indent, number, delimiter):
                return "\(indent)\(number + 1)\(delimiter) "
            case let .quote(indent, marker):
                return "\(indent)\(marker) "
            case let .toggleChild(indent):
                return "\(indent)  "
            }
        }

        private func leadingWhitespacePrefix(in line: String) -> String {
            var result = ""
            for char in line {
                if char == " " || char == "\t" {
                    result.append(char)
                } else {
                    break
                }
            }
            return result
        }

        private func isInsideToggleChild(currentLineStart: Int, currentIndent: Int, text: NSString) -> Bool {
            guard currentIndent > 0, currentLineStart > 0 else { return false }
            return nearestToggleAncestorMarker(
                currentLineStart: currentLineStart,
                currentIndent: currentIndent,
                text: text
            ) != nil
        }

        private func nearestToggleAncestorMarker(
            currentLineStart: Int,
            currentIndent: Int,
            text: NSString
        ) -> Int? {
            guard currentIndent > 0, currentLineStart > 0 else { return nil }
            var cursor = currentLineStart - 1
            while cursor >= 0 {
                let prevRange = text.lineRange(for: NSRange(location: cursor, length: 0))
                let prevContent = lineContentRange(lineRange: prevRange, text: text)
                let prevLine = text.substring(with: prevContent)
                let trimmed = prevLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let prevIndent = leadingIndentCount(in: prevLine)

                if !trimmed.isEmpty {
                    let local = NSRange(location: 0, length: (prevLine as NSString).length)
                    if let match = Self.toggleRegex.firstMatch(in: prevLine, options: [], range: local) {
                        let toggleIndent = leadingIndentCount(in: string(prevLine, range: match.range(at: 1)))
                        if toggleIndent < currentIndent {
                            return prevRange.location + match.range(at: 2).location
                        }
                    }
                    if prevIndent < currentIndent {
                        return nil
                    }
                }

                if prevRange.location == 0 { break }
                cursor = prevRange.location - 1
            }
            return nil
        }

        private func parseOrderedMarker(_ marker: String) -> (number: Int, delimiter: String)? {
            let local = NSRange(location: 0, length: (marker as NSString).length)
            guard
                let match = Self.orderedMarkerRegex.firstMatch(in: marker, options: [], range: local)
            else {
                return nil
            }
            let number = Int(string(marker, range: match.range(at: 1))) ?? 1
            let delimiter = string(marker, range: match.range(at: 2))
            return (number, delimiter)
        }

        private func string(_ text: String, range: NSRange) -> String {
            guard range.location != NSNotFound else { return "" }
            return (text as NSString).substring(with: range)
        }

        private func lineContentRange(lineRange: NSRange, text: NSString) -> NSRange {
            var length = lineRange.length
            while length > 0 {
                let char = text.character(at: lineRange.location + length - 1)
                if char == 10 || char == 13 {
                    length -= 1
                } else {
                    break
                }
            }
            return NSRange(location: lineRange.location, length: length)
        }

        private func absoluteRange(local: NSRange, lineStart: Int) -> NSRange {
            NSRange(location: lineStart + local.location, length: local.length)
        }

        private func intersectsProtected(_ range: NSRange, _ protectedRanges: [NSRange]) -> Bool {
            protectedRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }

        private func looksLikeTableRow(trimmed: String) -> Bool {
            guard trimmed.hasPrefix("|") || trimmed.hasSuffix("|") else { return false }
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2
        }

        private func frontMatterAttributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont.monospacedSystemFont(
                    ofSize: max(10, baseFont.pointSize * 0.74),
                    weight: .regular
                ),
                .foregroundColor: NSColor(calibratedRed: 0.47, green: 0.52, blue: 0.60, alpha: 0.90),
                .backgroundColor: NSColor(calibratedRed: 0.97, green: 0.98, blue: 0.99, alpha: 0.62)
            ]
        }

        private func hiddenMarkerAttributes(
            baseFont: NSFont,
            collapseFactor: CGFloat,
            activeLine: Bool = false
        ) -> [NSAttributedString.Key: Any] {
            if activeLine {
                let markerFont = NSFont.monospacedSystemFont(
                    ofSize: max(10, baseFont.pointSize * 0.74),
                    weight: .medium
                )
                let alpha = min(0.82, max(0.58, 0.72 - (collapseFactor * 0.25)))
                return [
                    .font: markerFont,
                    .foregroundColor: NSColor(
                        calibratedRed: 0.55,
                        green: 0.59,
                        blue: 0.65,
                        alpha: alpha
                    ),
                    .kern: 0
                ]
            }

            let tiny = max(0.6, baseFont.pointSize * 0.04)
            return [
                .font: NSFont.systemFont(ofSize: tiny, weight: .regular),
                .foregroundColor: NSColor.clear,
                .kern: 0
            ]
        }

        private func normalizedTypingAttributes(
            for textView: NSTextView,
            storage: NSTextStorage,
            baseFont: NSFont,
            baseColor: NSColor,
            fallbackParagraph: NSParagraphStyle
        ) -> [NSAttributedString.Key: Any] {
            var resolved: [NSAttributedString.Key: Any] = [
                .font: baseFont,
                .foregroundColor: baseColor,
                .paragraphStyle: fallbackParagraph
            ]

            guard storage.length > 0 else { return resolved }
            let sel = textView.selectedRange()
            let anchor: Int
            if sel.location > 0 {
                anchor = min(storage.length - 1, sel.location - 1)
            } else {
                anchor = 0
            }
            let attrs = storage.attributes(at: anchor, effectiveRange: nil)
            if let paragraph = attrs[.paragraphStyle] as? NSParagraphStyle {
                resolved[.paragraphStyle] = paragraph
            }
            return resolved
        }

        private func collapsedLineAttributes(baseFont: NSFont) -> [NSAttributedString.Key: Any] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = 0.1
            paragraph.maximumLineHeight = 0.1
            paragraph.paragraphSpacing = 0
            paragraph.paragraphSpacingBefore = 0
            paragraph.lineSpacing = 0

            return [
                .font: NSFont.systemFont(ofSize: 0.1),
                .foregroundColor: NSColor.clear,
                .paragraphStyle: paragraph
            ]
        }

        private func leadingIndentCount(in line: String) -> Int {
            var count = 0
            for char in line {
                if char == " " {
                    count += 1
                } else if char == "\t" {
                    count += 4
                } else {
                    break
                }
            }
            return count
        }

        private func pruneCollapsedMarkers(maxLength: Int) {
            collapsedToggleMarkers = collapsedToggleMarkers.filter { $0 >= 0 && $0 < maxLength }
        }

        private func isBoundaryForCollapsedToggle(
            line: String,
            trimmed: String,
            currentIndent: Int,
            collapsedIndent: Int,
            isToggleHeaderLine: Bool,
            isNotionQuoteLine: Bool
        ) -> Bool {
            if trimmed.isEmpty {
                return true
            }
            if currentIndent > collapsedIndent {
                return false
            }
            if isToggleHeaderLine || isNotionQuoteLine {
                return true
            }
            if trimmed.hasPrefix("#") || trimmed.hasPrefix("---") || trimmed.hasPrefix("***") || trimmed.hasPrefix("___") {
                return true
            }

            let local = NSRange(location: 0, length: (trimmed as NSString).length)
            if Self.listBoundaryRegex.firstMatch(in: trimmed, options: [], range: local) != nil {
                return true
            }

            return false
        }

        private func activeLineRange(in textView: NSTextView, text: NSString) -> NSRange? {
            guard text.length > 0, let selected = textView.selectedRanges.first else {
                return nil
            }
            let selectedRange = selected.rangeValue
            let location = min(max(0, selectedRange.location), max(0, text.length - 1))
            return text.lineRange(for: NSRange(location: location, length: 0))
        }

        private func isSameLine(_ lineRange: NSRange, _ activeLineRange: NSRange?) -> Bool {
            guard let activeLineRange else { return false }
            return lineRange.location == activeLineRange.location
        }

        private func headingScale(for level: Int) -> CGFloat {
            switch level {
            case 1: return 1.70
            case 2: return 1.42
            case 3: return 1.26
            case 4: return 1.14
            case 5: return 1.06
            default: return 1.0
            }
        }

        private func headingParagraph(for level: Int) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = max(1.0, parent.lineSpacing * 0.45)
            paragraph.paragraphSpacing = max(5.0, parent.fontSize * (level <= 2 ? 0.20 : 0.14))
            paragraph.paragraphSpacingBefore = max(4.0, parent.fontSize * (level == 1 ? 0.42 : level == 2 ? 0.30 : 0.16))
            return paragraph
        }

        private func headingColor(for level: Int) -> NSColor {
            switch level {
            case 1:
                return NSColor(calibratedRed: 0.14, green: 0.21, blue: 0.33, alpha: 0.98)
            case 2:
                return NSColor(calibratedRed: 0.17, green: 0.25, blue: 0.35, alpha: 0.96)
            case 3:
                return NSColor(calibratedRed: 0.19, green: 0.27, blue: 0.37, alpha: 0.95)
            case 4:
                return NSColor(calibratedRed: 0.22, green: 0.29, blue: 0.38, alpha: 0.93)
            default:
                return NSColor(calibratedRed: 0.24, green: 0.31, blue: 0.40, alpha: 0.92)
            }
        }

        private func listParagraph(for baseFont: NSFont, taskLine: Bool) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = parent.lineSpacing
            paragraph.paragraphSpacing = max(3.0, parent.lineSpacing * 0.65)
            paragraph.hyphenationFactor = 0.34
            paragraph.lineBreakStrategy = [.hangulWordPriority, .pushOut]
            paragraph.headIndent = baseFont.pointSize * (taskLine ? 1.34 : 1.12)
            paragraph.firstLineHeadIndent = paragraph.headIndent
            return paragraph
        }

        private func quoteParagraph(for baseFont: NSFont, activeLine: Bool) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = max(2.0, parent.lineSpacing * 0.8)
            paragraph.headIndent = baseFont.pointSize * 1.05
            paragraph.firstLineHeadIndent = activeLine
                ? baseFont.pointSize * 0.44
                : paragraph.headIndent
            paragraph.paragraphSpacing = max(3.0, baseFont.pointSize * 0.18)
            paragraph.paragraphSpacingBefore = max(2.0, baseFont.pointSize * 0.08)
            return paragraph
        }

        private func toggleParagraph(for baseFont: NSFont) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = max(2.0, parent.lineSpacing * 0.72)
            paragraph.paragraphSpacing = max(3.0, baseFont.pointSize * 0.18)
            paragraph.paragraphSpacingBefore = max(2.0, baseFont.pointSize * 0.08)
            paragraph.headIndent = baseFont.pointSize * 1.26
            paragraph.firstLineHeadIndent = paragraph.headIndent
            return paragraph
        }
    }
}
