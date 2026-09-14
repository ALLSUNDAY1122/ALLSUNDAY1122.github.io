import SceneKit
import XCTest

extension MeshProjectIntegrityTests {
    func testRawSceneValidatorRejectsNaNVertexPosition() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(Float.nan, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let triangle = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [triangle])))

        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRawSceneValidatorRejectsInfiniteVertexPosition() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, -Float.infinity, 0),
            SCNVector3(0, 1, 0),
        ])
        let triangle = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [triangle])))

        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }
}
