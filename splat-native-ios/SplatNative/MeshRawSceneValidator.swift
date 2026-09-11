import SceneKit

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains either no
    /// geometry nodes, geometry containers with zero primitives, or malformed geometry that has
    /// elements but no vertex-position payload. None is a usable finished Mesh, so require at least
    /// one geometry element with primitives backed by an actual vertex source.
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
              vertices.vectorCount > 0,
              vertices.componentsPerVector >= 3,
              !vertices.data.isEmpty else { return false }
        return geometry.elements.contains { $0.primitiveCount > 0 }
    }
}
