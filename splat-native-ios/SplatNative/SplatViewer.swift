import Foundation
import Metal
import MetalKit
import MetalSplatter
import SplatIO
import SwiftUI
import simd

private struct ViewerCameraDataset: Decodable {
    let frames: [ViewerCameraFrame]
}

private struct ViewerCameraFrame: Decodable {
    let transformMatrix: [[Float]]

    enum CodingKeys: String, CodingKey {
        case transformMatrix = "transform_matrix"
    }
}

struct SplatViewer: UIViewRepresentable {
    let url: URL
    @ObservedObject var state: SplatViewerState

    final class Coordinator {
        var renderer: SplatViewerRenderer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.025, green: 0.03, blue: 0.04, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false

        guard let renderer = SplatViewerRenderer(view: view, state: state) else { return view }
        context.coordinator.renderer = renderer
        view.delegate = renderer
        renderer.load(url: url)

        let orbit = UIPanGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.orbit(_:)))
        orbit.minimumNumberOfTouches = 1
        orbit.maximumNumberOfTouches = 1

        let scenePan = UIPanGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.scenePan(_:)))
        scenePan.minimumNumberOfTouches = 2
        scenePan.maximumNumberOfTouches = 2

        let pinch = UIPinchGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.pinch(_:)))

        let measureTap = UITapGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.measureTap(_:)))
        measureTap.numberOfTapsRequired = 1
        measureTap.numberOfTouchesRequired = 1

        let reset = UITapGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.resetView(_:)))
        reset.numberOfTapsRequired = 2
        reset.numberOfTouchesRequired = 2

        for gesture in [orbit, scenePan, pinch, measureTap, reset] {
            gesture.delegate = renderer
            view.addGestureRecognizer(gesture)
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        renderer.load(url: url)
        renderer.synchronize(with: state)
    }
}

@MainActor
final class SplatViewerRenderer: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate {
    private struct AxisRange: Sendable {
        let low: Float
        let high: Float

        var extent: Float { max(0.0001, high - low) }
        func value(at fraction: Double) -> Float {
            low + extent * Float(min(1, max(0, fraction)))
        }
    }

    private struct CropBounds: Sendable {
        let x: AxisRange
        let y: AxisRange
        let z: AxisRange
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private weak var view: MTKView?
    private weak var state: SplatViewerState?
    private var renderer: SplatRenderer?
    private var sourcePoints: [SplatPoint] = []
    private var pickPositions: [SIMD3<Float>] = []
    private var cropBounds = CropBounds(
        x: AxisRange(low: -1, high: 1),
        y: AxisRange(low: -1, high: 1),
        z: AxisRange(low: -1, high: 1)
    )

    private var loadedURL: URL?
    private var loadingURL: URL?
    private var drawableSize: CGSize
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var initialYaw: Float = 0
    private var initialPitch: Float = 0
    private var distance: Float = 2.5
    private var baseDistance: Float = 2.5
    private var sceneCenter = SIMD3<Float>.zero
    private var targetOffset = SIMD3<Float>.zero
    private var measurementPoints: [SIMD3<Float>] = []
    private var requestedSettings = SplatEditSettings.default
    private var renderedSettings = SplatEditSettings.default
    private var loadGeneration = 0
    private var editGeneration = 0
    private var lastResetToken: Int
    private var lastClearMeasurementToken: Int
    private var lastReloadToken: Int
    private var editDebounceTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var rebuildTask: Task<Void, Never>?
    private var consecutiveRenderFailures = 0
    private let semaphore = DispatchSemaphore(value: 2)
    private let fovY: Float = 55 * .pi / 180

    init?(view: MTKView, state: SplatViewerState) {
        guard let device = view.device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        self.view = view
        self.state = state
        self.drawableSize = view.drawableSize
        self.requestedSettings = state.editSettings
        self.renderedSettings = state.editSettings
        self.lastResetToken = state.resetCameraToken
        self.lastClearMeasurementToken = state.clearMeasurementToken
        self.lastReloadToken = state.reloadToken
        super.init()
    }

