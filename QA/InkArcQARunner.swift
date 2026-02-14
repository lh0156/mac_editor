import Foundation
import SwiftUI
import AppKit

@MainActor
@main
struct InkArcQARunner {
    private static let taskLineRegex = try! NSRegularExpression(
        pattern: "^(\\s*)([-*+]|\\d+\\.)(\\s+)(\\[(?: |x|X)?\\])(\\s*)(.*)$"
    )

    private final class TextBox {
        var value: String

        init(_ value: String) {
            self.value = value
        }
    }

    private static func makeHarness(initial: String) -> (PlainMarkdownEditor.Coordinator, NotionMarkdownTextView) {
        let box = TextBox(initial)
        let binding = Binding<String>(
            get: { box.value },
            set: { box.value = $0 }
        )
        let editor = PlainMarkdownEditor(text: binding, fontName: "SF Pro Text", fontSize: 18, lineSpacing: 9)
        let coordinator = PlainMarkdownEditor.Coordinator(editor)
        let textView = NotionMarkdownTextView(frame: NSRect(x: 0, y: 0, width: 960, height: 720))
        textView.string = initial
        textView.delegate = coordinator
        textView.onToggleClick = { [weak coordinator] location in
            coordinator?.toggleCollapse(at: location)
        }
        textView.onCheckboxClick = { [weak coordinator] location in
            coordinator?.toggleCheckbox(at: location)
        }
        coordinator.textView = textView
        textView.onToggleShortcutAtCaret = { [weak coordinator] in
            coordinator?.toggleAtCurrentCaret() ?? false
        }
        coordinator.applyTypography(to: textView)
        return (coordinator, textView)
    }

