import Foundation
import SwiftUI
import AppKit

@MainActor
@main
struct InkArcAppQARunner {
    private struct Harness {
        let window: NSWindow
        let textView: NotionMarkdownTextView
        let coordinator: PlainMarkdownEditor.Coordinator
    }

    private struct QAHostView: View {
        @StateObject private var model = ReaderModel()
        @StateObject private var settings = ReaderSettings()
        @State private var showingImporter = false

        var body: some View {
            ReaderRootView(
                model: model,
                settings: settings,
                showingImporter: $showingImporter
            )
            .frame(minWidth: 980, minHeight: 680)
        }
    }

    private static func pump(_ seconds: TimeInterval = 0.03) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private static func findEditor(in view: NSView) -> NotionMarkdownTextView? {
        if let editor = view as? NotionMarkdownTextView {
            return editor
        }
        for child in view.subviews {
            if let found = findEditor(in: child) {
                return found
            }
        }
        return nil
    }

    private static func makeHarness() -> Harness? {
        let hosting = NSHostingView(rootView: QAHostView())
        let window = NSWindow(
            contentRect: NSRect(x: 120, y: 120, width: 1080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "InkArc App QA"
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Wait for SwiftUI tree / NSViewRepresentable bridge to materialize.
        var editor: NotionMarkdownTextView?
        for _ in 0 ..< 120 {
            pump(0.03)
            if let root = window.contentView, let found = findEditor(in: root) {
                editor = found
                break
            }
        }

        guard let textView = editor,
              let coordinator = textView.delegate as? PlainMarkdownEditor.Coordinator
        else {
            window.close()
            return nil
        }

        window.makeFirstResponder(textView)
        pump(0.03)
        return Harness(window: window, textView: textView, coordinator: coordinator)
    }

    private static func setText(_ text: String, in harness: Harness) {
        harness.textView.string = text
        harness.coordinator.parent.text = text
        harness.coordinator.applyTypographyIfNeeded(to: harness.textView, force: true)
        pump(0.02)
    }

    private static func placeCaretEnd(_ harness: Harness) {
        let length = (harness.textView.string as NSString).length
        harness.textView.setSelectedRange(NSRange(location: length, length: 0))
        pump(0.02)
    }

    private static func placeCaret(at token: String, in harness: Harness) {
        let ns = harness.textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound else { return }
        harness.textView.setSelectedRange(NSRange(location: range.location, length: 0))
        pump(0.02)
    }

    private static func type(_ input: String, in harness: Harness) {
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
            pump(0.01)
        }
        harness.coordinator.applyTypographyIfNeeded(to: harness.textView, force: true)
        pump(0.02)
    }

    private static func pressEnter(_ harness: Harness) -> Bool {
        let handled = harness.coordinator.textView(
            harness.textView,
            doCommandBy: #selector(NSResponder.insertNewline(_:))
        )
        if !handled {
            harness.textView.insertNewline(nil)
        }
        pump(0.02)
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
        pump(0.03)
    }

    private static func alpha(of token: String, in harness: Harness) -> CGFloat {
        let ns = harness.textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = harness.textView.textStorage else { return -1 }
        return (storage.attributes(at: range.location, effectiveRange: nil)[.foregroundColor] as? NSColor)?.alphaComponent ?? -1
    }

    private static func fontSize(of token: String, in harness: Harness) -> CGFloat {
        let ns = harness.textView.string as NSString
        let range = ns.range(of: token)
        guard range.location != NSNotFound, let storage = harness.textView.textStorage else { return -1 }
        return (storage.attributes(at: range.location, effectiveRange: nil)[.font] as? NSFont)?.pointSize ?? -1
    }

    private static func runOneRound(round: Int, failures: inout [String]) {
        guard let harness = makeHarness() else {
            failures.append("APP-QA[\(round)]: failed to create app harness")
            return
        }

        defer { harness.window.close() }

        // Case 1: bullet duplicate marker guard.
        setText("", in: harness)
        placeCaretEnd(harness)
        type("- ", in: harness)
        if harness.textView.string != "- " {
            failures.append("APP-QA[\(round)] case1: bullet input mismatch")
        }
        let bulletDecorations = harness.textView.lineDecorations.filter { $0.kind == .bullet }.count
        if bulletDecorations != 1 {
            failures.append("APP-QA[\(round)] case1: missing bullet decoration")
        }
        if alpha(of: "-", in: harness) > 0.05 {
            failures.append("APP-QA[\(round)] case1: duplicate bullet marker visible")
        }

        // Case 2: toggle child writing visibility.
        setText("> parent", in: harness)
        placeCaretEnd(harness)
        _ = pressEnter(harness)
        type("- list", in: harness)
        if harness.textView.string != "> parent\n  - list" {
            failures.append("APP-QA[\(round)] case2: toggle child list mismatch")
        }
        if fontSize(of: "list", in: harness) <= 10 {
            failures.append("APP-QA[\(round)] case2: toggle child text font collapsed")
        }
        if alpha(of: "list", in: harness) <= 0.45 {
            failures.append("APP-QA[\(round)] case2: toggle child text invisible")
        }

        // Case 3: Cmd+Enter toggle action.
        placeCaret(at: "parent", in: harness)
        sendEnterShortcut(harness, modifiers: [.command])
        if let toggle = harness.textView.lineDecorations.first(where: { $0.kind == .toggle }) {
            if !toggle.isCollapsed {
                failures.append("APP-QA[\(round)] case3: Cmd+Enter did not collapse toggle")
            }
        } else {
            failures.append("APP-QA[\(round)] case3: toggle decoration missing")
        }
    }

    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let env = ProcessInfo.processInfo.environment
        let loops = max(1, min(2000, Int(env["INKARC_APP_QA_LOOPS"] ?? "") ?? 1))
        var failures: [String] = []

        for round in 1 ... loops {
            runOneRound(round: round, failures: &failures)
            if !failures.isEmpty { break }
        }

        if failures.isEmpty {
            print("APP UI QA RESULT: PASS (loops=\(loops))")
            return
        }

        print("APP UI QA RESULT: FAIL (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        Foundation.exit(1)
    }
}
