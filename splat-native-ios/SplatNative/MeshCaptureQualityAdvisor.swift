@preconcurrency import ARKit
import Foundation
import SwiftUI
import simd

@MainActor
final class MeshCaptureQualityAdvisor: ObservableObject {
    @Published private(set) var azimuthCoverage = 0
    @Published private(set) var elevationCoverage = 0
    @Published private(set) var pathLengthMeters: Float = 0
    @Published private(set) var stableSamples = 0
    @Published private(set) var qualityScore: Double = 0
    @Published private(set) var guidance = "対象の周囲をゆっくり移動してください"

    private var azimuthBins = Set<Int>()
    private var elevationBins = Set<Int>()
    private var lastPosition: SIMD3<Float>?
    private var lastTimestamp: TimeInterval = -.greatestFiniteMagnitude

    func reset() {
        azimuthBins.removeAll()
        elevationBins.removeAll()
        lastPosition = nil
        lastTimestamp = -.greatestFiniteMagnitude
        azimuthCoverage = 0
        elevationCoverage = 0
        pathLengthMeters = 0
        stableSamples = 0
        qualityScore = 0
        guidance = "対象の周囲をゆっくり移動してください"
    }

    func record(frame: ARFrame, mode: MeshCaptureMode, size: MeshScanSize, frameCount: Int, faceCount: Int) {
        guard frame.timestamp - lastTimestamp >= 0.16 else { return }
        guard case .normal = frame.camera.trackingState else {
            guidance = "追跡が安定するまで速度を落としてください"
            return
        }
        lastTimestamp = frame.timestamp

        let transform = frame.camera.transform
        let position = SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let forwardRaw = SIMD3<Float>(-transform.columns.2.x, -transform.columns.2.y, -transform.columns.2.z)
        let forward = simd_length_squared(forwardRaw) > 1e-8 ? simd_normalize(forwardRaw) : SIMD3<Float>(0, 0, -1)

        let yaw = atan2(forward.x, -forward.z)
        let normalizedYaw = (yaw + .pi) / (2 * .pi)
        let azimuth = min(11, max(0, Int(floor(normalizedYaw * 12))))
        azimuthBins.insert(azimuth)

        let pitch = asin(min(1, max(-1, forward.y)))
        let elevation: Int
        if pitch < -0.16 { elevation = 0 }
        else if pitch > 0.16 { elevation = 2 }
        else { elevation = 1 }
        elevationBins.insert(elevation)

        if let previous = lastPosition {
            let delta = simd_distance(position, previous)
            if delta >= 0.006 && delta <= 0.35 {
                pathLengthMeters += delta
            }
        }
        lastPosition = position
        stableSamples += 1
        azimuthCoverage = azimuthBins.count
        elevationCoverage = elevationBins.count

        let requiredAzimuth = mode == .lidar ? 7.0 : 9.0
        let requiredSamples = mode == .lidar ? 18.0 : 28.0
        let requiredPath = Double(pathThreshold(size: size))
        let faceFactor = mode == .lidar ? min(1, Double(faceCount) / 6_000.0) : 1
        let photoFactor = min(1, Double(frameCount) / (mode == .lidar ? 20.0 : 32.0))
        let azimuthFactor = min(1, Double(azimuthCoverage) / requiredAzimuth)
        let elevationFactor = min(1, Double(elevationCoverage) / 2.0)
        let pathFactor = min(1, Double(pathLengthMeters) / max(0.1, requiredPath))
        let sampleFactor = min(1, Double(stableSamples) / requiredSamples)
        qualityScore = 0.26 * azimuthFactor + 0.16 * elevationFactor + 0.18 * pathFactor + 0.12 * sampleFactor + 0.14 * photoFactor + 0.14 * faceFactor

        if azimuthCoverage < Int(requiredAzimuth) {
            guidance = "同じ側に偏っています。対象の反対側まで回り込んでください"
        } else if elevationCoverage < 2 {
            guidance = "高さが単調です。少し上・下からも撮影してください"
        } else if pathLengthMeters < pathThreshold(size: size) {
            guidance = "移動量が不足しています。対象との距離を保ってもう少し回ってください"
        } else if mode == .lidar && faceCount < 6_000 {
            guidance = "形状密度が低めです。細部へ近づき、斜め方向から追加撮影してください"
        } else if frameCount < (mode == .lidar ? 20 : 32) {
            guidance = "テクスチャ用RGBが不足しています。重なりを保って追加撮影してください"
        } else {
            guidance = "品質条件を満たしました。欠けが見える部分だけ追加撮影してください"
        }
    }

    func isSufficient(mode: MeshCaptureMode, size: MeshScanSize, frameCount: Int, faceCount: Int) -> Bool {
        let azimuthOK = azimuthCoverage >= (mode == .lidar ? 7 : 9)
        let elevationOK = elevationCoverage >= 2
        let pathOK = pathLengthMeters >= pathThreshold(size: size)
        let samplesOK = stableSamples >= (mode == .lidar ? 18 : 28)
        let framesOK = frameCount >= (mode == .lidar ? 20 : 32)
        let geometryOK = mode != .lidar || faceCount >= 6_000
        return azimuthOK && elevationOK && pathOK && samplesOK && framesOK && geometryOK
    }

    var compactStatus: String {
        "周回 \(azimuthCoverage)/12・高さ \(elevationCoverage)/3・移動 \(String(format: "%.1f", pathLengthMeters))m・品質 \(Int((qualityScore * 100).rounded()))%"
    }

    private func pathThreshold(size: MeshScanSize) -> Float {
        switch size {
        case .small: return 0.55
        case .medium: return 1.0
        case .large: return 1.8
        }
    }
}
