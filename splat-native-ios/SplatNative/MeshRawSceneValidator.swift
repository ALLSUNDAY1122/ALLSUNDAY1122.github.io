import SceneKit

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains either no
    /// geometry nodes or geometry containers with zero primitives. Neither is a usable finished
    /// Mesh, so require at least one geometry element that actually contains primitives.
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
              !geometry.sources.isEmpty,
              !geometry.elements.isEmpty else { return false }
        return geometry.elements.contains { $0.primitiveCount > 0 }
    }
}
