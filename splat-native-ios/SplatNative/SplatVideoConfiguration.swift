import Foundation

struct SplatVideoConfiguration: Equatable, Sendable {
    enum AspectRatio: String, CaseIterable, Identifiable, Sendable {
        case portrait9x16
        case square1x1
        case landscape16x9

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .portrait9x16: return "縦 9:16"
            case .square1x1: return "正方形 1:1"
            case .landscape16x9: return "横 16:9"
            }
        }

        var dimensions: (width: Int, height: Int) {
            switch self {
            case .portrait9x16: return (720, 1280)
            case .square1x1: return (720, 720)
            case .landscape16x9: return (1280, 720)
            }
        }
    }

    enum CameraMotion: String, CaseIterable, Identifiable, Sendable {
        case orbit360
        case orbit180
        case pushIn
        case fixed

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .orbit360: return "1周する"
            case .orbit180: return "半周する"
            case .pushIn: return "近づく"
            case .fixed: return "固定"
            }
        }
    }

    enum Speed: String, CaseIterable, Identifiable, Sendable {
        case slow
        case normal
        case fast

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .slow: return "ゆっくり"
            case .normal: return "標準"
            case .fast: return "速い"
            }
        }

        var duration: TimeInterval {
            switch self {
            case .slow: return 12
            case .normal: return 8
            case .fast: return 4
            }
        }
    }

    struct CameraSample: Equatable, Sendable {
        let yaw: Float
        let pitch: Float
        let distanceMultiplier: Float
    }

    var aspectRatio: AspectRatio = .portrait9x16
    var cameraMotion: CameraMotion = .orbit360
    var speed: Speed = .normal
    var framesPerSecond: Int = 30

    var dimensions: (width: Int, height: Int) { aspectRatio.dimensions }
    var duration: TimeInterval { speed.duration }
    var totalFrames: Int { max(1, Int((duration * Double(framesPerSecond)).rounded())) }

    func cameraSample(progress rawProgress: Double) -> CameraSample {
        let progress = Float(max(0, min(1, rawProgress)))
        switch cameraMotion {
        case .orbit360:
            // The encoder samples progress inclusively from 0...1. Mapping 1.0 to 2π would
            // duplicate the first frame at the end of every turntable movie, creating a tiny
            // visible dwell at the loop seam. Keep N unique angular samples with a constant
            // 2π/N step so the last->first transition is the same size as every other step.
            let frameCount = max(1, totalFrames)
            let loopProgress = progress * Float(max(0, frameCount - 1)) / Float(frameCount)
            return CameraSample(
                yaw: loopProgress * 2 * .pi,
                pitch: sin(loopProgress * 2 * .pi) * 0.06,
                distanceMultiplier: 1
            )
        case .orbit180:
            // Finite camera moves should settle gently at both ends instead of
            // starting and stopping with an instantaneous angular velocity change.
            let eased = smoothstep(progress)
            return CameraSample(
                yaw: -.pi / 2 + eased * .pi,
                pitch: sin(eased * .pi) * 0.05,
                distanceMultiplier: 1
            )
        case .pushIn:
            // Ease the dolly move so exported videos do not visibly snap into or
            // out of motion on their first and final frames.
            let eased = smoothstep(progress)
            return CameraSample(
                yaw: 0,
                pitch: 0,
                distanceMultiplier: 1.25 - eased * 0.45
            )
        case .fixed:
            return CameraSample(yaw: 0, pitch: 0, distanceMultiplier: 1)
        }
    }

    private func smoothstep(_ value: Float) -> Float {
        value * value * (3 - 2 * value)
    }
}