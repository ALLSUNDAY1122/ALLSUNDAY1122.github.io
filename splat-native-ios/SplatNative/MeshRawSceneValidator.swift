import SceneKit
import simd

enum MeshRawSceneValidator {
    /// SceneKit can successfully decode a syntactically valid USDZ whose scene contains either no
    /// geometry nodes, geometry containers with zero primitives, malformed geometry that has
    /// elements but no complete vertex-position payload, invalid indices, non-finite geometry, or
    /// only point/line primitives. None is a usable finished surface Mesh, so require at least one
    /// surface primitive backed by complete, finite vertex/transform and valid non-degenerate index
    /// payloads.
    static func containsGeometry(_ scene: SCNScene) -> Bool {
        let root = scene.rootNode
        if hasFiniteWorldTransform(root),
           hasRenderableGeometry(root.geometry, worldTransform: root.simdWorldTransform) {
            return true
        }
        var containsGeometry = false
        root.enumerateChildNodes { node, stop in
            guard hasFiniteWorldTransform(node),
                  hasRenderableGeometry(node.geometry, worldTransform: node.simdWorldTransform) else { return }
            containsGeometry = true
            stop.pointee = true
        }
        return containsGeometry
    }

    private static func hasFiniteWorldTransform(_ node: SCNNode) -> Bool {
        let transform = node.simdWorldTransform
        for column in [transform.columns.0, transform.columns.1, transform.columns.2, transform.columns.3] {
            guard column.x.isFinite,
                  column.y.isFinite,
                  column.z.isFinite,
                  column.w.isFinite else { return false }
        }
        return true
    }

