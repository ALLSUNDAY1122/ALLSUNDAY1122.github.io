import Foundation

enum MeshDepthPayload {
    // A depth frame is transient capture input, not an arbitrary file payload. Keep malformed
    // dimensions from turning one frame into a process-sized allocation. This remains well above
    // expected iPhone/iPad depth-map sizes.
    private static let maximumPackedByteCount = 128 * 1024 * 1024

    /// Copies a Float32 depth plane into the tightly packed on-disk layout used by MeshDepthRecorder.
    /// ARKit pixel buffers may pad each source row; allocate the destination once and copy only the
    /// meaningful width so capture does not create one temporary Data allocation per row.
    static func tightlyPackedFloat32(
        baseAddress: UnsafeRawPointer,
        width: Int,
        height: Int,
        sourceRowBytes: Int
    ) -> Data? {
        guard width > 0, height > 0 else { return nil }

        let (rowBytes, rowOverflow) = width.multipliedReportingOverflow(by: MemoryLayout<Float>.size)
        guard !rowOverflow, sourceRowBytes >= rowBytes else { return nil }
        let (totalBytes, totalOverflow) = rowBytes.multipliedReportingOverflow(by: height)
        guard !totalOverflow,
              totalBytes > 0,
              totalBytes <= Self.maximumPackedByteCount else { return nil }

        let (lastRowOffset, sourceOffsetOverflow) = (height - 1).multipliedReportingOverflow(by: sourceRowBytes)
        guard !sourceOffsetOverflow else { return nil }
        let (_, sourceSpanOverflow) = lastRowOffset.addingReportingOverflow(rowBytes)
        guard !sourceSpanOverflow else { return nil }

        var data = Data(count: totalBytes)
        data.withUnsafeMutableBytes { destination in
            guard let destinationBase = destination.baseAddress else { return }
            if sourceRowBytes == rowBytes {
                destinationBase.copyMemory(from: baseAddress, byteCount: totalBytes)
                return
            }
            for row in 0..<height {
                destinationBase.advanced(by: row * rowBytes).copyMemory(
                    from: baseAddress.advanced(by: row * sourceRowBytes),
                    byteCount: rowBytes
                )
            }
        }
        return data
    }
}