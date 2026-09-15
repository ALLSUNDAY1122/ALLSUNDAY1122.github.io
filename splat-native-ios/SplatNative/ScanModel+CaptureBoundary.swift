import Foundation

/// Stable owner-facing contract for capture work.
///
/// HQ2 keeps `ScanModel` as the integration implementation while A2 works
/// against this surface. Add capture-specific behavior outside ScanModel.swift
/// whenever possible so parallel lanes do not overwrite the shared hotspot.
@MainActor
protocol ScanCaptureBoundary: AnyObject {
    var phase: ScanModel.Phase { get }
    var acceptedFrames: Int { get }
    var targetFrames: Int { get set }
    var featurePointCount: Int { get }
    var coverageSectorCount: Int { get }
    var trackingMessage: String { get }
    var isCapturePaused: Bool { get }
    var activeCaptureSeconds: Double { get }
    var ignoreLiDAR: Bool { get set }
    var depthCaptureActive: Bool { get }

    var lidarControlAvailable: Bool { get }
    var canFinishCapture: Bool { get }
    var progressText: String { get }
    var captureBand: String { get }
    var captureQualityText: String { get }

    func startCapture()
    func pauseCapture()
    func resumeCapture()
    func finishCapture()
}

extension ScanModel: ScanCaptureBoundary {}
