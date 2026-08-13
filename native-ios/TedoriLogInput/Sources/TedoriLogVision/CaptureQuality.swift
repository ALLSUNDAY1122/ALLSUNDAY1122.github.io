#if canImport(CoreImage)
import Foundation
import CoreImage
import CoreGraphics

/// 撮影品質の判定と撮り直し誘導。
/// 「読めない写真をそのまま解析して、要確認だらけの結果を見せる」のを避けるための入口。
public enum CaptureQuality {

    public enum Issue: String {
        case tooDark = "暗すぎます。明るい場所で撮り直してください"
        case tooBright = "明るすぎます。光の反射を避けてください"
        case lowContrast = "文字がぼやけています。ピントを合わせて撮り直してください"
        case tilted = "傾いています。明細と平行になるよう構えてください"
        case tooSmall = "文字が小さすぎます。明細に近づいて撮ってください"
    }

    public struct Assessment {
        public var brightness: Double      // 0..1
        public var contrast: Double        // 標準偏差 0..1
        public var skewDegrees: Double
        public var pixelWidth: Int
        public var issues: [Issue]
        public var isUsable: Bool { issues.isEmpty }
        public var shouldRetake: Bool {
            issues.contains(.tooDark) || issues.contains(.lowContrast) || issues.contains(.tooSmall)
        }
        public var message: String? { issues.first?.rawValue }
    }

    public static func assess(_ image: CGImage, skewDegrees: Double = 0) -> Assessment {
        let stats = luminanceStats(image)
        var issues: [Issue] = []
        if stats.mean < 0.28 { issues.append(.tooDark) }
        if stats.mean > 0.94 { issues.append(.tooBright) }
        if stats.stdDev < 0.06 { issues.append(.lowContrast) }
        if abs(skewDegrees) > 4 { issues.append(.tilted) }
        if image.width < 1000 { issues.append(.tooSmall) }
        return Assessment(brightness: stats.mean, contrast: stats.stdDev, skewDegrees: skewDegrees,
                          pixelWidth: image.width, issues: issues)
    }

    /// 解析後の傾き推定を反映して評価し直す（Visionのトークンから傾きが分かるため）。
    public static func assess(_ image: CGImage, slope: Double) -> Assessment {
        assess(image, skewDegrees: atan(slope) * 180 / .pi)
    }

    private static func luminanceStats(_ image: CGImage) -> (mean: Double, stdDev: Double) {
        let width = 64
        let height = max(1, Int(Double(width) * Double(image.height) / Double(max(image.width, 1))))
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return (0.5, 0.5) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let values = pixels.map { Double($0) / 255.0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return (mean, variance.squareRoot())
    }
}
#endif
