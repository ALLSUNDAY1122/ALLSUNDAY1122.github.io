#if canImport(AVFAudio)
import AVFAudio
import Foundation

public enum ApplePracticeDSPBackendError: Error, Equatable, Sendable {
    case invalidTempoRatio(Double)
    case invalidPitchSemitones(Double)
    case invalidSampleRate(Double)
    case staleSchedule(expectedGeneration: UInt64, eventGeneration: UInt64)
}

/// Replaceable Apple baseline node. Playback owns the AVAudioEngine/transport and inserts this node
/// in its graph; DSP owns only time/pitch configuration.
public final class AppleTimePitchBackend: @unchecked Sendable {
    public let node: AVAudioUnitTimePitch
    public let capabilities: PracticeDSPCapabilities

    public init(
        node: AVAudioUnitTimePitch = AVAudioUnitTimePitch(),
        capabilities: PracticeDSPCapabilities = .appleTimePitchBaseline,
        overlap: Float = 8.0
    ) {
        self.node = node
        self.capabilities = capabilities
        self.node.overlap = overlap
    }

    public func apply(tempoRatio: Double, pitchSemitones: Double) throws {
        guard tempoRatio.isFinite, capabilities.tempoRatioRange.contains(tempoRatio) else {
            throw ApplePracticeDSPBackendError.invalidTempoRatio(tempoRatio)
        }
        guard pitchSemitones.isFinite, capabilities.pitchSemitoneRange.contains(pitchSemitones) else {
            throw ApplePracticeDSPBackendError.invalidPitchSemitones(pitchSemitones)
        }
        node.rate = Float(tempoRatio)
        node.pitch = Float(PracticeDSPMath.cents(forSemitones: pitchSemitones))
    }
}

/// Schedules project-owned/rights-cleared click buffers on a player node using absolute sample time.
/// It intentionally does not start/stop the engine or own transport state.
public final class AppleSampleTimeClickScheduler: @unchecked Sendable {
    private let playerNode: AVAudioPlayerNode

    public init(playerNode: AVAudioPlayerNode) {
        self.playerNode = playerNode
    }

    public func schedule(
        events: [DSPClickEvent],
        normalClick: AVAudioPCMBuffer,
        accentClick: AVAudioPCMBuffer,
        sampleRate: Double,
        activeGeneration: UInt64
    ) throws {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw ApplePracticeDSPBackendError.invalidSampleRate(sampleRate)
        }
        for event in events {
            guard event.generation == activeGeneration else {
                throw ApplePracticeDSPBackendError.staleSchedule(
                    expectedGeneration: activeGeneration,
                    eventGeneration: event.generation
                )
            }
            let buffer = event.accent ? accentClick : normalClick
            let at = AVAudioTime(sampleTime: event.sampleTime, atRate: sampleRate)
            playerNode.scheduleBuffer(buffer, at: at, options: [], completionHandler: nil)
        }
    }
}

/// Real-track offline renderer used for deterministic macOS/iOS benchmark runs.
/// Output is uncompressed PCM; quality analysis is performed on the rendered artifact.
public final class AppleOfflineTimePitchRenderer: @unchecked Sendable {
    public init() {}

    public func render(
        inputURL: URL,
        outputURL: URL,
        tempoRatio: Double,
        pitchSemitones: Double,
        maximumFrameCount: AVAudioFrameCount = 4096
    ) throws {
        let input = try AVAudioFile(forReading: inputURL)
        let inputFormat = input.processingFormat

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let backend = AppleTimePitchBackend()
        try backend.apply(tempoRatio: tempoRatio, pitchSemitones: pitchSemitones)

        engine.attach(player)
        engine.attach(backend.node)
        engine.connect(player, to: backend.node, format: inputFormat)
        engine.connect(backend.node, to: engine.mainMixerNode, format: inputFormat)

        try engine.enableManualRenderingMode(
            .offline,
            format: inputFormat,
            maximumFrameCount: maximumFrameCount
        )

        let output = try AVAudioFile(
            forWriting: outputURL,
            settings: inputFormat.settings,
            commonFormat: inputFormat.commonFormat,
            interleaved: inputFormat.isInterleaved
        )
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        var sourceCompleted = false
        player.scheduleFile(input, at: nil) {
            sourceCompleted = true
        }
        try engine.start()
        player.play()

        // TimePitch may emit a short algorithmic tail. Drain bounded extra buffers after source completion.
        var completedDrainBuffers = 0
        let maxDrainBuffers = 8
        while !sourceCompleted || completedDrainBuffers < maxDrainBuffers {
            let frames = engine.manualRenderingMaximumFrameCount
            let status = try engine.renderOffline(frames, to: buffer)
            switch status {
            case .success:
                if buffer.frameLength > 0 {
                    try output.write(from: buffer)
                }
                if sourceCompleted { completedDrainBuffers += 1 }
            case .insufficientDataFromInputNode:
                if sourceCompleted { completedDrainBuffers += 1 }
            case .cannotDoInCurrentContext:
                continue
            case .error:
                throw CocoaError(.fileWriteUnknown)
            @unknown default:
                throw CocoaError(.fileWriteUnknown)
            }
        }

        player.stop()
        engine.stop()
        engine.disableManualRenderingMode()
    }
}
#endif
