import AVFoundation
import Metal
import XCTest

final class SplatVideoColorPipelineTests: XCTestCase {
    func testVideoRenderTargetUsesSRGBEncodingLikeLiveViewer() {
        XCTAssertEqual(SplatVideoExporter.renderPixelFormat, .bgra8Unorm_srgb)
    }

    func testEncodedVideoDeclaresBT709ColorProperties() {
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoColorPrimariesKey],
            AVVideoColorPrimaries_ITU_R_709_2
        )
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoTransferFunctionKey],
            AVVideoTransferFunction_ITU_R_709_2
        )
        XCTAssertEqual(
            SplatVideoExporter.videoColorProperties[AVVideoYCbCrMatrixKey],
            AVVideoYCbCrMatrix_ITU_R_709_2
        )
    }
}
