import SceneKit
import XCTest

final class MeshRawSceneValidatorTests: XCTestCase {
    func testRejectsDecodedSceneWithoutGeometry() {
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(SCNScene()))
    }

    func testRejectsGeometryContainerWithoutPrimitives() {
        let scene = SCNScene()
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [], elements: [])))

        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testAcceptsNestedGeometryWithPrimitives() {
        let scene = SCNScene()
        let container = SCNNode()
        let meshNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
        container.addChildNode(meshNode)
        scene.rootNode.addChildNode(container)

        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }
}
