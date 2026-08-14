import Metal
import MetalKit
import MetalSplatter
import SplatIO
import SwiftUI
import simd

struct SplatViewer: UIViewRepresentable {
    let url: URL

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
        let renderer = SplatViewerRenderer(view: view)
        context.coordinator.renderer = renderer
        view.delegate = renderer
        renderer?.load(url: url)

        let pan = UIPanGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.pan(_:)))
        let pinch = UIPinchGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.pinch(_:)))
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.renderer?.load(url: url)
    }
}

@MainActor
final class SplatViewerRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private weak var view: MTKView?
    private var renderer: SplatRenderer?
    private var loadedURL: URL?
    private var drawableSize: CGSize = .zero
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var distance: Float = 2.5
    private let semaphore = DispatchSemaphore(value: 2)

    init?(view: MTKView) {
        guard let device = view.device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        self.view = view
        super.init()
    }

    func load(url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        renderer = nil
        Task {
            do {
                let r = try SplatRenderer(device: device,
                                          colorFormat: view?.colorPixelFormat ?? .bgra8Unorm_srgb,
                                          depthFormat: view?.depthStencilPixelFormat ?? .depth32Float,
                                          sampleCount: 1,
                                          maxViewCount: 1,
                                          maxSimultaneousRenders: 2)
                let reader = try AutodetectSceneReader(url)
                let points = try await reader.readAll()
                let chunk = try SplatChunk(device: device, from: points)
                await r.addChunk(chunk)
                renderer = r
            } catch {
                print("Splat load failed: \(error)")
            }
        }
    }

    @objc func pan(_ g: UIPanGestureRecognizer) {
        guard let v = g.view else { return }
        let delta = g.translation(in: v)
        yaw += Float(delta.x) * 0.006
        pitch = max(-1.1, min(1.1, pitch + Float(delta.y) * 0.004))
        g.setTranslation(.zero, in: v)
    }

    @objc func pinch(_ g: UIPinchGestureRecognizer) {
        distance = max(0.45, min(8, distance / Float(g.scale)))
        g.scale = 1
    }

    func draw(in view: MTKView) {
        guard let renderer, renderer.isReadyToRender,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        _ = semaphore.wait(timeout: .distantFuture)
        commandBuffer.addCompletedHandler { [semaphore] _ in semaphore.signal() }

        let aspect = max(0.1, Float(drawableSize.width / max(1, drawableSize.height)))
        let projection = perspective(fovY: 55 * .pi / 180, aspect: aspect, near: 0.05, far: 100)
        let eye = SIMD3<Float>(
            sin(yaw) * cos(pitch) * distance,
            sin(pitch) * distance,
            cos(yaw) * cos(pitch) * distance
        )
        let viewMatrix = lookAt(eye: eye, center: .zero, up: SIMD3<Float>(0, 1, 0))
        let viewport = SplatRenderer.ViewportDescriptor(
            viewport: MTLViewport(originX: 0, originY: 0, width: drawableSize.width, height: drawableSize.height, znear: 0, zfar: 1),
            projectionMatrix: projection,
            viewMatrix: viewMatrix * rotationZ(.pi),
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
            if rendered { commandBuffer.present(drawable) }
        } catch {
            print("Splat render failed: \(error)")
        }
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        drawableSize = size
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

    private func rotationZ(_ a: Float) -> simd_float4x4 {
        let c = cos(a), s = sin(a)
        return simd_float4x4(columns: (
            SIMD4<Float>(c, s, 0, 0),
            SIMD4<Float>(-s, c, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(0, 0, 0, 1)
        ))
    }
}
