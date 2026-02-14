import SwiftUI
import UniformTypeIdentifiers

struct ReaderRootView: View {
    @ObservedObject var model: ReaderModel
    @ObservedObject var settings: ReaderSettings
    @Binding var showingImporter: Bool

    private var markdownTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let md = UTType(filenameExtension: "md") {
            types.append(md)
        }
        if let markdown = UTType(filenameExtension: "markdown") {
            types.append(markdown)
        }
        return types
    }

    var body: some View {
        ZStack(alignment: .top) {
            paperBackground

            editorSurface
                .padding(.top, settings.focusMode ? 10 : 54)
                .padding(.horizontal, settings.focusMode ? 8 : 18)
                .padding(.bottom, 10)

            if !settings.focusMode {
                toolbar
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: markdownTypes,
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                model.open(url: url)
            case .failure(let error):
                model.errorMessage = "파일 선택에 실패했습니다: \(error.localizedDescription)"
            }
        }
        .alert("오류", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { newValue in
                if !newValue { model.errorMessage = nil }
            }
        )) {
            Button("확인", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var paperBackground: some View {
        ZStack {
            Color(nsColor: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1))
            LinearGradient(
                colors: [
                    Color.white.opacity(0.72),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .opacity(1.0)
        }
        .ignoresSafeArea()
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                toolbarIconButton(systemImage: "square.and.pencil") {
                    model.newDocument()
                }
                toolbarIconButton(systemImage: "folder") {
                    showingImporter = true
                }
                toolbarIconButton(systemImage: "square.and.arrow.down") {
                    model.save()
                }
            }

            Spacer(minLength: 10)

            Menu {
                Picker("Preset", selection: $settings.preset) {
                    ForEach(TypographyPreset.allCases) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                Divider()
                Button("Increase Text Size") {
                    settings.increaseFontSize()
                }
                Button("Decrease Text Size") {
                    settings.decreaseFontSize()
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12.5, weight: .semibold))
                    .padding(8)
                    .background(Color.white.opacity(0.68), in: Circle())
            }
            .menuStyle(.borderlessButton)

            HStack(spacing: 7) {
                Text(model.displayName)
                    .font(.custom("SF Pro Display", size: 13))
                    .lineLimit(1)

                if model.hasUnsavedChanges {
                    Circle()
                        .fill(Color(red: 0.84, green: 0.57, blue: 0.15))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.84), in: Capsule())

            Text("\(model.wordCount) words")
                .font(.custom("SF Pro Text", size: 11))
                .foregroundStyle(Color(red: 0.36, green: 0.40, blue: 0.46))

            Button {
                settings.focusMode.toggle()
            } label: {
                Image(systemName: settings.focusMode ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                    .font(.system(size: 12.5, weight: .semibold))
            }
            .buttonStyle(.plain)
            .padding(8)
            .background(Color.white.opacity(0.68), in: Circle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(red: 0.84, green: 0.85, blue: 0.83).opacity(0.90), lineWidth: 0.85)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 2)
        .frame(maxWidth: 760)
    }

    private var editorSurface: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                Spacer(minLength: 0)

                PlainMarkdownEditor(
                    text: Binding(
                        get: { model.rawMarkdown },
                        set: { model.updateMarkdown($0) }
                    ),
                    fontName: settings.fontName,
                    fontSize: settings.fontSize,
                    lineSpacing: settings.lineSpacing
                )
                .frame(maxWidth: settings.maxContentWidth, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 18)
                .padding(.vertical, settings.focusMode ? 10 : 24)

                Spacer(minLength: 0)
            }

            if !settings.focusMode {
                Text("\(settings.preset.evidenceLabel) · now \(settings.estimatedCPL) CPL")
                    .font(.custom("SF Pro Text", size: 10.5))
                    .foregroundStyle(Color(red: 0.54, green: 0.55, blue: 0.51))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toolbarIconButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                )
        }
        .buttonStyle(.plain)
    }
}
