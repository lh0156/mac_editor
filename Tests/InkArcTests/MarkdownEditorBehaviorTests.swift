import XCTest
import SwiftUI
import AppKit
@testable import InkArc

@MainActor
final class MarkdownEditorBehaviorTests: XCTestCase {
    private final class TextBox {
        var value: String

        init(_ value: String) {
            self.value = value
        }
    }

    private func makeHarness(initial: String) -> (TextBox, PlainMarkdownEditor.Coordinator, NotionMarkdownTextView) {
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
        coordinator.textView = textView
        coordinator.applyTypography(to: textView)
        return (box, coordinator, textView)
    }

    private func pressReturn(
        _ coordinator: PlainMarkdownEditor.Coordinator,
        in textView: NotionMarkdownTextView
    ) -> Bool {
        coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))
    }

    private func fontSize(of token: String, in textView: NotionMarkdownTextView) -> CGFloat {
        let ns = textView.string as NSString
        let range = ns.range(of: token)
        XCTAssertNotEqual(range.location, NSNotFound, "Token '\(token)' not found in text")
        guard range.location != NSNotFound, let storage = textView.textStorage else { return -1 }
        let attrs = storage.attributes(at: range.location, effectiveRange: nil)
        return (attrs[.font] as? NSFont)?.pointSize ?? -1
    }

    func testBulletContinuationAndEscapeOnDoubleEnter() {
        let (_, coordinator, textView) = makeHarness(initial: "- first")
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "- first\n- ")

        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "- first\n")
    }

    func testToggleContinuationAndEscapeOnDoubleEnter() {
        let (_, coordinator, textView) = makeHarness(initial: "> topic")
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "> topic\n  ")

        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "> topic\n")
    }

    func testNotionQuoteContinuationAndEscapeOnDoubleEnter() {
        let (_, coordinator, textView) = makeHarness(initial: "\" quote")
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "\" quote\n\" ")

        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "\" quote\n")
    }

    func testTaskAndOrderedContinuation() {
        let (_, coordinator, textView) = makeHarness(initial: "- [ ] task")
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))

        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "- [ ] task\n- [ ] ")

        textView.string = "3) third"
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
        coordinator.applyTypography(to: textView)

        XCTAssertTrue(pressReturn(coordinator, in: textView))
        XCTAssertEqual(textView.string, "3) third\n4) ")
    }

    func testDoubleQuoteIsNotAutoPaired() {
        let (_, coordinator, textView) = makeHarness(initial: "")
        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 0, length: 0),
            replacementString: "\""
        )
        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
    }

    func testBacktickStillAutoPairs() {
        let (_, coordinator, textView) = makeHarness(initial: "")
        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 0, length: 0),
            replacementString: "`"
        )
        XCTAssertFalse(handled)
        XCTAssertEqual(textView.string, "``")
        XCTAssertEqual(textView.selectedRange().location, 1)
    }

    func testQuickTodoShortcutFromSquareBrackets() {
        let (_, coordinator, textView) = makeHarness(initial: "[]")
        textView.setSelectedRange(NSRange(location: 2, length: 0))
        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 2, length: 0),
            replacementString: " "
        )
        XCTAssertFalse(handled)
        XCTAssertEqual(textView.string, "- [ ] ")
    }

    func testQuickTodoShortcutKeepsCheckedState() {
        let (_, coordinator, textView) = makeHarness(initial: "[x]")
        textView.setSelectedRange(NSRange(location: 3, length: 0))
        let handled = coordinator.textView(
            textView,
            shouldChangeTextIn: NSRange(location: 3, length: 0),
            replacementString: " "
        )
        XCTAssertFalse(handled)
        XCTAssertEqual(textView.string, "- [x] ")
    }

    func testDecorationsIncludeBulletToggleAndCheckbox() {
        let (_, coordinator, textView) = makeHarness(
            initial: "- bullet\n> toggle\n- [x] done"
        )
        coordinator.applyTypography(to: textView)

        let decorations = textView.lineDecorations
        XCTAssertEqual(decorations.filter { $0.kind == .bullet }.count, 1)
        XCTAssertEqual(decorations.filter { $0.kind == .toggle }.count, 1)
        XCTAssertEqual(decorations.filter { $0.kind == .checkbox }.count, 1)
        XCTAssertTrue(decorations.contains { $0.kind == .checkbox && $0.isChecked })
    }

    func testToggleCollapseHidesAndRestoresChildLines() {
        let (_, coordinator, textView) = makeHarness(
            initial: "> Parent\n  child line\n# Next"
        )
        coordinator.applyTypography(to: textView)

        guard let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) else {
            XCTFail("Toggle decoration not found")
            return
        }

        coordinator.toggleCollapse(at: toggle.markerLocation)
        let collapsedChildFont = fontSize(of: "child line", in: textView)
        let collapsedHeadingFont = fontSize(of: "Next", in: textView)
        XCTAssertLessThanOrEqual(collapsedChildFont, 0.2)
        XCTAssertGreaterThan(collapsedHeadingFont, 1.0)

        coordinator.toggleCollapse(at: toggle.markerLocation)
        let expandedChildFont = fontSize(of: "child line", in: textView)
        XCTAssertGreaterThan(expandedChildFont, 1.0)
    }

    func testAltEnterTogglesCurrentToggleBlock() {
        let (_, coordinator, textView) = makeHarness(initial: "> Toggle me\n  child")
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        let handled = coordinator.textView(
            textView,
            doCommandBy: #selector(NSResponder.insertLineBreak(_:))
        )
        XCTAssertTrue(handled)

        guard let toggle = textView.lineDecorations.first(where: { $0.kind == .toggle }) else {
            XCTFail("Toggle decoration not found")
            return
        }
        XCTAssertTrue(toggle.isCollapsed)
    }
}