    func load(url: URL) {
        guard loadedURL != url, loadingURL != url else { return }
        loadGeneration &+= 1
        let generation = loadGeneration
        loadTask?.cancel()
        editDebounceTask?.cancel()
        rebuildTask?.cancel()
        loadingURL = url
        loadedURL = nil
        renderer = nil
        sourcePoints.removeAll(keepingCapacity: false)
        pickPositions.removeAll(keepingCapacity: false)
        measurementPoints.removeAll(keepingCapacity: false)
        state?.rendererBeganLoading()

        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let reader = try AutodetectSceneReader(url)
                let points = try await reader.readAll()
                guard !Task.isCancelled, generation == self.loadGeneration else { return }
                guard !points.isEmpty else {
                    self.loadingURL = nil
                    self.state?.rendererFailed("3Dデータに表示できる点がありません")
                    return
                }

                let framing = Self.robustFraming(for: points)
                self.sceneCenter = framing.center
                self.baseDistance = framing.distance
                self.distance = framing.distance
                self.cropBounds = Self.robustCropBounds(for: points)
                self.sourcePoints = points
                self.targetOffset = .zero

                let initial = Self.initialViewGeometry(for: url, center: framing.center)
                self.initialYaw = initial.yaw
                self.initialPitch = initial.pitch
                self.yaw = self.initialYaw
                self.pitch = self.initialPitch
                self.loadedURL = url
                self.loadingURL = nil
                self.state?.rendererLoaded(total: points.count)
                self.requestedSettings = self.state?.editSettings ?? .default
                self.rebuildImmediately(settings: self.requestedSettings)
            } catch {
                guard generation == self.loadGeneration else { return }
                self.loadingURL = nil
                self.state?.rendererFailed("3Dデータを読み込めませんでした: \(error.localizedDescription)")
            }
        }
    }

    func synchronize(with state: SplatViewerState) {
        self.state = state

        if lastReloadToken != state.reloadToken {
            lastReloadToken = state.reloadToken
            forceReload()
            return
        }
        if lastResetToken != state.resetCameraToken {
            lastResetToken = state.resetCameraToken
            resetCamera()
        }
        if lastClearMeasurementToken != state.clearMeasurementToken {
            lastClearMeasurementToken = state.clearMeasurementToken
            clearMeasurement()
        }

        let settings = state.editSettings
        if settings != requestedSettings {
            requestedSettings = settings
            scheduleRebuild(settings: settings)
        }
    }

    @objc func orbit(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, !stateMeasurementEnabled else { return }
        let delta = gesture.translation(in: view)
        yaw += Float(delta.x) * 0.006
        pitch = max(-1.15, min(1.15, pitch + Float(delta.y) * 0.0045))
        gesture.setTranslation(.zero, in: view)
    }

    @objc func scenePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view, !stateMeasurementEnabled else { return }
        let delta = gesture.translation(in: view)
        let target = sceneCenter + targetOffset
        let eye = target + orbitVector
        let forward = simd_normalize(target - eye)
        let worldUp = SIMD3<Float>(0, 1, 0)
        let right = simd_normalize(simd_cross(forward, worldUp))
        let up = simd_normalize(simd_cross(right, forward))
        let pixels = max(1, Float(view.bounds.height))
        let worldPerPixel = max(0.00001, 2 * tan(fovY * 0.5) * distance / pixels)

        // Rendering applies a 180-degree camera-space roll. Compensate here so the
        // scene follows the user's two-finger drag on screen.
        targetOffset += right * Float(delta.x) * worldPerPixel
        targetOffset -= up * Float(delta.y) * worldPerPixel
        gesture.setTranslation(.zero, in: view)
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        guard !stateMeasurementEnabled else { return }
        distance = max(baseDistance * 0.12, min(baseDistance * 7.0, distance / Float(gesture.scale)))
        gesture.scale = 1
    }

    @objc func resetView(_ gesture: UITapGestureRecognizer) {
        resetCamera()
    }

    @objc func measureTap(_ gesture: UITapGestureRecognizer) {
        guard stateMeasurementEnabled,
              let view = gesture.view,
              !pickPositions.isEmpty else { return }
        let location = gesture.location(in: view)
        guard let picked = nearestVisiblePoint(to: location, in: view.bounds.size) else {
            state?.rendererRejectedEdit("点が見つかりません。3Dの表面をタップしてください")
            return
        }

        if measurementPoints.count >= 2 {
            measurementPoints.removeAll(keepingCapacity: true)
        }
        measurementPoints.append(picked)
        if measurementPoints.count == 1 {
            state?.rendererSelectedMeasurementPoint(count: 1)
        } else if measurementPoints.count == 2 {
            // SplatViewerState converts exported scene units back into meters using
            // the exact camera normalization applied by the pinned msplat trainer.
            state?.rendererMeasured(meters: simd_distance(measurementPoints[0], measurementPoints[1]))
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) ||
        (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
    }

    func draw(in view: MTKView) {
        guard let renderer, renderer.isReadyToRender,
              drawableSize.width > 0, drawableSize.height > 0,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        _ = semaphore.wait(timeout: .distantFuture)
        commandBuffer.addCompletedHandler { [semaphore] _ in semaphore.signal() }

        let matrices = cameraMatrices(size: drawableSize)
        let viewport = SplatRenderer.ViewportDescriptor(
            viewport: MTLViewport(originX: 0, originY: 0, width: drawableSize.width, height: drawableSize.height, znear: 0, zfar: 1),
            projectionMatrix: matrices.projection,
            viewMatrix: matrices.view,
            screenSize: SIMD2(Int(drawableSize.width), Int(drawableSize.height))
        )

        do {
            let rendered = try renderer.render(viewports: [viewport],
                                               colorTexture: drawable.texture,
                                               colorStoreAction: .store,
                                               depthTexture: view.depthStencilTexture,
                                               rasterizationRateMap: nil,
                                               renderTargetArrayLength: 0,
                                               to: commandBuffer)
            consecutiveRenderFailures = 0
            if rendered { commandBuffer.present(drawable) }
        } catch {
            consecutiveRenderFailures += 1
            if consecutiveRenderFailures == 3 {
                state?.rendererFailed("3D表示を継続できませんでした: \(error.localizedDescription)")
            }
        }
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
    }

    private var stateMeasurementEnabled: Bool {
        state?.measurementEnabled ?? false
    }

    private var orbitVector: SIMD3<Float> {
        SIMD3<Float>(
            sin(yaw) * cos(pitch) * distance,
            sin(pitch) * distance,
            cos(yaw) * cos(pitch) * distance
        )
    }

    private func resetCamera() {
        yaw = initialYaw
        pitch = initialPitch
        distance = baseDistance
        targetOffset = .zero
    }

    private func clearMeasurement() {
        measurementPoints.removeAll(keepingCapacity: true)
    }

    private func forceReload() {
        guard let url = loadedURL ?? loadingURL else { return }
        loadedURL = nil
        loadingURL = nil
        load(url: url)
    }

    private func scheduleRebuild(settings: SplatEditSettings) {
        guard !sourcePoints.isEmpty else { return }
        editDebounceTask?.cancel()
        editDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, let self else { return }
            self.rebuildImmediately(settings: settings)
        }
    }

    private func rebuildImmediately(settings: SplatEditSettings) {
        guard !sourcePoints.isEmpty else { return }
        editGeneration &+= 1
        let generation = editGeneration
        let points = sourcePoints
        let bounds = cropBounds
        let settings = settings.normalized()
        state?.rendererBeganApplyingEdits()
        rebuildTask?.cancel()

        rebuildTask = Task { [weak self] in
            guard let self else { return }
            let edited = await Task.detached(priority: .userInitiated) {
                Self.editedPoints(points, settings: settings, bounds: bounds)
            }.value
            guard !Task.isCancelled, generation == self.editGeneration else { return }
            guard !edited.isEmpty else {
                self.state?.rendererRejectedEdit("切り抜き範囲に3Dデータが残っていません")
                return
            }

            do {
                let candidate = try SplatRenderer(
                    device: self.device,
                    colorFormat: self.view?.colorPixelFormat ?? .bgra8Unorm_srgb,
                    depthFormat: self.view?.depthStencilPixelFormat ?? .depth32Float,
                    sampleCount: 1,
                    maxViewCount: 1,
                    maxSimultaneousRenders: 2
                )
                let chunk = try SplatChunk(device: self.device, from: edited)
                await candidate.addChunk(chunk)
                guard generation == self.editGeneration else { return }
                self.renderer = candidate
                self.renderedSettings = settings
                self.pickPositions = Self.sampledPositions(from: edited, limit: 15_000)
                self.clearMeasurement()
                self.consecutiveRenderFailures = 0
                self.state?.rendererAppliedEdits(visible: edited.count)
            } catch {
                guard generation == self.editGeneration else { return }
                self.state?.rendererRejectedEdit("編集結果を表示できませんでした: \(error.localizedDescription)")
            }
        }
    }

    private func cameraMatrices(size: CGSize) -> (projection: simd_float4x4, view: simd_float4x4) {
        let aspect = max(0.1, Float(size.width / max(1, size.height)))
        let projection = perspective(fovY: fovY, aspect: aspect, near: 0.01, far: 100)
        let target = sceneCenter + targetOffset
        let eye = target + orbitVector
        let baseView = lookAt(eye: eye, center: target, up: SIMD3<Float>(0, 1, 0))

        // The old implementation multiplied this correction on the world side,
        // which rotates translated scans around the global origin and can push an
        // otherwise correctly framed subject off-center. Apply it in camera space.
        let correctedView = rotationZ(.pi) * baseView
        return (projection, correctedView)
    }

    private func nearestVisiblePoint(to location: CGPoint, in size: CGSize) -> SIMD3<Float>? {
        guard size.width > 0, size.height > 0 else { return nil }
        let matrices = cameraMatrices(size: size)
        var best: SIMD3<Float>?
        var bestDistanceSquared = CGFloat(42 * 42)

        for point in pickPositions {
            let clip = matrices.projection * matrices.view * SIMD4<Float>(point.x, point.y, point.z, 1)
            guard clip.w > 0.0001 else { continue }
            let ndc = SIMD3<Float>(clip.x, clip.y, clip.z) / clip.w
            guard ndc.x >= -1.1, ndc.x <= 1.1, ndc.y >= -1.1, ndc.y <= 1.1 else { continue }
            let normalizedX = CGFloat(ndc.x) * 0.5 + 0.5
            let normalizedY = CGFloat(ndc.y) * 0.5 + 0.5
            let x = normalizedX * size.width
            let y = (1.0 - normalizedY) * size.height
            let dx = x - location.x
            let dy = y - location.y
            let d2 = dx * dx + dy * dy
            if d2 < bestDistanceSquared {
                bestDistanceSquared = d2
                best = point
            }
        }
        return best
    }

    /// Reproduces the pinned msplat camera center/scale normalization before
    /// comparing the capture camera positions with the exported Splat scene.
    private static func initialViewGeometry(for url: URL, center: SIMD3<Float>) -> (yaw: Float, pitch: Float) {
        let transformsURL = url.deletingLastPathComponent().appendingPathComponent("transforms.json")
        guard let data = try? Data(contentsOf: transformsURL),
              let dataset = try? JSONDecoder().decode(ViewerCameraDataset.self, from: data),
              !dataset.frames.isEmpty else { return (0, 0) }

        let positions = dataset.frames.compactMap { frame -> SIMD3<Float>? in
            let matrix = frame.transformMatrix
            guard matrix.count >= 3,
                  matrix[0].count >= 4,
                  matrix[1].count >= 4,
                  matrix[2].count >= 4 else { return nil }
            return SIMD3<Float>(matrix[0][3], matrix[1][3], matrix[2][3])
        }
        guard !positions.isEmpty else { return (0, 0) }

        let normalization = SplatSceneNormalization(cameraPositions: positions)
        var cameraSum = SIMD3<Float>.zero
        var count: Float = 0
        for position in positions.prefix(6) {
            cameraSum += position
            count += 1
        }
        guard count > 0 else { return (0, 0) }

        let camera = normalization.normalized(cameraSum / count)
        let vector = camera - center
        let length = simd_length(vector)
        guard length > 0.05 else { return (0, 0) }
        let yaw = atan2(vector.x, vector.z)
        let pitch = asin(max(-0.9, min(0.9, vector.y / length)))
        return (yaw, pitch)
    }

    private static func robustFraming(for points: [SplatPoint]) -> (center: SIMD3<Float>, distance: Float) {
        let strideSize = max(1, points.count / 6_000)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        xs.reserveCapacity(min(points.count, 6_000))
        ys.reserveCapacity(min(points.count, 6_000))
        zs.reserveCapacity(min(points.count, 6_000))

        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            xs.append(p.x)
            ys.append(p.y)
            zs.append(p.z)
        }

        guard !xs.isEmpty else { return (.zero, 2.5) }
        xs.sort(); ys.sort(); zs.sort()
        let middle = xs.count / 2
        let center = SIMD3<Float>(xs[middle], ys[middle], zs[middle])

        var radii: [Float] = []
        radii.reserveCapacity(xs.count)
        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            radii.append(simd_distance(p, center))
        }
        radii.sort()
        guard !radii.isEmpty else { return (center, 2.5) }
        let percentileIndex = min(radii.count - 1, Int(Float(radii.count - 1) * 0.90))
        let radius = max(0.10, radii[percentileIndex])
        let framingDistance = max(0.35, min(18.0, radius * 2.8))
        return (center, framingDistance)
    }

    private static func robustCropBounds(for points: [SplatPoint]) -> CropBounds {
        let strideSize = max(1, points.count / 8_000)
        var xs: [Float] = []
        var ys: [Float] = []
        var zs: [Float] = []
        for index in stride(from: 0, to: points.count, by: strideSize) {
            let p = points[index].position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            xs.append(p.x); ys.append(p.y); zs.append(p.z)
        }
        return CropBounds(
            x: percentileRange(xs),
            y: percentileRange(ys),
            z: percentileRange(zs)
        )
    }

    nonisolated private static func percentileRange(_ values: [Float]) -> AxisRange {
        guard !values.isEmpty else { return AxisRange(low: -1, high: 1) }
        let sorted = values.sorted()
        let lowIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.01))
        let highIndex = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.99))
        var low = sorted[lowIndex]
        var high = sorted[highIndex]
        if !low.isFinite || !high.isFinite || high - low < 0.0001 {
            low = sorted.first ?? -1
            high = sorted.last ?? 1
        }
        if high - low < 0.0001 {
            high = low + 0.0001
        }
        return AxisRange(low: low, high: high)
    }

    nonisolated private static func editedPoints(_ points: [SplatPoint],
                                                  settings: SplatEditSettings,
                                                  bounds: CropBounds) -> [SplatPoint] {
        let settings = settings.normalized()
        let exposureGain = Float(pow(2.0, settings.exposureEV))
        let contrast = Float(settings.contrast)
        let needsColorAdjustment = abs(settings.exposureEV) > 0.0001 || abs(settings.contrast - 1) > 0.0001

        let xLow = bounds.x.value(at: settings.cropXMin)
        let xHigh = bounds.x.value(at: settings.cropXMax)
        let yLow = bounds.y.value(at: settings.cropYMin)
        let yHigh = bounds.y.value(at: settings.cropYMax)
        let zLow = bounds.z.value(at: settings.cropZMin)
        let zHigh = bounds.z.value(at: settings.cropZMax)
        let cropX = settings.cropXMin > 0.0001 || settings.cropXMax < 0.9999
        let cropY = settings.cropYMin > 0.0001 || settings.cropYMax < 0.9999
        let cropZ = settings.cropZMin > 0.0001 || settings.cropZMax < 0.9999

        var result: [SplatPoint] = []
        result.reserveCapacity(points.count)
        for point in points {
            let p = point.position
            guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
            if cropX && (p.x < xLow || p.x > xHigh) { continue }
            if cropY && (p.y < yLow || p.y > yHigh) { continue }
            if cropZ && (p.z < zLow || p.z > zHigh) { continue }

            guard needsColorAdjustment else {
                result.append(point)
                continue
            }

            var edited = point
            let base = point.color.asSRGBFloat
            let exposed = base * exposureGain
            let midpoint = SIMD3<Float>(repeating: 0.5)
            let adjusted = simd_clamp((exposed - midpoint) * contrast + midpoint, .zero, .one)

            switch point.color {
            case .sphericalHarmonicFloat(var coefficients):
                if !coefficients.isEmpty {
                    coefficients[0] = (adjusted - midpoint) * SplatPoint.Color.INV_SH_C0
                    edited.color = .sphericalHarmonicFloat(coefficients)
                }
            case .sRGBUInt8:
                edited.color = .sRGBUInt8(SIMD3<UInt8>(
                    byte(adjusted.x), byte(adjusted.y), byte(adjusted.z)
                ))
            }
            result.append(edited)
        }
        return result
    }

    nonisolated private static func byte(_ value: Float) -> UInt8 {
        UInt8(clamping: Int((max(0, min(1, value)) * 255).rounded()))
    }

    nonisolated private static func sampledPositions(from points: [SplatPoint], limit: Int) -> [SIMD3<Float>] {
        guard !points.isEmpty else { return [] }
        let step = max(1, points.count / max(1, limit))
        var result: [SIMD3<Float>] = []
        result.reserveCapacity(min(points.count, limit + 1))
        for index in stride(from: 0, to: points.count, by: step) {
            let p = points[index].position
            if p.x.isFinite, p.y.isFinite, p.z.isFinite { result.append(p) }
        }
        return result
    }

    private func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
        let y = 1 / tan(fovY * 0.5)
        let x = y / aspect
        let z = far / (near - far)
        return simd_float4x4(columns: (
            SIMD4<Float>(x, 0, 0, 0),
            SIMD4<Float>(0, y, 0, 0),
            SIMD4<Float>(0, 0, z, -1),
            SIMD4<Float>(0, 0, z * near, 0)
        ))
    }

    private func lookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
        let z = simd_normalize(eye - center)
        let x = simd_normalize(simd_cross(up, z))
        let y = simd_cross(z, x)
        return simd_float4x4(columns: (
            SIMD4<Float>(x.x, y.x, z.x, 0),
            SIMD4<Float>(x.y, y.y, z.y, 0),
            SIMD4<Float>(x.z, y.z, z.z, 0),
            SIMD4<Float>(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)
        ))
    }

    private func rotationZ(_ angle: Float) -> simd_float4x4 {
        let c = cos(angle), s = sin(angle)
        return simd_float4x4(columns: (
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}
