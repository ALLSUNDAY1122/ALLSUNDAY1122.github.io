#if canImport(CoreImage)
import Foundation
import CoreImage

/// 再OCR用の画像補正（端末内で完結）。
/// 影・低コントラスト・小さすぎる文字を、1回目で読めなかったときだけ補正する。
public enum ImagePreprocessor {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    public static func enhanceForOCR(_ image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        // 1) 照明ムラの平坦化（大きくぼかした背景で割る）
        if let blur = CIFilter(name: "CIBoxBlur") {
            blur.setValue(ciImage, forKey: kCIInputImageKey)
            blur.setValue(max(20, Double(image.width) / 25), forKey: kCIInputRadiusKey)
            if let background = blur.outputImage?.cropped(to: ciImage.extent),
               let divide = CIFilter(name: "CIDivideBlendMode") {
                divide.setValue(background, forKey: kCIInputBackgroundImageKey)
                divide.setValue(ciImage, forKey: kCIInputImageKey)
                if let output = divide.outputImage { ciImage = output.cropped(to: ciImage.extent) }
            }
        }
        // 2) グレースケール化とコントラスト強調
        if let controls = CIFilter(name: "CIColorControls") {
            controls.setValue(ciImage, forKey: kCIInputImageKey)
            controls.setValue(0.0, forKey: kCIInputSaturationKey)
            controls.setValue(1.35, forKey: kCIInputContrastKey)
            controls.setValue(0.02, forKey: kCIInputBrightnessKey)
            if let output = controls.outputImage { ciImage = output }
        }
        // 3) 文字の輪郭を立てる（軽いアンシャープ）
        if let sharpen = CIFilter(name: "CIUnsharpMask") {
            sharpen.setValue(ciImage, forKey: kCIInputImageKey)
            sharpen.setValue(1.6, forKey: kCIInputRadiusKey)
            sharpen.setValue(0.7, forKey: kCIInputIntensityKey)
            if let output = sharpen.outputImage { ciImage = output }
        }
        // 4) 小さい画像は拡大してから読ませる
        let targetWidth = 1600.0
        if Double(image.width) < targetWidth, let scaleFilter = CIFilter(name: "CILanczosScaleTransform") {
            scaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
            scaleFilter.setValue(targetWidth / Double(image.width), forKey: kCIInputScaleKey)
            scaleFilter.setValue(1.0, forKey: kCIInputAspectRatioKey)
            if let output = scaleFilter.outputImage { ciImage = output }
        }

        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
#endif
