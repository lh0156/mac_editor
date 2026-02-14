import SwiftUI
import AppKit

final class InkArcAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.windows.forEach { $0.appearance = NSAppearance(named: .aqua) }
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct InkArcApp: App {
    @NSApplicationDelegateAdaptor(InkArcAppDelegate.self) private var appDelegate
    @StateObject private var model = ReaderModel()
    @StateObject private var settings = ReaderSettings()
    @State private var showingImporter = false

    var body: some Scene {
        WindowGroup("InkArc") {
            ReaderRootView(
                model: model,
                settings: settings,
                showingImporter: $showingImporter
            )
            .frame(minWidth: 980, minHeight: 680)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Document") {
                    model.newDocument()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Open Markdown...") {
                    showingImporter = true
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    model.save()
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button("Save As...") {
                    model.saveAs()
                }
                .keyboardShortcut("S", modifiers: [.command, .shift])
            }

            CommandMenu("Format") {
                Button("Bold") {
                    guard let textView = NSApp.keyWindow?.firstResponder as? NotionMarkdownTextView else { return }
                    textView.toggleMarkdownWrap("**")
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Italic") {
                    guard let textView = NSApp.keyWindow?.firstResponder as? NotionMarkdownTextView else { return }
                    textView.toggleMarkdownWrap("*")
                }
                .keyboardShortcut("i", modifiers: [.command])

                Button("Strikethrough") {
                    guard let textView = NSApp.keyWindow?.firstResponder as? NotionMarkdownTextView else { return }
                    textView.toggleMarkdownWrap("~~")
                }
                .keyboardShortcut("x", modifiers: [.command, .shift])

                Button("Inline Code") {
                    guard let textView = NSApp.keyWindow?.firstResponder as? NotionMarkdownTextView else { return }
                    textView.toggleMarkdownWrap("`")
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Link") {
                    guard let textView = NSApp.keyWindow?.firstResponder as? NotionMarkdownTextView else { return }
                    textView.insertLinkTemplate()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }

            CommandMenu("InkArc") {
                Button("Reload Document") {
                    model.reload()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(model.fileURL == nil)

                Divider()

                Button("Research Preset") {
                    settings.preset = .research
                }

                Button("Compact Preset") {
                    settings.preset = .compact
                }

                Divider()

                Button("Increase Text Size") {
                    settings.increaseFontSize()
                }
                .keyboardShortcut("+", modifiers: [.command])

                Button("Decrease Text Size") {
                    settings.decreaseFontSize()
                }
                .keyboardShortcut("-", modifiers: [.command])

                Divider()

                Button(settings.focusMode ? "Disable Focus Mode" : "Enable Focus Mode") {
                    settings.focusMode.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}
