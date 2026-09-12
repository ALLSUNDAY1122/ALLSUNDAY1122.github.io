import SceneKit

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains either no
    /// geometry nodes, geometry containers with zero primitives, malformed geometry that has
    /// elements but no complete vertex-position payload, invalid indices, or only point/line
    /// primitives. None is a usable finished surface Mesh, so require at least one surface
    /// primitive backed by complete vertex and index payloads.
    static func containsGeometry(_ scene: SCNScene) -> Bool {
        if hasRenderableGeometry(scene.rootNode.geometry) {
            return true
        }
        var containsGeometry = false
        scene.rootNode.enumerateChildNodes { node, stop in
            guard hasRenderableGeometry(node.geometry) else { return }
            containsGeometry = true
            stop.pointee = true
        }
        return containsGeometry
    }

    private static func hasRenderableGeometry(_ geometry: SCNGeometry?) -> Bool {
        guard let geometry,
              !geometry.elements.isEmpty,
              let vertices = geometry.sources(for: .vertex).first,
              hasCompleteVertexPayload(vertices) else { return false }
        return geometry.elements.contains { element in
            guard element.primitiveCount > 0 else { return false }
            switch element.primitiveType {
            case .triangles, .triangleStrip:
                return hasValidIndexedSurface(element, vertexCount: vertices.vectorCount)
            case .polygon:
                // Polygon elements use variable-length per-polygon index records. SceneKit's
                // decoder has already validated their container representation; keep accepting
                // them here rather than applying the fixed-width triangle/strip contract.
                return element.bytesPerIndex > 0 && !element.data.isEmpty
            case .line, .point:
                return false
            @unknown default:
                return false
            }
        }
    }

    private static func hasCompleteVertexPayload(_ source: SCNGeometrySource) -> Bool {
        guard source.vectorCount > 0,
              source.componentsPerVector >= 3,
              source.bytesPerComponent > 0,
              source.dataOffset >= 0,
              source.dataStride >= 0,
              !source.data.isEmpty else { return false }

        let (vectorBytes, componentOverflow) = source.componentsPerVector.multipliedReportingOverflow(
            by: source.bytesPerComponent
        )
        guard !componentOverflow, vectorBytes > 0 else { return false }
        let stride = source.dataStride == 0 ? vectorBytes : source.dataStride
        guard stride >= vectorBytes else { return false }

        let (precedingBytes, strideOverflow) = (source.vectorCount - 1).multipliedReportingOverflow(by: stride)
        guard !strideOverflow else { return false }
        let (lastVectorStart, offsetOverflow) = source.dataOffset.addingReportingOverflow(precedingBytes)
        guard !offsetOverflow else { return false }
        let (requiredBytes, payloadOverflow) = lastVectorStart.addingReportingOverflow(vectorBytes)
        guard !payloadOverflow else { return false }
        return requiredBytes <= source.data.count
    }

    private static func hasValidIndexedSurface(_ element: SCNGeometryElement, vertexCount: Int) -> Bool {
        guard vertexCount > 0,
              element.bytesPerIndex == 1 || element.bytesPerIndex == 2 || element.bytesPerIndex == 4 else {
            return false
        }

        let indexCount: Int
        switch element.primitiveType {
        case .triangles:
            let (count, overflow) = element.primitiveCount.multipliedReportingOverflow(by: 3)
            guard !overflow else { return false }
            indexCount = count
        case .triangleStrip:
            let (count, overflow) = element.primitiveCount.addingReportingOverflow(2)
            guard !overflow else { return false }
            indexCount = count
        default:
            return false
        }
        guard indexCount > 0 else { return false }

        let (requiredBytes, overflow) = indexCount.multipliedReportingOverflow(by: element.bytesPerIndex)
        guard !overflow, requiredBytes <= element.data.count else { return false }

        return element.data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return false }
            for index in 0..<indexCount {
                let pointer = base.advanced(by: index * element.bytesPerIndex)
                let value: UInt32
                switch element.bytesPerIndex {
                case 1:
                    value = UInt32(pointer.load(as: UInt8.self))
                case 2:
                    value = UInt32(UInt16(littleEndian: pointer.loadUnaligned(as: UInt16.self)))
                case 4:
                    value = UInt32(littleEndian: pointer.loadUnaligned(as: UInt32.self))
                default:
                    return false
                }
                if value >= UInt32(vertexCount) { return false }
            }
            return true
        }
    }
}
