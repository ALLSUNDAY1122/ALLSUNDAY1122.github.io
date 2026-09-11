import SceneKit

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains either no
    /// geometry nodes, geometry containers with zero primitives, or malformed geometry that has
    /// elements but no complete vertex-position payload. None is a usable finished Mesh, so require
    /// at least one geometry element with primitives backed by a complete vertex source.
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
        return geometry.elements.contains { $0.primitiveCount > 0 }
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
}
