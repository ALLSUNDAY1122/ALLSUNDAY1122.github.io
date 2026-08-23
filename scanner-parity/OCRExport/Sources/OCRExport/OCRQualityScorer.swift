import Foundation

public enum OCRQualityScorer {
    public static func evaluate(text: String, blocks: [OCRBlock], layout: OCRLayout) -> OCRQuality {
        let scalars = Array(text.unicodeScalars)
        let visibleScalars = scalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        let visibleCount = max(1, visibleScalars.count)

        let japaneseCount = visibleScalars.filter(isJapanese).count
        let noiseCount = visibleScalars.filter(isLikelyNoise).count
        let japaneseRatio = Double(japaneseCount) / Double(visibleCount)
        let noiseRatio = Double(noiseCount) / Double(visibleCount)

        let weightedConfidence: Double = {
            let weights = blocks.map { max(1, $0.text.count) }
            let total = max(1, weights.reduce(0, +))
            let sum = zip(blocks, weights).reduce(0.0) { partial, pair in
                partial + clamp(pair.0.confidence) * Double(pair.1)
            }
            return sum / Double(total)
        }()

        let meaningful = blocks.filter { block in
            let count = block.text.unicodeScalars.filter { isJapanese($0) || CharacterSet.decimalDigits.contains($0) }.count
            return layout == .vertical ? count >= 1 : count >= 3
        }.count
        let meaningfulLineRatio = blocks.isEmpty ? 0 : Double(meaningful) / Double(blocks.count)

        let fragments = blocks.filter { block in
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if layout == .vertical { return false }
            return trimmed.count <= 2 && !trimmed.unicodeScalars.contains(where: isJapanese)
        }.count
        let fragmentRatio = blocks.isEmpty ? 1 : Double(fragments) / Double(blocks.count)

        let lengthBonus = min(1.0, Double(visibleCount) / 120.0)
        let languageSignal = min(1.0, japaneseRatio * 1.8 + 0.15)
        let score = clamp(
            weightedConfidence * 0.48
            + meaningfulLineRatio * 0.19
            + languageSignal * 0.14
            + lengthBonus * 0.12
            + (1 - fragmentRatio) * 0.07
            - noiseRatio * 0.35
        )

        let tooShort = visibleCount < 8
        let needsReview = tooShort || score < 0.62 || weightedConfidence < 0.55 || noiseRatio > 0.08
        return OCRQuality(
            score: score,
            meanConfidence: weightedConfidence,
            japaneseRatio: japaneseRatio,
            noiseRatio: noiseRatio,
            fragmentRatio: fragmentRatio,
            meaningfulLineRatio: meaningfulLineRatio,
            needsReview: needsReview
        )
    }

    public static func inferLayout(from blocks: [OCRBlock]) -> OCRLayout {
        guard !blocks.isEmpty else { return .unknown }
        var vertical = 0
        var horizontal = 0
        for block in blocks {
            let width = max(0.0001, block.boundingBox.width)
            let height = max(0.0001, block.boundingBox.height)
            if height / width >= 1.6 { vertical += 1 }
            if width / height >= 1.6 { horizontal += 1 }
        }
        let count = Double(blocks.count)
        let verticalRatio = Double(vertical) / count
        let horizontalRatio = Double(horizontal) / count
        if verticalRatio >= 0.55 && horizontalRatio < 0.25 { return .vertical }
        if horizontalRatio >= 0.55 && verticalRatio < 0.25 { return .horizontal }
        if verticalRatio >= 0.20 && horizontalRatio >= 0.20 { return .mixed }
        return .unknown
    }

    private static func isJapanese(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30ff, 0x31f0...0x31ff, 0x3400...0x9fff, 0xff66...0xff9f:
            return true
        default:
            return false
        }
    }

    private static func isLikelyNoise(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x7c, 0x5f, 0x3c, 0x3e, 0x5c, 0x60, 0x5e:
            return true
        default:
            return false
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
