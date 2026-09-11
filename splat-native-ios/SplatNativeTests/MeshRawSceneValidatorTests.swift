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

    func testRejectsPrimitiveElementsWithoutVertexPositions() {
        let scene = SCNScene()
        let normals = SCNGeometrySource(normals: [
            SCNVector3(0, 1, 0),
            SCNVector3(0, 1, 0),
            SCNVector3(0, 1, 0),
        ])
        let element = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        let malformed = SCNGeometry(sources: [normals], elements: [element])
        scene.rootNode.addChildNode(SCNNode(geometry: malformed))

        XCTAssertEqual(element.primitiveCount, 1)
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsTruncatedVertexPayloadEvenWhenPrimitiveCountIsPositive() {
        let scene = SCNScene()
        let truncatedVertices = SCNGeometrySource(
            data: Data(repeating: 0, count: 12),
            semantic: .vertex,
            vectorCount: 3,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: 4,
            dataOffset: 0,
            dataStride: 12
        )
        let element = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        let malformed = SCNGeometry(sources: [truncatedVertices], elements: [element])
        scene.rootNode.addChildNode(SCNNode(geometry: malformed))

        XCTAssertEqual(element.primitiveCount, 1)
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
