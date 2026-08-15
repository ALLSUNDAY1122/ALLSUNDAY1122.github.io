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
        let doubleTap = UITapGestureRecognizer(target: renderer, action: #selector(SplatViewerRenderer.resetView(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(doubleTap)
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
    private var loadingURL: URL?
    private var drawableSize: CGSize
    private var yaw: Float = 0
    private var pitch: Float = 0
    private var distance: Float = 2.5
    private var baseDistance: Float = 2.5
    private var sceneCenter = SIMD3<Float>.zero
    private let semaphore = DispatchSemaphore(value: 2)

    init?(view: MTKView) {
        guard let device = view.device, let queue = device.makeCommandQueue() else { return nil }
        self.device = device
        self.commandQueue = queue
        self.view = view
        self.drawableSize = view.drawableSize
        super.init()
    }

    func load(url: URL) {
        guard loadedURL != url, loadingURL != url else { return }
        loadingURL = url
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
                guard !points.isEmpty else {
                    loadingURL = nil
                    return
                }

                let framing = SplatCameraGeometry.robustFraming(for: points)
                sceneCenter = framing.center
                baseDistance = framing.distance
                distance = framing.distance
                yaw = 0
                pitch = 0

                let chunk = try SplatChunk(device: device, from: points)
                await r.addChunk(chunk)
                renderer = r
                loadedURL = url
                loadingURL = nil
            } catch {
                loadingURL = nil
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
        distance = max(baseDistance * 0.18, min(baseDistance * 5.0, distance / Float(g.scale)))
        g.scale = 1
    }

    @objc func resetView(_ g: UITapGestureRecognizer) {
        yaw = 0
        pitch = 0
        distance = baseDistance
    }

    func draw(in view: MTKView) {
        guard let renderer, renderer.isReadyToRender,
              drawableSize.width > 0, drawableSize.height > 0,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        _ = semaphore.wait(timeout: .distantFuture)
        commandBuffer.addCompletedHandler { [semaphore] _ in semaphore.signal() }

        let aspect = max(0.1, Float(drawableSize.width / max(1, drawableSize.height)))
        let projection = SplatCameraGeometry.perspective(fovY: 55 * .pi / 180, aspect: aspect, near: 0.01, far: 100)
        let eye = SplatCameraGeometry.eye(center: sceneCenter, distance: distance, yaw: yaw, pitch: pitch)
        let viewMatrix = SplatCameraGeometry.lookAt(eye: eye, center: sceneCenter, up: SIMD3<Float>(0, 1, 0))
        let viewport = SplatRenderer.ViewportDescriptor(
            viewport: MTLViewport(originX: 0, originY: 0, width: drawableSize.width, height: drawableSize.height, znear: 0, zfar: 1),
            projectionMatrix: projection,
            viewMatrix: viewMatrix * SplatCameraGeometry.rotationZ(.pi),
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
}
