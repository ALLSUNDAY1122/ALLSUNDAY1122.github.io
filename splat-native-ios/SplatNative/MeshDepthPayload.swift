import Foundation

enum MeshDepthPayload {
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
        guard !totalOverflow, totalBytes > 0 else { return nil }

        var data = Data(count: totalBytes)
        data.withUnsafeMutableBytes { destination in
            guard let destinationBase = destination.baseAddress else { return }
            for row in 0..<height {
                destinationBase
                    .advanced(by: row * rowBytes)
                    .copyMemory(
                        from: baseAddress.advanced(by: row * sourceRowBytes),
                        byteCount: rowBytes
                    )
            }
        }
        return data
    }
}
