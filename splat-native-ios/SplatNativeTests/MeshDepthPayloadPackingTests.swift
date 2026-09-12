import Foundation
import XCTest

final class MeshDepthPayloadPackingTests: XCTestCase {
    func testTightlyPackedPlanePreservesAllFloatBytes() {
        let values: [Float] = [0.25, 0.5, 1.0, 2.0, 3.5, 7.25]
        let result = values.withUnsafeBytes { raw -> Data? in
            guard let base = raw.baseAddress else { return nil }
            return MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: base,
                width: 3,
                height: 2,
                sourceRowBytes: 3 * MemoryLayout<Float>.size
            )
        }
        XCTAssertEqual(result, values.withUnsafeBytes { Data($0) })
    }

    func testPaddedRowsDiscardStridePaddingWithoutChangingPixels() {
        let pixelBytes = 2 * MemoryLayout<Float>.size
        let sourceRowBytes = pixelBytes + 8
        var source = Data(count: sourceRowBytes * 2)
        let first: [Float] = [1.25, 2.5]
        let second: [Float] = [3.75, 5.0]
        source.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            first.withUnsafeBytes { base.copyMemory(from: $0.baseAddress!, byteCount: pixelBytes) }
            second.withUnsafeBytes {
                base.advanced(by: sourceRowBytes).copyMemory(from: $0.baseAddress!, byteCount: pixelBytes)
            }
            memset(base.advanced(by: pixelBytes), 0x7f, 8)
            memset(base.advanced(by: sourceRowBytes + pixelBytes), 0x7f, 8)
        }

        let result = source.withUnsafeBytes { raw -> Data? in
            guard let base = raw.baseAddress else { return nil }
            return MeshDepthPayload.tightlyPackedFloat32(
                baseAddress: base,
                width: 2,
                height: 2,
                sourceRowBytes: sourceRowBytes
            )
        }
        let expected = first.withUnsafeBytes { Data($0) } + second.withUnsafeBytes { Data($0) }
        XCTAssertEqual(result, expected)
    }
}