    private static func pressReturn(
        _ coordinator: PlainMarkdownEditor.Coordinator,
        in textView: NotionMarkdownTextView
    ) -> Bool {
        coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))
    }

    private static func fontSize(of token: String, in textView: NotionMarkdownTextView) -> CGFloat {
        let ns = textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = textView.textStorage else { return -1 }
        let attrs = storage.attributes(at: range.location, effectiveRange: nil)
        return (attrs[.font] as? NSFont)?.pointSize ?? -1
    }

    private static func makeEnterKeyEvent(modifiers: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        )
    }

    private static func attrsAtToken(_ token: String, in textView: NotionMarkdownTextView) -> [NSAttributedString.Key: Any] {
        let ns = textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = textView.textStorage else { return [:] }
        return storage.attributes(at: range.location, effectiveRange: nil)
    }

    private static func applyInput(
        _ input: String,
        coordinator: PlainMarkdownEditor.Coordinator,
        textView: NotionMarkdownTextView
    ) {
        let range = textView.selectedRange()
        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: range,
            replacementString: input
        )
        guard handled else { return }
        textView.textStorage?.replaceCharacters(in: range, with: input)
        textView.didChangeText()
        textView.setSelectedRange(
            NSRange(location: range.location + (input as NSString).length, length: 0)
        )
    }

    private static func isMonospaceFont(_ font: NSFont?) -> Bool {
        guard let font else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.monoSpace)
    }

    private static func lineContentRange(lineRange: NSRange, text: NSString) -> NSRange {
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

    private static func checkboxMetrics(in textView: NotionMarkdownTextView) -> [(gap: CGFloat, yDiff: CGFloat)] {
        guard let lm = textView.layoutManager else { return [] }
        let origin = textView.textContainerOrigin
        let ns = textView.string as NSString

        var metrics: [(CGFloat, CGFloat)] = []
        for decoration in textView.lineDecorations where decoration.kind == .checkbox {
            let markerLoc = decoration.markerLocation
            guard markerLoc >= 0, markerLoc < ns.length else { continue }

            let markerGlyph = lm.glyphRange(
                forCharacterRange: NSRange(location: markerLoc, length: 1),
                actualCharacterRange: nil
            )
            if markerGlyph.location == NSNotFound { continue }

            let markerUsed = lm.lineFragmentUsedRect(forGlyphAt: markerGlyph.location, effectiveRange: nil)
            let iconRect = NSRect(
                x: origin.x + markerUsed.minX - NotionMarkdownTextView.markerColumnOffset,
                y: origin.y + markerUsed.midY - (NotionMarkdownTextView.checkboxIconSize / 2) + NotionMarkdownTextView.checkboxVerticalOffset,
                width: NotionMarkdownTextView.checkboxIconSize,
                height: NotionMarkdownTextView.checkboxIconSize
            )

            let lineRange = ns.lineRange(for: NSRange(location: markerLoc, length: 0))
            let contentRange = lineContentRange(lineRange: lineRange, text: ns)
            let line = ns.substring(with: contentRange)
            let local = NSRange(location: 0, length: (line as NSString).length)

            var contentX = origin.x + markerUsed.maxX
            var lineMidY = origin.y + markerUsed.midY

            if let m = taskLineRegex.firstMatch(in: line, options: [], range: local), m.range(at: 6).length > 0 {
                let contentLoc = lineRange.location + m.range(at: 6).location
                let contentGlyph = lm.glyphRange(
                    forCharacterRange: NSRange(location: contentLoc, length: 1),
                    actualCharacterRange: nil
                )
                if contentGlyph.location != NSNotFound {
                    let glyphPoint = lm.location(forGlyphAt: contentGlyph.location)
                    let contentUsed = lm.lineFragmentUsedRect(forGlyphAt: contentGlyph.location, effectiveRange: nil)
                    contentX = origin.x + glyphPoint.x
                    lineMidY = origin.y + contentUsed.midY
                }
            }

            let gap = contentX - iconRect.maxX
            let yDiff = abs(iconRect.midY - lineMidY)
            metrics.append((gap, yDiff))
        }
        return metrics
    }

    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "- first")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "bullet: Enter not handled")
            expect(textView.string == "- first\n- ", "bullet: continuation mismatch")
            expect(fontSize(of: "first", in: textView) > 1.0, "bullet: previous line text became invalid")
            let typingFont = (textView.typingAttributes[.font] as? NSFont)?.pointSize ?? 0
            expect(typingFont > 10, "bullet: typing font collapsed after continuation")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "bullet: second Enter not handled")
            expect(textView.string == "- first\n", "bullet: double-enter escape mismatch")
        }

        do {
            expect(NotionMarkdownTextView.bulletVisualSignature == "dot-only-v1", "visual signature: bullet signature version mismatch")
        }

        do {
            let provided = Set(NotionMarkdownTextView.slashCommandItems.map { $0.title })
            let required: Set<String> = [
                "텍스트",
                "제목1",
                "제목2",
                "제목3",
                "글머리 기호 목록",
                "번호 매기기 목록",
                "할 일 목록",
                "토글 목록",
                "페이지",
                "콜아웃",
                "인용",
                "코드 블록",
            ]
            expect(required.isSubset(of: provided), "slash palette: required block items are missing")

            if let textItem = NotionMarkdownTextView.slashCommandItems.first(where: { $0.title == "텍스트" }) {
                expect(textItem.template.isEmpty, "slash palette: text block should be plain template")
            } else {
                failures.append("slash palette: 텍스트 item missing")
            }

            let requiredTemplates: [String: String] = [
                "제목1": "# ",
                "제목2": "## ",
                "제목3": "### ",
                "글머리 기호 목록": "- ",
                "번호 매기기 목록": "1. ",
                "할 일 목록": "- [ ] ",
                "토글 목록": "> ",
                "페이지": "# 새 페이지\n\n",
                "콜아웃": "> 💡 ",
                "인용": "\" ",
                "코드 블록": "```\n\n```"
            ]
            for (title, expectedTemplate) in requiredTemplates {
                if let item = NotionMarkdownTextView.slashCommandItems.first(where: { $0.title == title }) {
                    expect(item.template == expectedTemplate, "slash palette: template mismatch for \(title)")
                } else {
                    failures.append("slash palette: \(title) item missing for template validation")
                }
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "```java\nSystem.out.println(\"x\")\n```")
            let attrs = attrsAtToken("System.out", in: textView)
            let font = attrs[.font] as? NSFont
            let bg = attrs[.backgroundColor] as? NSColor
            expect(isMonospaceFont(font), "code block: font should be monospaced")
            expect(bg != nil && bg != NSColor.clear, "code block: background highlight missing")
        }

        do {
            let (_, textView) = makeHarness(initial: "before `code` after")
            let attrs = attrsAtToken("code", in: textView)
            let font = attrs[.font] as? NSFont
            let bg = attrs[.backgroundColor] as? NSColor
            expect(isMonospaceFont(font), "inline code: font should be monospaced")
            expect(bg != nil && bg != NSColor.clear, "inline code: background highlight missing")
        }

        do {
            let (_, textView) = makeHarness(
                initial: """
                - [ ] 테스크 리스트입니다
                - [ ] 후
                - [ ] 오
                - [ ] 오오
                - [ ] 오오오
                """
            )
            let metrics = checkboxMetrics(in: textView)
            expect(metrics.count >= 5, "checkbox alignment: insufficient metric samples")

            for metric in metrics {
                expect(
                    metric.gap >= NotionMarkdownTextView.taskTextGapMin
                        && metric.gap <= NotionMarkdownTextView.taskTextGapMax,
                    "checkbox alignment: text gap out of conservative bounds"
                )
                expect(metric.yDiff <= 1.2, "checkbox alignment: vertical center mismatch")
            }

            let gaps = metrics.map { $0.gap }
            if let minGap = gaps.min(), let maxGap = gaps.max() {
                expect((maxGap - minGap) <= 1.2, "checkbox alignment: inconsistent gap across rows")
            }
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "* first")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "star bullet: Enter not handled")
            expect(textView.string == "* first\n* ", "star bullet: continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "+ first")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "plus bullet: Enter not handled")
            expect(textView.string == "+ first\n+ ", "plus bullet: continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "- first")
            textView.setSelectedRange(NSRange(location: 2, length: 0))
            expect(!pressReturn(coordinator, in: textView), "bullet mid-line: Enter should fall back to default behavior")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "Heading candidate\n-")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            coordinator.applyTypography(to: textView)
            expect(fontSize(of: "Heading candidate", in: textView) < 22, "setext: single '-' should not promote previous line to heading while typing")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "Heading candidate\n--")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            coordinator.applyTypography(to: textView)
            expect(fontSize(of: "Heading candidate", in: textView) > 22, "setext: multi '-' underline should still work")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> topic")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "toggle: Enter not handled")
            expect(textView.string == "> topic\n  ", "toggle: child-line continuation mismatch")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "toggle: second Enter not handled")
            expect(textView.string == "> topic\n", "toggle: double-enter escape mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "\" quote")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "notion quote: Enter not handled")
            expect(textView.string == "\" quote\n\" ", "notion quote: continuation mismatch")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "notion quote: second Enter not handled")
            expect(textView.string == "\" quote\n", "notion quote: double-enter escape mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "1. one")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "ordered list: Enter not handled")
            expect(textView.string == "1. one\n2. ", "ordered list: continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "- [ ] todo")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "task list: Enter not handled")
            expect(textView.string == "- [ ] todo\n- [ ] ", "task list: continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "")
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementString: "\""
            )
            expect(handled, "double quote: should not be auto-paired")
            expect(textView.string.isEmpty, "double quote: text mutated unexpectedly")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "")
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 0, length: 0),
                replacementString: "`"
            )
            expect(!handled, "backtick: should be handled by auto-pair")
            expect(textView.string == "``", "backtick: auto-pair mismatch")
            expect(textView.selectedRange().location == 1, "backtick: caret should be inside pair")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "[]")
            textView.setSelectedRange(NSRange(location: 2, length: 0))
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 2, length: 0),
                replacementString: " "
            )
            expect(!handled, "quick todo []: should be intercepted")
            expect(textView.string == "- [ ] ", "quick todo []: conversion mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "[x]")
            textView.setSelectedRange(NSRange(location: 3, length: 0))
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 3, length: 0),
                replacementString: " "
            )
            expect(!handled, "quick todo [x]: should be intercepted")
            expect(textView.string == "- [x] ", "quick todo [x]: conversion mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "abc []")
            textView.setSelectedRange(NSRange(location: 6, length: 0))
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 6, length: 0),
                replacementString: " "
            )
            expect(handled, "quick todo mid-line: should not be intercepted")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "  []")
            textView.setSelectedRange(NSRange(location: 4, length: 0))
            let handled = coordinator.textView(
                textView,
                shouldChangeTextIn: NSRange(location: 4, length: 0),
                replacementString: " "
            )
            expect(!handled, "quick todo indented []: should be intercepted")
            expect(textView.string == "  - [ ] ", "quick todo indented []: conversion mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "- bullet\n> toggle\n- [x] done")
            coordinator.applyTypography(to: textView)
            let decorations = textView.lineDecorations
            expect(decorations.filter { $0.kind == .bullet }.count == 1, "decorations: bullet count mismatch")
            expect(decorations.filter { $0.kind == .toggle }.count == 1, "decorations: toggle count mismatch")
            expect(decorations.filter { $0.kind == .checkbox }.count == 1, "decorations: checkbox count mismatch")
            expect(decorations.contains { $0.kind == .checkbox && $0.isChecked }, "decorations: checked state mismatch")
        }

        do {
            let (_, textView) = makeHarness(initial: "- bullet")
            let markerAlpha = (attrsAtToken("-", in: textView)[.foregroundColor] as? NSColor)?.alphaComponent ?? 1
            expect(markerAlpha <= 0.05, "bullet marker: '-' glyph should stay hidden to avoid duplicate marker rendering")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> Parent\n  child line\n# Next")
            coordinator.applyTypography(to: textView)
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                coordinator.toggleCollapse(at: toggle.markerLocation)
                expect(fontSize(of: "child line", in: textView) <= 0.2, "collapse: child line is not hidden")
                expect(fontSize(of: "Next", in: textView) > 1.0, "collapse: boundary heading should remain visible")
                coordinator.toggleCollapse(at: toggle.markerLocation)
                expect(fontSize(of: "child line", in: textView) > 1.0, "collapse: child line not restored")
            } else {
                failures.append("collapse: missing toggle decoration")
            }
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> Toggle me\n  child")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertLineBreak(_:)))
            expect(handled, "insertLineBreak fallback: should be handled as regular newline")
            expect(textView.string == "> Toggle me\n  child\n  ", "insertLineBreak fallback: toggle child continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> Toggle me\n  child")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)))
            expect(handled, "insertNewlineIgnoringFieldEditor fallback: should be handled as regular newline")
            expect(textView.string == "> Toggle me\n  child\n  ", "insertNewlineIgnoringFieldEditor fallback: toggle child continuation mismatch")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> parent")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "toggle child visibility: Enter not handled")
            expect(textView.string == "> parent\n  ", "toggle child visibility: missing child indent line")

            applyInput("-", coordinator: coordinator, textView: textView)
            applyInput(" ", coordinator: coordinator, textView: textView)
            applyInput("리스트", coordinator: coordinator, textView: textView)
            coordinator.applyTypographyIfNeeded(to: textView, force: true)

            expect(textView.string == "> parent\n  - 리스트", "toggle child visibility: nested list text mismatch")
            expect(fontSize(of: "리스트", in: textView) > 10, "toggle child visibility: child text font collapsed")
            let alpha = (attrsAtToken("리스트", in: textView)[.foregroundColor] as? NSColor)?.alphaComponent ?? -1
            expect(alpha > 0.45, "toggle child visibility: child text is too transparent/invisible")

            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(!toggle.isCollapsed, "toggle child visibility: toggle should stay expanded while typing")
            } else {
                failures.append("toggle child visibility: missing toggle decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "> Cmd toggle\n  child")
            textView.setSelectedRange(NSRange(location: 3, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.command]) {
                textView.keyDown(with: event)
            } else {
                failures.append("cmd+enter: failed to synthesize key event")
            }
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "cmd+enter: toggle should collapse")
            } else {
                failures.append("cmd+enter: missing toggle decoration")
            }
            if let event = makeEnterKeyEvent(modifiers: [.command]) {
                textView.keyDown(with: event)
            }
            if let toggle2 = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(!toggle2.isCollapsed, "cmd+enter: second shortcut should expand")
            } else {
                failures.append("cmd+enter second: missing toggle decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "> Opt toggle\n  child")
            textView.setSelectedRange(NSRange(location: 3, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.option]) {
                textView.keyDown(with: event)
            } else {
                failures.append("alt+enter: failed to synthesize key event")
            }
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "alt+enter keyDown: toggle should collapse")
            } else {
                failures.append("alt+enter keyDown: missing toggle decoration")
            }
            if let event = makeEnterKeyEvent(modifiers: [.option]) {
                textView.keyDown(with: event)
            }
            if let toggle2 = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(!toggle2.isCollapsed, "alt+enter keyDown: second shortcut should expand")
            } else {
                failures.append("alt+enter keyDown second: missing toggle decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "> Parent toggle\n  child")
            let childRange = (textView.string as NSString).range(of: "child")
            textView.setSelectedRange(NSRange(location: childRange.location, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.command]) {
                textView.keyDown(with: event)
            } else {
                failures.append("cmd+enter child: failed to synthesize key event")
            }
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "cmd+enter child: parent toggle should collapse")
            } else {
                failures.append("cmd+enter child: missing toggle decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "> Parent toggle\n  child")
            let childRange = (textView.string as NSString).range(of: "child")
            textView.setSelectedRange(NSRange(location: childRange.location, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.option]) {
                textView.keyDown(with: event)
            } else {
                failures.append("alt+enter child: failed to synthesize key event")
            }
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "alt+enter child: parent toggle should collapse")
            } else {
                failures.append("alt+enter child: missing toggle decoration")
            }
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> parent\n  child")
            let childEnd = (textView.string as NSString).length
            textView.setSelectedRange(NSRange(location: childEnd, length: 0))
            expect(pressReturn(coordinator, in: textView), "toggle child: Enter not handled")
            expect(textView.string == "> parent\n  child\n  ", "toggle child: continuation mismatch")
            textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
            expect(pressReturn(coordinator, in: textView), "toggle child: second Enter not handled")
            expect(textView.string == "> parent\n  child\n", "toggle child: escape mismatch")
        }

        do {
            let (_, textView) = makeHarness(initial: "> Click toggle\n  child")
            if let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                textView.onToggleClick?(toggle.markerLocation)
                if let updated = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                    expect(updated.isCollapsed, "toggle click callback: should collapse")
                } else {
                    failures.append("toggle click callback: missing updated decoration")
                }
            } else {
                failures.append("toggle click callback: missing toggle decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "- [ ] task")
            if let checkbox = textView.lineDecorations.first(where: { $0.kind == .checkbox }) {
                textView.onCheckboxClick?(checkbox.markerLocation)
                expect(textView.string.contains("[x]"), "checkbox click callback: should check")
                if let second = textView.lineDecorations.first(where: { $0.kind == .checkbox }) {
                    textView.onCheckboxClick?(second.markerLocation)
                    expect(textView.string.contains("[ ]"), "checkbox click callback: should uncheck")
                } else {
                    failures.append("checkbox click callback: missing second checkbox decoration")
                }
            } else {
                failures.append("checkbox click callback: missing checkbox decoration")
            }
        }

        do {
            let (_, textView) = makeHarness(initial: "- [ ] cmd toggle checkbox")
            textView.setSelectedRange(NSRange(location: 3, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.command]) {
                textView.keyDown(with: event)
            } else {
                failures.append("cmd+enter checkbox: failed to synthesize key event")
            }
            expect(textView.string.contains("[x]"), "cmd+enter checkbox: should check")
            if let event = makeEnterKeyEvent(modifiers: [.command]) {
                textView.keyDown(with: event)
            }
            expect(textView.string.contains("[ ]"), "cmd+enter checkbox: second shortcut should uncheck")
        }

        do {
            let (_, textView) = makeHarness(initial: "- [ ] alt toggle checkbox")
            textView.setSelectedRange(NSRange(location: 3, length: 0))
            if let event = makeEnterKeyEvent(modifiers: [.option]) {
                textView.keyDown(with: event)
            } else {
                failures.append("alt+enter checkbox: failed to synthesize key event")
            }
            expect(textView.string.contains("[x]"), "alt+enter checkbox: should check")
            if let event = makeEnterKeyEvent(modifiers: [.option]) {
                textView.keyDown(with: event)
            }
            expect(textView.string.contains("[ ]"), "alt+enter checkbox: second shortcut should uncheck")
        }

        do {
            let (coordinator, textView) = makeHarness(initial: "> Keep collapse\n  child")
            if let original = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                coordinator.toggleCollapse(at: original.markerLocation)
                if let collapsed = textView.lineDecorations.first(where: { $0.kind == .toggle }), collapsed.isCollapsed {
                    // Insert newline before the toggle line and ensure collapsed state survives marker shift.
                    let insertRange = NSRange(location: 0, length: 0)
                    let allowInsert = coordinator.textView(
                        textView,
                        shouldChangeTextIn: insertRange,
                        replacementString: "\n"
                    )
                    if allowInsert {
                        textView.textStorage?.replaceCharacters(in: insertRange, with: "\n")
                        textView.didChangeText()
                    } else {
                        failures.append("collapse marker shift: insert before marker was denied")
                    }

                    if let shifted = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                        expect(shifted.isCollapsed, "collapse marker shift: collapsed state lost after insert")
                    } else {
                        failures.append("collapse marker shift: toggle missing after insert")
                    }

                    let deleteRange = NSRange(location: 0, length: 1)
                    let allowDelete = coordinator.textView(
                        textView,
                        shouldChangeTextIn: deleteRange,
                        replacementString: ""
                    )
                    if allowDelete {
                        textView.textStorage?.replaceCharacters(in: deleteRange, with: "")
                        textView.didChangeText()
                    } else {
                        failures.append("collapse marker shift: delete before marker was denied")
                    }
                    if let restored = textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                        expect(restored.isCollapsed, "collapse marker shift: collapsed state lost after delete")
                    } else {
                        failures.append("collapse marker shift: toggle missing after delete")
                    }
                } else {
                    failures.append("collapse marker shift: initial collapse failed")
                }
            } else {
                failures.append("collapse marker shift: initial toggle missing")
            }
        }

        if failures.isEmpty {
            print("QA RESULT: PASS")
            return
        }

        print("QA RESULT: FAIL (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        Foundation.exit(1)
    }
}
