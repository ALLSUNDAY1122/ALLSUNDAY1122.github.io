import XCTest

final class MeshDepthPayloadTests: XCTestCase {
    func testStripsSourceRowPaddingWithoutChangingFloatBytes() throws {
        let rowBytes = 2 * MemoryLayout<Float>.size
        let stride = rowBytes + 4
        var source = Data(count: stride * 2)

        let expected: [UInt8] = [
            0x00, 0x00, 0x80, 0x3F,
            0x00, 0x00, 0x00, 0x40,
            0x00, 0x00, 0x40, 0x40,
            0x00, 0x00, 0x80, 0x40,
        ]
        source.replaceSubrange(0..<rowBytes, with: expected[0..<rowBytes])
        source.replaceSubrange(stride..<(stride + rowBytes), with: expected[rowBytes..<expected.count])
        source.replaceSubrange(rowBytes..<stride, with: [0xAA, 0xAA, 0xAA, 0xAA])
        source.replaceSubrange((stride + rowBytes)..<(stride * 2), with: [0xBB, 0xBB, 0xBB, 0xBB])

        let packed = source.withUnsafeBytes { bytes in
            MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: bytes.baseAddress!,
                width: 2,
                height: 2,
                sourceRowBytes: stride
            )
        }

        XCTAssertEqual(packed, Data(expected))
    }

    func testRejectsInvalidStrideAndDimensions() {
        let source = Data(repeating: 0, count: 16)
        source.withUnsafeBytes { bytes in
            let base = bytes.baseAddress!
            XCTAssertNil(MeshDepthPayload.tightlyPackedFloat32(baseAddress: base, width: 0, height: 1, sourceRowBytes: 8))
            XCTAssertNil(MeshDepthPayload.tightlyPackedFloat32(baseAddress: base, width: 2, height: 0, sourceRowBytes: 8))
            XCTAssertNil(MeshDepthPayload.tightlyPackedFloat32(baseAddress: base, width: 2, height: 1, sourceRowBytes: 7))
        }
    }
}
