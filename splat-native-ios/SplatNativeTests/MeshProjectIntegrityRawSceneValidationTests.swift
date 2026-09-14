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

    func testRawSceneValidatorRejectsNaNWorldTransform() {
        let scene = SCNScene()
        let node = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
        node.simdPosition.x = Float.nan
        scene.rootNode.addChildNode(node)

        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRawSceneValidatorRejectsInfiniteAncestorTransform() {
        let scene = SCNScene()
        let container = SCNNode()
        container.simdPosition.z = Float.infinity
        container.addChildNode(SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)))
        scene.rootNode.addChildNode(container)

        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRawSceneValidatorRejectsFiniteInputsThatOverflowInWorldSpace() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(Float.greatestFiniteMagnitude, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let triangle = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        let node = SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [triangle]))
        node.simdScale = SIMD3<Float>(repeating: 2)
        scene.rootNode.addChildNode(node)

        XCTAssertTrue(Float.greatestFiniteMagnitude.isFinite)
        XCTAssertTrue(node.simdWorldTransform.columns.0.x.isFinite)
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }
}