    private static func hasRenderableGeometry(
        _ geometry: SCNGeometry?,
        worldTransform: simd_float4x4
    ) -> Bool {
        guard let geometry,
              !geometry.elements.isEmpty,
              let vertices = geometry.sources(for: .vertex).first,
              hasCompleteVertexPayload(vertices),
              hasFiniteVertexPositions(vertices, worldTransform: worldTransform) else { return false }
        return geometry.elements.contains { element in
            guard element.primitiveCount > 0 else { return false }
            switch element.primitiveType {
            case .triangles, .triangleStrip:
                return hasValidIndexedSurface(
                    element,
                    vertices: vertices,
                    worldTransform: worldTransform
                )
            case .polygon:
                return hasValidPolygonSurface(
                    element,
                    vertices: vertices,
                    worldTransform: worldTransform
                )
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

    private static func hasFiniteVertexPositions(
        _ source: SCNGeometrySource,
        worldTransform: simd_float4x4
    ) -> Bool {
        // Integer-backed local coordinates are finite by construction. The production Mesh paths
        // use floating positions; validate those both locally and after the node's world transform
        // so two individually finite values cannot overflow into Inf during framing/render/export.
        guard source.usesFloatComponents else { return true }
        guard source.bytesPerComponent == 4 || source.bytesPerComponent == 8 else { return false }

        return source.data.withUnsafeBytes { rawBuffer in
            guard rawBuffer.baseAddress != nil else { return false }
            for vectorIndex in 0..<source.vectorCount {
                guard worldPosition(
                    vectorIndex,
                    source: source,
                    worldTransform: worldTransform,
                    rawBuffer: rawBuffer
                ) != nil else { return false }
            }
            return true
        }
    }

    private static func worldPosition(
        _ vectorIndex: Int,
        source: SCNGeometrySource,
        worldTransform: simd_float4x4,
        rawBuffer: UnsafeRawBufferPointer
    ) -> SIMD3<Float>? {
        guard source.usesFloatComponents,
              source.bytesPerComponent == 4 || source.bytesPerComponent == 8,
              let base = rawBuffer.baseAddress else { return nil }

        let componentBytes = source.bytesPerComponent
        let vectorBytes = source.componentsPerVector * componentBytes
        let stride = source.dataStride == 0 ? vectorBytes : source.dataStride
        let vectorStart = source.dataOffset + vectorIndex * stride
        let xPointer = base.advanced(by: vectorStart)
        let yPointer = base.advanced(by: vectorStart + componentBytes)
        let zPointer = base.advanced(by: vectorStart + componentBytes * 2)

        let x: Float
        let y: Float
        let z: Float
        switch componentBytes {
        case 4:
            x = xPointer.loadUnaligned(as: Float.self)
            y = yPointer.loadUnaligned(as: Float.self)
            z = zPointer.loadUnaligned(as: Float.self)
        case 8:
            let dx = xPointer.loadUnaligned(as: Double.self)
            let dy = yPointer.loadUnaligned(as: Double.self)
            let dz = zPointer.loadUnaligned(as: Double.self)
            guard dx.isFinite, dy.isFinite, dz.isFinite else { return nil }
            x = Float(dx)
            y = Float(dy)
            z = Float(dz)
        default:
            return nil
        }

        guard x.isFinite, y.isFinite, z.isFinite else { return nil }
        let world = worldTransform * SIMD4<Float>(x, y, z, 1)
        guard world.x.isFinite,
              world.y.isFinite,
              world.z.isFinite,
              world.w.isFinite else { return nil }
        return SIMD3<Float>(world.x, world.y, world.z)
    }

    private static func hasValidIndexedSurface(
        _ element: SCNGeometryElement,
        vertices: SCNGeometrySource,
        worldTransform: simd_float4x4
    ) -> Bool {
        guard vertices.vectorCount > 0,
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

        return element.data.withUnsafeBytes { indexBuffer in
            guard indexBuffer.baseAddress != nil else { return false }
            // Pass 1 validates the complete payload without materializing a second O(indexCount)
            // array. Large reconstructed scenes can contain millions of indices.
            for index in 0..<indexCount {
                guard let value = indexValue(index, element: element, rawBuffer: indexBuffer),
                      value < UInt32(vertices.vectorCount) else { return false }
            }

            // Integer-backed positions are not used by the production reconstruction paths and
            // require format-specific normalization semantics. Preserve their prior structural
            // acceptance rather than guessing coordinates here.
            guard vertices.usesFloatComponents else { return true }

            return vertices.data.withUnsafeBytes { vertexBuffer in
                guard vertexBuffer.baseAddress != nil else { return false }
                let triangleCount: Int
                switch element.primitiveType {
                case .triangles:
                    triangleCount = element.primitiveCount
                case .triangleStrip:
                    triangleCount = max(0, indexCount - 2)
                default:
                    return false
                }

                // Pass 2 only reads the three indices for each primitive and exits on the first
                // usable surface. Valid meshes therefore pay no index-sized allocation and usually
                // stop the area check after their first triangle.
                for triangleIndex in 0..<triangleCount {
                    let baseIndex: Int
                    switch element.primitiveType {
                    case .triangles:
                        baseIndex = triangleIndex * 3
                    case .triangleStrip:
                        baseIndex = triangleIndex
                    default:
                        return false
                    }
                    guard let rawA = indexValue(baseIndex, element: element, rawBuffer: indexBuffer),
                          let rawB = indexValue(baseIndex + 1, element: element, rawBuffer: indexBuffer),
                          let rawC = indexValue(baseIndex + 2, element: element, rawBuffer: indexBuffer),
                          let a = worldPosition(Int(rawA), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer),
                          let b = worldPosition(Int(rawB), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer),
                          let c = worldPosition(Int(rawC), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer) else {
                        return false
                    }
                    if formsNonDegenerateTriangle(a, b, c) {
                        return true
                    }
                }
                return false
            }
        }
    }

    /// SceneKit polygon elements encode each primitive as a vertex-count token followed by that
    /// polygon's indices. Treating any non-empty polygon payload as a finished surface allowed a
    /// malformed/out-of-range or fully degenerate polygon to bypass the triangle validator.
    private static func hasValidPolygonSurface(
        _ element: SCNGeometryElement,
        vertices: SCNGeometrySource,
        worldTransform: simd_float4x4
    ) -> Bool {
        guard element.primitiveType == .polygon,
              element.primitiveCount > 0,
              vertices.vectorCount > 0,
              element.bytesPerIndex == 1 || element.bytesPerIndex == 2 || element.bytesPerIndex == 4,
              !element.data.isEmpty else { return false }

        return element.data.withUnsafeBytes { indexBuffer in
            guard indexBuffer.baseAddress != nil else { return false }
            let availableTokens = element.data.count / element.bytesPerIndex
            var cursor = 0
            var polygons: [(start: Int, count: Int)] = []
            polygons.reserveCapacity(min(element.primitiveCount, 64))

            for _ in 0..<element.primitiveCount {
                guard cursor < availableTokens,
                      let rawCount = indexValue(cursor, element: element, rawBuffer: indexBuffer),
                      rawCount >= 3,
                      rawCount <= UInt32(Int.max) else { return false }
                cursor += 1
                let count = Int(rawCount)
                let (end, overflow) = cursor.addingReportingOverflow(count)
                guard !overflow, end <= availableTokens else { return false }
                for token in cursor..<end {
                    guard let value = indexValue(token, element: element, rawBuffer: indexBuffer),
                          value < UInt32(vertices.vectorCount) else { return false }
                }
                polygons.append((start: cursor, count: count))
                cursor = end
            }

            guard vertices.usesFloatComponents else { return !polygons.isEmpty }
            return vertices.data.withUnsafeBytes { vertexBuffer in
                guard vertexBuffer.baseAddress != nil else { return false }
                for polygon in polygons {
                    guard let rawA = indexValue(polygon.start, element: element, rawBuffer: indexBuffer),
                          let a = worldPosition(Int(rawA), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer) else {
                        return false
                    }
                    for offset in 1..<(polygon.count - 1) {
                        guard let rawB = indexValue(polygon.start + offset, element: element, rawBuffer: indexBuffer),
                              let rawC = indexValue(polygon.start + offset + 1, element: element, rawBuffer: indexBuffer),
                              let b = worldPosition(Int(rawB), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer),
                              let c = worldPosition(Int(rawC), source: vertices, worldTransform: worldTransform, rawBuffer: vertexBuffer) else {
                            return false
                        }
                        if formsNonDegenerateTriangle(a, b, c) {
                            return true
                        }
                    }
                }
                return false
            }
        }
    }

    private static func formsNonDegenerateTriangle(
        _ a: SIMD3<Float>,
        _ b: SIMD3<Float>,
        _ c: SIMD3<Float>
    ) -> Bool {
        let ab = b - a
        let ac = c - a
        guard ab.x.isFinite, ab.y.isFinite, ab.z.isFinite,
              ac.x.isFinite, ac.y.isFinite, ac.z.isFinite else { return false }
        let cross = simd_cross(ab, ac)
        guard cross.x.isFinite, cross.y.isFinite, cross.z.isFinite else { return false }
        return cross.x != 0 || cross.y != 0 || cross.z != 0
    }

    private static func indexValue(
        _ index: Int,
        element: SCNGeometryElement,
        rawBuffer: UnsafeRawBufferPointer
    ) -> UInt32? {
        guard let base = rawBuffer.baseAddress else { return nil }
        let pointer = base.advanced(by: index * element.bytesPerIndex)
        switch element.bytesPerIndex {
        case 1:
            return UInt32(pointer.load(as: UInt8.self))
        case 2:
            return UInt32(UInt16(littleEndian: pointer.loadUnaligned(as: UInt16.self)))
        case 4:
            return UInt32(littleEndian: pointer.loadUnaligned(as: UInt32.self))
        default:
            return nil
        }
    }
}
