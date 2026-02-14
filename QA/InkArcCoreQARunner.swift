import Foundation
import AppKit

@MainActor
@main
struct InkArcCoreQARunner {
    static func main() {
        var failures: [String] = []

        func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { failures.append(message) }
        }

        do {
            let settings = ReaderSettings()
            expect(settings.preset == .research, "settings: default preset should be research")
            expect((55...75).contains(settings.estimatedCPL), "settings: research CPL out of range")
            expect(settings.maxContentWidth >= 560 && settings.maxContentWidth <= 920, "settings: width out of bounds")

            settings.preset = .compact
            expect((70...90).contains(settings.estimatedCPL), "settings: compact CPL out of range")
            let compactWidth = settings.maxContentWidth
            settings.increaseFontSize()
            expect(settings.fontSize == 18, "settings: increaseFontSize should increment")
            expect(settings.maxContentWidth != compactWidth, "settings: width should recompute on font size change")
            settings.decreaseFontSize()
            expect(settings.fontSize == 17, "settings: decreaseFontSize should decrement")
        }

        do {
            let model = ReaderModel()
            expect(model.rawMarkdown.contains("Start writing"), "model: default document text missing")
            expect(!model.hasUnsavedChanges, "model: new document should not be unsaved")

            model.updateMarkdown("# A B C")
            expect(model.hasUnsavedChanges, "model: update should mark unsaved")
            expect(model.wordCount == 4, "model: wordCount mismatch")
            expect(model.readingMinutes >= 1, "model: readingMinutes must be >= 1")
        }

        do {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("inkarc-core-qa-\(UUID().uuidString).md")
            let sample = "# Title\n\nBody line"
            try ReaderModel.writeText(sample, to: tempURL)
            let loaded = try ReaderModel.readText(from: tempURL)
            expect(loaded == sample, "model: utf8 read/write mismatch")
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            failures.append("model: utf8 read/write threw error: \(error.localizedDescription)")
        }

        do {
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("inkarc-core-qa-latin1-\(UUID().uuidString).md")
            let latin1 = Data([0x63, 0x61, 0x66, 0xE9]) // "café" in ISO-8859-1
            try latin1.write(to: tempURL)
            let loaded = try ReaderModel.readText(from: tempURL)
            expect(loaded == "café", "model: latin1 decoding mismatch")
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            failures.append("model: latin1 read threw error: \(error.localizedDescription)")
        }

        do {
            let model = ReaderModel()
            let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("inkarc-core-qa-save-\(UUID().uuidString).md")
            model.fileURL = tempURL
            model.updateMarkdown("save test")
            model.save()
            expect(!model.hasUnsavedChanges, "model: save should clear unsaved flag")
            let loaded = try ReaderModel.readText(from: tempURL)
            expect(loaded == "save test", "model: save content mismatch")
            try? FileManager.default.removeItem(at: tempURL)
        } catch {
            failures.append("model: save path test threw error: \(error.localizedDescription)")
        }

        do {
            let model = ReaderModel()
            let missingURL = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("inkarc-core-qa-missing-\(UUID().uuidString).md")
            model.open(url: missingURL)
            expect(model.errorMessage != nil, "model: opening missing file should set error message")
        }

        if failures.isEmpty {
            print("CORE QA RESULT: PASS")
            return
        }

        print("CORE QA RESULT: FAIL (\(failures.count))")
        for failure in failures {
            print("- \(failure)")
        }
        Foundation.exit(1)
    }
}
