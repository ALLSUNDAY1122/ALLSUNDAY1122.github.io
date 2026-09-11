import SceneKit

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains no mesh
    /// geometry. Treat that as reconstruction failure rather than a finished user-visible asset.
    static func containsGeometry(_ scene: SCNScene) -> Bool {
        if scene.rootNode.geometry != nil {
            return true
        }
        var containsGeometry = false
        scene.rootNode.enumerateChildNodes { node, stop in
            guard node.geometry != nil else { return }
            containsGeometry = true
            stop.pointee = true
        }
        return containsGeometry
    }
}
