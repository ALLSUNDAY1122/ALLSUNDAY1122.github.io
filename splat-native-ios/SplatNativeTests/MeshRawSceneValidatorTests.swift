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

    func testRejectsTriangleWhoseIndexExceedsVertexPayload() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let invalid = SCNGeometryElement(indices: [UInt16(0), 1, 7], primitiveType: .triangles)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [invalid])))

        XCTAssertEqual(invalid.primitiveCount, 1)
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testAcceptsValidIndexedTriangleSurface() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let triangle = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .triangles)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [triangle])))

        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsPointCloudAsFinishedSurfaceMesh() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(0, 1, 0),
        ])
        let points = SCNGeometryElement(indices: [UInt16(0), 1, 2], primitiveType: .point)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [points])))

        XCTAssertGreaterThan(points.primitiveCount, 0)
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testRejectsLineGeometryAsFinishedSurfaceMesh() {
        let scene = SCNScene()
        let vertices = SCNGeometrySource(vertices: [
            SCNVector3(0, 0, 0),
            SCNVector3(1, 0, 0),
        ])
        let lines = SCNGeometryElement(indices: [UInt16(0), 1], primitiveType: .line)
        scene.rootNode.addChildNode(SCNNode(geometry: SCNGeometry(sources: [vertices], elements: [lines])))

        XCTAssertGreaterThan(lines.primitiveCount, 0)
        XCTAssertFalse(MeshRawSceneValidator.containsGeometry(scene))
    }

    func testAcceptsNestedSurfaceGeometryWithPrimitives() {
        let scene = SCNScene()
        let container = SCNNode()
        let meshNode = SCNNode(geometry: SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0))
        container.addChildNode(meshNode)
        scene.rootNode.addChildNode(container)

        XCTAssertTrue(MeshRawSceneValidator.containsGeometry(scene))
    }
}
