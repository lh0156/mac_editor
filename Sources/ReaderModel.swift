import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
final class ReaderModel: ObservableObject {
    @Published var fileURL: URL?
    @Published var rawMarkdown: String = ""
    @Published var errorMessage: String?
    @Published var hasUnsavedChanges: Bool = false

    private var lastSavedSnapshot = ""

    init() {
        newDocument()
    }

    var wordCount: Int {
        rawMarkdown.split { $0.isWhitespace || $0.isNewline }.count
    }

    var readingMinutes: Int {
        max(1, Int(ceil(Double(max(1, wordCount)) / 220.0)))
    }

    var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled.md"
    }

    var subtitle: String {
        fileURL?.path ?? "Notion-like writing canvas"
    }

    func newDocument() {
        applyLoadedContent(
            """
            # Untitled

            Start writing...
            """,
            url: nil
        )
    }

    func open(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let content = try Self.readText(from: url)
            applyLoadedContent(content, url: url)
        } catch {
            errorMessage = "파일을 읽을 수 없습니다: \(error.localizedDescription)"
        }
    }

    func reload() {
        guard let fileURL else { return }
        open(url: fileURL)
    }

    func updateMarkdown(_ text: String) {
        guard rawMarkdown != text else { return }
        rawMarkdown = text
        hasUnsavedChanges = (rawMarkdown != lastSavedSnapshot)
    }

    func save() {
        if fileURL == nil {
            saveAs()
            return
        }
        guard let fileURL else { return }

        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }
        do {
            try Self.writeText(rawMarkdown, to: fileURL)
            lastSavedSnapshot = rawMarkdown
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            errorMessage = "저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.title = "Save Markdown"
        panel.message = "Markdown 파일로 저장합니다."
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"
        panel.allowedContentTypes = [.init(filenameExtension: "md") ?? .plainText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try Self.writeText(rawMarkdown, to: url)
            fileURL = url
            lastSavedSnapshot = rawMarkdown
            hasUnsavedChanges = false
            errorMessage = nil
        } catch {
            errorMessage = "다른 이름 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    private func applyLoadedContent(_ content: String, url: URL?) {
        fileURL = url
        rawMarkdown = content
        lastSavedSnapshot = content
        hasUnsavedChanges = false
        errorMessage = nil
    }

    static func readText(from url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }

        if looksLikeUTF16(data) {
            if let utf16 = String(data: data, encoding: .utf16) {
                return utf16
            }
            if let utf16LE = String(data: data, encoding: .utf16LittleEndian) {
                return utf16LE
            }
            if let utf16BE = String(data: data, encoding: .utf16BigEndian) {
                return utf16BE
            }
        }

        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }

        return String(decoding: data, as: UTF8.self)
    }

    private static func looksLikeUTF16(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        let bytes = [UInt8](data.prefix(4))
        let hasUTF16BOM =
            (bytes.count >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE)
            || (bytes.count >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF)
        if hasUTF16BOM { return true }

        // Heuristic: UTF-16 text usually contains frequent NUL bytes in ASCII ranges.
        let nulCount = data.reduce(0) { $0 + ($1 == 0 ? 1 : 0) }
        return nulCount > max(1, data.count / 8)
    }

    static func writeText(_ text: String, to url: URL) throws {
        let data = Data(text.utf8)
        try data.write(to: url, options: .atomic)
    }
}
