import XCTest

final class MeshDepthPayloadOverflowTests: XCTestCase {
    func testNormalPackedDepthCopyStillWorks() {
        var source: [Float] = [1, 2, 3, 4]
        let data = source.withUnsafeBytes { bytes in
            MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: bytes.baseAddress!,
                width: 2,
                height: 2,
                sourceRowBytes: 2 * MemoryLayout<Float>.size
            )
        }

        XCTAssertEqual(data?.count, 4 * MemoryLayout<Float>.size)
    }

    func testOverflowingSourceSpanIsRejectedBeforePointerAdvance() {
        var source: Float = 1
        let data = withUnsafePointer(to: &source) { pointer in
            MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: UnsafeRawPointer(pointer),
                width: 1,
                height: 2,
                sourceRowBytes: Int.max
            )
        }

        XCTAssertNil(data)
    }
}
