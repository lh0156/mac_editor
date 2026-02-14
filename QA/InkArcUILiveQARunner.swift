import Foundation
import SwiftUI
import AppKit

@MainActor
@main
struct InkArcUILiveQARunner {
    private final class TextBox {
        var value: String

        init(_ value: String) {
            self.value = value
        }
    }

    private struct Harness {
        let coordinator: PlainMarkdownEditor.Coordinator
        let textView: NotionMarkdownTextView
        let window: NSWindow
    }

    private static func makeHarness(initial: String) -> Harness {
        let box = TextBox(initial)
        let binding = Binding<String>(
            get: { box.value },
            set: { box.value = $0 }
        )
        let editor = PlainMarkdownEditor(text: binding, fontName: "SF Pro Text", fontSize: 18, lineSpacing: 9)
        let coordinator = PlainMarkdownEditor.Coordinator(editor)

        let textView = NotionMarkdownTextView(frame: NSRect(x: 0, y: 0, width: 980, height: 700))
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
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.insertionPointColor = NSColor.textColor

        textView.string = initial
        textView.delegate = coordinator
        textView.onToggleClick = { [weak coordinator] location in
            coordinator?.toggleCollapse(at: location)
        }
        textView.onCheckboxClick = { [weak coordinator] location in
            coordinator?.toggleCheckbox(at: location)
        }
        textView.onToggleShortcutAtCaret = { [weak coordinator] in
            coordinator?.toggleAtCurrentCaret() ?? false
        }
        coordinator.textView = textView
        coordinator.applyTypography(to: textView)

        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 980, height: 700))
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(calibratedRed: 0.99, green: 0.99, blue: 0.98, alpha: 1)
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.documentView = textView

        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 980, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InkArc Live QA"
        window.contentView = scrollView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)

        pump()
        return Harness(coordinator: coordinator, textView: textView, window: window)
    }

    private static func pump(_ seconds: TimeInterval = 0.02) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private static func placeCaretEnd(_ harness: Harness) {
        let length = (harness.textView.string as NSString).length
        harness.textView.setSelectedRange(NSRange(location: length, length: 0))
        pump()
    }

    private static func placeCaret(
        at token: String,
        in harness: Harness
    ) {
        let ns = harness.textView.string as NSString
        let r = ns.range(of: token)
        guard r.location != NSNotFound else { return }
        harness.textView.setSelectedRange(NSRange(location: r.location, length: 0))
        pump()
    }

    private static func type(
        _ input: String,
        in harness: Harness
    ) {
        for char in input {
            let token = String(char)
            let range = harness.textView.selectedRange()
            let handled = harness.coordinator.textView(
                harness.textView,
                shouldChangeTextIn: range,
                replacementString: token
            )
            if handled {
                harness.textView.textStorage?.replaceCharacters(in: range, with: token)
                harness.textView.didChangeText()
                harness.textView.setSelectedRange(
                    NSRange(location: range.location + (token as NSString).length, length: 0)
                )
            }
            pump()
        }
        harness.coordinator.applyTypographyIfNeeded(to: harness.textView, force: true)
        pump()
    }

    private static func pressEnter(
        _ harness: Harness,
        selector: Selector = #selector(NSResponder.insertNewline(_:))
    ) -> Bool {
        let handled = harness.coordinator.textView(harness.textView, doCommandBy: selector)
        pump()
        return handled
    }

    private static func sendEnterShortcut(
        _ harness: Harness,
        modifiers: NSEvent.ModifierFlags
    ) {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: harness.window.windowNumber,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36
        ) else { return }
        harness.textView.keyDown(with: event)
        pump()
    }

    private static func decorationFrame(
        _ decoration: NotionMarkdownTextView.LineDecoration,
        in textView: NotionMarkdownTextView
    ) -> NSRect? {
        guard let layoutManager = textView.layoutManager else { return nil }
        let maxLen = textView.string.utf16.count
        guard decoration.markerLocation >= 0, decoration.markerLocation < maxLen else { return nil }

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
            iconSize = NotionMarkdownTextView.toggleIconSize
            verticalOffset = NotionMarkdownTextView.toggleVerticalOffset
        case .checkbox:
            iconSize = NotionMarkdownTextView.checkboxIconSize
            verticalOffset = NotionMarkdownTextView.checkboxVerticalOffset
        case .bullet:
            iconSize = NotionMarkdownTextView.bulletIconSize
            verticalOffset = NotionMarkdownTextView.bulletVerticalOffset
        }

        let origin = textView.textContainerOrigin
        return NSRect(
            x: origin.x + usedRect.minX - NotionMarkdownTextView.markerColumnOffset,
            y: origin.y + usedRect.midY - (iconSize / 2) + verticalOffset,
            width: iconSize,
            height: iconSize
        )
    }

    private static func clickDecoration(
        kind: NotionMarkdownTextView.DecorationKind,
        in harness: Harness
    ) -> Bool {
        guard let decoration = harness.textView.lineDecorations.first(where: { $0.kind == kind }),
              let iconFrame = decorationFrame(decoration, in: harness.textView),
              let window = harness.textView.window
        else { return false }

        let localPoint = NSPoint(x: iconFrame.midX, y: iconFrame.midY)
        let windowPoint = harness.textView.convert(localPoint, to: nil)
        guard let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: windowPoint,
            modifierFlags: [],
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1
        ) else { return false }

        harness.textView.mouseDown(with: event)
        pump()
        return true
    }

    private static func fontSize(
        of token: String,
        in harness: Harness
    ) -> CGFloat {
        let ns = harness.textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = harness.textView.textStorage else { return -1 }
        return (storage.attributes(at: range.location, effectiveRange: nil)[.font] as? NSFont)?.pointSize ?? -1
    }

    private static func alpha(
        of token: String,
        in harness: Harness
    ) -> CGFloat {
        let ns = harness.textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = harness.textView.textStorage else { return -1 }
        return (storage.attributes(at: range.location, effectiveRange: nil)[.foregroundColor] as? NSColor)?.alphaComponent ?? -1
    }

    private static func stressLoopCount() -> Int {
        let env = ProcessInfo.processInfo.environment
        guard let raw = env["INKARC_LIVE_STRESS_LOOPS"], let parsed = Int(raw), parsed > 0 else {
            return 1
        }
        return min(parsed, 2000)
    }

    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        // TC-LIVE-001: Toggle child typing stays visible.
        do {
            let h = makeHarness(initial: "> 부모")
            placeCaretEnd(h)
            expect(pressEnter(h), "TC-LIVE-001: Enter not handled")
            expect(h.textView.string == "> 부모\n  ", "TC-LIVE-001: toggle child indent mismatch")
            type("- 리스트", in: h)
            expect(h.textView.string == "> 부모\n  - 리스트", "TC-LIVE-001: nested list text mismatch")
            expect(fontSize(of: "리스트", in: h) > 10, "TC-LIVE-001: nested text font collapsed")
            expect(alpha(of: "리스트", in: h) > 0.45, "TC-LIVE-001: nested text is invisible/too transparent")
            h.window.close()
        }

        // TC-LIVE-002: insertLineBreak / insertNewlineIgnoringFieldEditor fall back to continuation.
        do {
            let h = makeHarness(initial: "> Toggle me\n  child")
            placeCaretEnd(h)
            expect(
                pressEnter(h, selector: #selector(NSResponder.insertLineBreak(_:))),
                "TC-LIVE-002A: insertLineBreak not handled"
            )
            expect(
                h.textView.string == "> Toggle me\n  child\n  ",
                "TC-LIVE-002A: insertLineBreak continuation mismatch"
            )
            h.window.close()
        }
        do {
            let h = makeHarness(initial: "> Toggle me\n  child")
            placeCaretEnd(h)
            expect(
                pressEnter(h, selector: #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:))),
                "TC-LIVE-002B: insertNewlineIgnoringFieldEditor not handled"
            )
            expect(
                h.textView.string == "> Toggle me\n  child\n  ",
                "TC-LIVE-002B: insertNewlineIgnoringFieldEditor continuation mismatch"
            )
            h.window.close()
        }

        // TC-LIVE-003: Click toggle icon should collapse/expand.
        do {
            let h = makeHarness(initial: "> 토글\n  자식")
            expect(clickDecoration(kind: .toggle, in: h), "TC-LIVE-003: toggle click event dispatch failed")
            if let toggle = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "TC-LIVE-003: toggle did not collapse on click")
            } else {
                failures.append("TC-LIVE-003: toggle decoration missing")
            }
            expect(clickDecoration(kind: .toggle, in: h), "TC-LIVE-003: second toggle click event dispatch failed")
            if let toggle2 = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(!toggle2.isCollapsed, "TC-LIVE-003: toggle did not expand on second click")
            } else {
                failures.append("TC-LIVE-003: toggle decoration missing after second click")
            }
            h.window.close()
        }

        // TC-LIVE-004: Click checkbox icon toggles [ ] <-> [x].
        do {
            let h = makeHarness(initial: "- [ ] task")
            expect(clickDecoration(kind: .checkbox, in: h), "TC-LIVE-004: checkbox click dispatch failed")
            expect(h.textView.string.contains("[x]"), "TC-LIVE-004: checkbox not checked after click")
            expect(clickDecoration(kind: .checkbox, in: h), "TC-LIVE-004: second checkbox click dispatch failed")
            expect(h.textView.string.contains("[ ]"), "TC-LIVE-004: checkbox not unchecked after second click")
            h.window.close()
        }

        // TC-LIVE-005: Cmd/Alt + Enter toggles from header and child line.
        do {
            let h = makeHarness(initial: "> Parent toggle\n  child")
            placeCaret(at: "Parent", in: h)
            sendEnterShortcut(h, modifiers: [.command])
            if let toggle = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "TC-LIVE-005A: Cmd+Enter failed to collapse")
            } else {
                failures.append("TC-LIVE-005A: toggle decoration missing")
            }

            sendEnterShortcut(h, modifiers: [.command])
            if let toggle2 = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(!toggle2.isCollapsed, "TC-LIVE-005A: second Cmd+Enter failed to expand")
            } else {
                failures.append("TC-LIVE-005A: toggle decoration missing after second command")
            }

            placeCaret(at: "child", in: h)
            sendEnterShortcut(h, modifiers: [.option])
            if let toggle3 = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle3.isCollapsed, "TC-LIVE-005B: Alt+Enter from child failed to collapse parent")
            } else {
                failures.append("TC-LIVE-005B: toggle decoration missing from child")
            }
            h.window.close()
        }

        // TC-LIVE-006: List continuation and double-enter escape.
        do {
            let h = makeHarness(initial: "- first")
            placeCaretEnd(h)
            expect(pressEnter(h), "TC-LIVE-006: first Enter not handled")
            expect(h.textView.string == "- first\n- ", "TC-LIVE-006: continuation mismatch")
            placeCaretEnd(h)
            expect(pressEnter(h), "TC-LIVE-006: second Enter not handled")
            expect(h.textView.string == "- first\n", "TC-LIVE-006: double-enter escape mismatch")
            h.window.close()
        }

        // TC-LIVE-007: Bullet marker should not visually duplicate with '-' glyph.
        do {
            let h = makeHarness(initial: "")
            type("- ", in: h)
            expect(h.textView.string == "- ", "TC-LIVE-007: bullet line input mismatch")
            let bullets = h.textView.lineDecorations.filter { $0.kind == .bullet }
            expect(bullets.count == 1, "TC-LIVE-007: bullet decoration missing")
            expect(
                alpha(of: "-", in: h) <= 0.05,
                "TC-LIVE-007: '-' glyph is visible with custom bullet (duplicate marker)"
            )
            if let bullet = bullets.first {
                expect(!bullet.showsGuideBar, "TC-LIVE-007: empty active bullet should hide guide bar")
            }
            h.window.close()
        }

        // TC-STRESS-001: Repeat core live scenarios to catch flaky regressions.
        let loops = stressLoopCount()
        for idx in 1 ... loops {
            let h = makeHarness(initial: "> stress parent")
            placeCaretEnd(h)
            expect(pressEnter(h), "TC-STRESS-001[\(idx)]: Enter not handled")
            type("- stress", in: h)
            let bulletCount = h.textView.lineDecorations.filter { $0.kind == .bullet }.count
            expect(bulletCount >= 1, "TC-STRESS-001[\(idx)]: bullet decoration missing")
            expect(
                alpha(of: "-", in: h) <= 0.05,
                "TC-STRESS-001[\(idx)]: duplicate bullet marker visible"
            )
            placeCaret(at: "stress", in: h)
            sendEnterShortcut(h, modifiers: [.command])
            if let toggle = h.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
                expect(toggle.isCollapsed, "TC-STRESS-001[\(idx)]: Cmd+Enter failed to collapse")
            } else {
                failures.append("TC-STRESS-001[\(idx)]: toggle decoration missing")
            }
            h.window.close()
        }

        if failures.isEmpty {
            print("LIVE UI QA RESULT: PASS")
            return
        }

        print("LIVE UI QA RESULT: FAIL (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        Foundation.exit(1)
    }
}
