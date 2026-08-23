import AVFoundation
import CoreGraphics
import CoreImage
import Vision
import FrameExtraction
import ImageCorrection
import PageAudit

/// Compile-only probe. It deliberately performs no file/network I/O and is never a Golden PASS/FAIL gate.
public enum AppleAdapterContractProbe {
    public static func validatePublicAppleSurface() {
        let frameConfiguration = FrameExtractionConfiguration()
        let frameExtractor = AVFoundationStableFrameExtractor(configuration: frameConfiguration)
        _ = frameExtractor

        let correctionConfiguration = PageCorrectionConfiguration()
        let correctionEngine = PageCorrectionEngine(configuration: correctionConfiguration)
        _ = correctionEngine

        _ = VisionPageAuditRecognizer.self
        _ = VisionPageAuditRecognition.self

        // Touch Apple SDK symbols used across the three adapters so an unavailable or
        // incompatible framework/API is caught by the same iPhoneOS typecheck.
        _ = AVAsset.self
        _ = CGImage.self
        _ = CIContext.self
        _ = VNRecognizeTextRequest.self
    }
}
