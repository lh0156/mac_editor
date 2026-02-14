import Foundation

enum TypographyPreset: String, CaseIterable, Identifiable {
    case research
    case compact

    var id: String { rawValue }

    var label: String {
        switch self {
        case .research:
            return "Research"
        case .compact:
            return "Compact"
        }
    }

    var evidenceLabel: String {
        switch self {
        case .research:
            return "55-75 CPL / line-height 1.58-1.70"
        case .compact:
            return "70-90 CPL / line-height 1.45-1.58"
        }
    }
}

final class ReaderSettings: ObservableObject {
    static let fontRange: ClosedRange<Double> = 14 ... 32
    private static let averageGlyphWidthFactor: Double = 0.53
    private static let minReadableWidth: Double = 560
    private static let maxReadableWidth: Double = 920

    @Published var preset: TypographyPreset = .research {
        didSet { applyPreset(preset) }
    }

    @Published var fontName: String = "SF Pro Text"
    @Published var fontSize: Double = 18
    @Published var lineHeight: Double = 1.62
    @Published var maxContentWidth: Double = 640
    @Published private(set) var estimatedCPL: Int = 66
    @Published var focusMode: Bool = false

    private var targetCPL: Double = 66

    var lineSpacing: Double {
        max(0, fontSize * (lineHeight - 1))
    }

    init() {
        applyPreset(preset)
    }

    func applyPreset(_ preset: TypographyPreset) {
        switch preset {
        case .research:
            fontName = "SF Pro Text"
            fontSize = 18
            lineHeight = 1.62
            targetCPL = 66
        case .compact:
            fontName = "SF Pro Text"
            fontSize = 17
            lineHeight = 1.52
            targetCPL = 80
        }
        recomputeContentWidth()
    }

    func increaseFontSize() {
        fontSize = min(fontSize + 1, Self.fontRange.upperBound)
        recomputeContentWidth()
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 1, Self.fontRange.lowerBound)
        recomputeContentWidth()
    }

    private func recomputeContentWidth() {
        let estimatedCharacterWidth = fontSize * Self.averageGlyphWidthFactor
        let ideal = estimatedCharacterWidth * targetCPL
        maxContentWidth = min(Self.maxReadableWidth, max(Self.minReadableWidth, ideal))
        estimatedCPL = Int((maxContentWidth / max(1, estimatedCharacterWidth)).rounded())
    }
}
