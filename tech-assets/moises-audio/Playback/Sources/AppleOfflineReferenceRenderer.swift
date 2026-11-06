#if canImport(AVFAudio)
import AVFAudio
import Foundation

public enum Lane3AppleOfflineRendererError: Error, Equatable, Sendable {
    case invalidConfiguration
    case duplicateStemInput(String)
    case missingStemInput(String)
    case unexpectedStemInput(String)
    case clickBuffersRequired
    case invalidClickBuffers
    case outputFormatUnavailable
    case segmentFrameCountExceedsAppleAPI(stemID: String, frameCount: Int64)
    case pcmAccessUnavailable
    case manualRenderingError
    case manualRenderingNoProgress
    case renderedFrameCountMismatch(expected: Int64, actual: Int64)
}

public struct Lane3AppleOfflineStemInput: Equatable, Sendable {
    public let stemID: String
    public let fileURL: URL

    public init(stemID: String, fileURL: URL) {
        self.stemID = stemID
        self.fileURL = fileURL
    }
}

public struct Lane3AppleOfflineRendererConfiguration: Equatable, Sendable {
    public let outputChannels: Int
    public let maximumFrameCount: Int
    public let maximumNoProgressCycles: Int
    public let maximumSourceFrameCountDelta: Int64

    public init(
        outputChannels: Int = 2,
        maximumFrameCount: Int = 4_096,
        maximumNoProgressCycles: Int = 32,
        maximumSourceFrameCountDelta: Int64 = 2_048
    ) {
        self.outputChannels = outputChannels
        self.maximumFrameCount = maximumFrameCount
        self.maximumNoProgressCycles = maximumNoProgressCycles
        self.maximumSourceFrameCountDelta = maximumSourceFrameCountDelta
    }
}

public struct Lane3AppleOfflineRenderResult: Equatable, Sendable {
    public let plan: Lane3ReferenceRenderPlan
    public let executionManifest: Lane3OfflineExecutionManifest
    public let observation: Lane3ReferenceObservation
    public let pcmDigest: Lane3PCMExecutionDigest
    public let renderedFrameCount: Int64
    public let outputFileWritten: Bool
    public let eventEvidenceScope: String
    public let parityPromotionAllowed: Bool

    public init(
        plan: Lane3ReferenceRenderPlan,
        executionManifest: Lane3OfflineExecutionManifest,
        observation: Lane3ReferenceObservation,
        pcmDigest: Lane3PCMExecutionDigest,
        renderedFrameCount: Int64,
        outputFileWritten: Bool
    ) {
        self.plan = plan
        self.executionManifest = executionManifest
        self.observation = observation
        self.pcmDigest = pcmDigest
        self.renderedFrameCount = renderedFrameCount
        self.outputFileWritten = outputFileWritten
        self.eventEvidenceScope = "SCHEDULE_COMMAND_TRACE_NOT_AUDIO_ONSET_DETECTION"
        self.parityPromotionAllowed = false
    }
}

/// Real Apple offline PCM adapter for Lane 3. It uses AVAudioEngine manual rendering and the same
/// AVAudioUnitTimePitch primitive intended for production tempo/pitch. All files/click formats are
/// preflighted before graph mutation. The result is explicitly NON_PARITY until HQ runs it on the
/// selected Apple SDK with rights-cleared real fixtures and performs device/differential evidence.
public enum AppleOfflineReferenceRenderer {
    private struct OpenStem {
        let descriptor: Lane3ReferenceStemDescriptor
        let file: AVAudioFile
    }

    private struct RenderStem {
        let player: AVAudioPlayerNode
        let timePitch: AVAudioUnitTimePitch
        let mixer: AVAudioMixerNode
        let file: AVAudioFile
        let window: Lane3ReferenceStemWindow
    }

    public static func render(
        request: Lane3ReferenceRenderRequest,
        stemInputs: [Lane3AppleOfflineStemInput],
        normalClick: AVAudioPCMBuffer? = nil,
        accentClick: AVAudioPCMBuffer? = nil,
        outputFileURL: URL? = nil,
        configuration: Lane3AppleOfflineRendererConfiguration = Lane3AppleOfflineRendererConfiguration()
    ) throws -> Lane3AppleOfflineRenderResult {
        guard (1...32).contains(configuration.outputChannels),
              (1...65_536).contains(configuration.maximumFrameCount),
              configuration.maximumNoProgressCycles > 0,
              configuration.maximumSourceFrameCountDelta >= 0 else {
            throw Lane3AppleOfflineRendererError.invalidConfiguration
        }

        let plan = try Lane3OfflineReferencePlanner.makePlan(request)
        let inputByID = try indexedInputs(stemInputs, request: request)

        // Open and validate all AVAudioFiles before attaching any node to a graph.
        var openByID: [String: OpenStem] = [:]
        var metadata: [Lane3OfflineStemFileMetadata] = []
        metadata.reserveCapacity(request.stems.count)
        for descriptor in request.stems {
            guard let input = inputByID[descriptor.id] else {
                throw Lane3AppleOfflineRendererError.missingStemInput(descriptor.id)
            }
            let file = try AVAudioFile(forReading: input.fileURL)
            let format = file.processingFormat
            metadata.append(
                Lane3OfflineStemFileMetadata(
                    stemID: descriptor.id,
                    sampleRate: format.sampleRate,
                    frameCount: file.length,
                    channels: Int(format.channelCount)
                )
            )
            openByID[descriptor.id] = OpenStem(descriptor: descriptor, file: file)
        }

        let clickEvents = plan.events.filter {
            $0.kind == .countInClick || $0.kind == .metronomeClick
        }
        let clickFormat = try validateClickBuffersIfNeeded(
            clickEventsPresent: !clickEvents.isEmpty,
            normalClick: normalClick,
            accentClick: accentClick,
            outputSampleRate: plan.outputSampleRate
        )
        let manifest = try Lane3OfflineExecutionValidator.makeManifest(
            request: request,
            plan: plan,
            stemMetadata: metadata,
            clickPCMFormat: clickFormat,
            maximumFrameCountDelta: configuration.maximumSourceFrameCountDelta
        )

        guard let outputFormat = AVAudioFormat(
            standardFormatWithSampleRate: plan.outputSampleRate,
            channels: AVAudioChannelCount(configuration.outputChannels)
        ) else {
            throw Lane3AppleOfflineRendererError.outputFormatUnavailable
        }

        let engine = AVAudioEngine()
        var renderStems: [RenderStem] = []
        renderStems.reserveCapacity(plan.stemWindows.count)

        for window in plan.stemWindows {
            guard let opened = openByID[window.stemID] else {
                throw Lane3AppleOfflineRendererError.missingStemInput(window.stemID)
            }
            guard window.sourceFrameCount <= Int64(UInt32.max) else {
                throw Lane3AppleOfflineRendererError.segmentFrameCountExceedsAppleAPI(
                    stemID: window.stemID,
                    frameCount: window.sourceFrameCount
                )
            }

            let player = AVAudioPlayerNode()
            let timePitch = AVAudioUnitTimePitch()
            let mixer = AVAudioMixerNode()
            timePitch.rate = Float(request.practice.tempoRatio)
            timePitch.pitch = Float(request.practice.pitchSemitones * 100)
            mixer.outputVolume = Float(window.gain)

            engine.attach(player)
            engine.attach(timePitch)
            engine.attach(mixer)
            engine.connect(player, to: timePitch, format: opened.file.processingFormat)
            engine.connect(timePitch, to: mixer, format: nil)
            engine.connect(mixer, to: engine.mainMixerNode, format: nil)
            renderStems.append(
                RenderStem(
                    player: player,
                    timePitch: timePitch,
                    mixer: mixer,
                    file: opened.file,
                    window: window
                )
            )
        }

        let clickPlayer: AVAudioPlayerNode?
        if !clickEvents.isEmpty {
            guard let normalClick else {
                throw Lane3AppleOfflineRendererError.clickBuffersRequired
            }
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: normalClick.format)
            clickPlayer = player
        } else {
            clickPlayer = nil
        }

        try engine.enableManualRenderingMode(
            .offline,
            format: outputFormat,
            maximumFrameCount: AVAudioFrameCount(configuration.maximumFrameCount)
        )
        defer {
            engine.stop()
            engine.disableManualRenderingMode()
        }

        let outputFile = try outputFileURL.map {
            try AVAudioFile(forWriting: $0, settings: outputFormat.settings)
        }
        guard let renderBuffer = AVAudioPCMBuffer(
            pcmFormat: engine.manualRenderingFormat,
            frameCapacity: engine.manualRenderingMaximumFrameCount
        ) else {
            throw Lane3AppleOfflineRendererError.outputFormatUnavailable
        }

        engine.prepare()
        try engine.start()

        for item in renderStems {
            item.player.scheduleSegment(
                item.file,
                startingFrame: AVAudioFramePosition(item.window.sourceStartFrame),
                frameCount: AVAudioFrameCount(item.window.sourceFrameCount),
                at: AVAudioTime(
                    sampleTime: AVAudioFramePosition(item.window.renderStartFrame),
                    atRate: plan.outputSampleRate
                ),
                completionHandler: nil
            )
            item.player.play()
        }

        if let clickPlayer, let normalClick, let accentClick {
            for event in clickEvents {
                let buffer = event.accent == true ? accentClick : normalClick
                clickPlayer.scheduleBuffer(
                    buffer,
                    at: AVAudioTime(
                        sampleTime: AVAudioFramePosition(event.frame),
                        atRate: plan.outputSampleRate
                    ),
                    options: [],
                    completionHandler: nil
                )
            }
            clickPlayer.play()
        }

        var accumulator = try Lane3StreamingPCMAccumulator(
            channels: configuration.outputChannels,
            sampleRate: plan.outputSampleRate
        )
        var noProgressCycles = 0

        while engine.manualRenderingSampleTime < AVAudioFramePosition(plan.outputFrameCount) {
            let remaining = plan.outputFrameCount - Int64(engine.manualRenderingSampleTime)
            let requested = AVAudioFrameCount(
                min(Int64(engine.manualRenderingMaximumFrameCount), remaining)
            )
            let before = engine.manualRenderingSampleTime
            let status = try engine.renderOffline(requested, to: renderBuffer)

            switch status {
            case .success:
                noProgressCycles = 0
                try accumulator.consume(
                    interleavedSamples: try interleavedFloatSamples(renderBuffer)
                )
                if let outputFile {
                    try outputFile.write(from: renderBuffer)
                }

            case .insufficientDataFromInputNode, .cannotDoInCurrentContext:
                if engine.manualRenderingSampleTime == before {
                    noProgressCycles += 1
                    guard noProgressCycles <= configuration.maximumNoProgressCycles else {
                        throw Lane3AppleOfflineRendererError.manualRenderingNoProgress
                    }
                } else {
                    noProgressCycles = 0
                }

            case .error:
                throw Lane3AppleOfflineRendererError.manualRenderingError

            @unknown default:
                throw Lane3AppleOfflineRendererError.manualRenderingError
            }
        }

        let renderedFrames = accumulator.summary().frameCount
        guard renderedFrames == plan.outputFrameCount else {
            throw Lane3AppleOfflineRendererError.renderedFrameCountMismatch(
                expected: plan.outputFrameCount,
                actual: renderedFrames
            )
        }
        let summary = accumulator.summary()
        let digest = accumulator.digest()
        let observation = Lane3ReferenceObservation(
            fixtureID: plan.fixtureID,
            controlSignatureFNV1A64: plan.controlSignatureFNV1A64,
            outputFrameCount: renderedFrames,
            events: plan.events.filter { $0.kind != .practiceState }.map {
                Lane3ObservedRenderEvent(kind: $0.kind, frame: $0.frame, stemID: $0.stemID)
            },
            audioSummary: summary,
            actualAudioCaptured: true
        )
        return Lane3AppleOfflineRenderResult(
            plan: plan,
            executionManifest: manifest,
            observation: observation,
            pcmDigest: digest,
            renderedFrameCount: renderedFrames,
            outputFileWritten: outputFile != nil
        )
    }

    private static func indexedInputs(
        _ inputs: [Lane3AppleOfflineStemInput],
        request: Lane3ReferenceRenderRequest
    ) throws -> [String: Lane3AppleOfflineStemInput] {
        let expected = Set(request.stems.map(\.id))
        var result: [String: Lane3AppleOfflineStemInput] = [:]
        result.reserveCapacity(inputs.count)
        for input in inputs {
            guard result.updateValue(input, forKey: input.stemID) == nil else {
                throw Lane3AppleOfflineRendererError.duplicateStemInput(input.stemID)
            }
            guard expected.contains(input.stemID) else {
                throw Lane3AppleOfflineRendererError.unexpectedStemInput(input.stemID)
            }
        }
        for descriptor in request.stems where result[descriptor.id] == nil {
            throw Lane3AppleOfflineRendererError.missingStemInput(descriptor.id)
        }
        return result
    }

    private static func validateClickBuffersIfNeeded(
        clickEventsPresent: Bool,
        normalClick: AVAudioPCMBuffer?,
        accentClick: AVAudioPCMBuffer?,
        outputSampleRate: Double
    ) throws -> Lane3OfflinePCMFormatDescriptor? {
        guard clickEventsPresent else { return nil }
        guard let normalClick, let accentClick else {
            throw Lane3AppleOfflineRendererError.clickBuffersRequired
        }
        let normal = normalClick.format
        let accent = accentClick.format
        guard normalClick.frameLength > 0,
              accentClick.frameLength > 0,
              normal.sampleRate.isFinite,
              accent.sampleRate.isFinite,
              abs(normal.sampleRate - outputSampleRate) <= 0.5,
              abs(accent.sampleRate - outputSampleRate) <= 0.5,
              normal.channelCount > 0,
              normal.channelCount == accent.channelCount,
              normal.commonFormat == accent.commonFormat,
              normal.isInterleaved == accent.isInterleaved else {
            throw Lane3AppleOfflineRendererError.invalidClickBuffers
        }
        return Lane3OfflinePCMFormatDescriptor(
            sampleRate: normal.sampleRate,
            channels: Int(normal.channelCount)
        )
    }

    private static func interleavedFloatSamples(
        _ buffer: AVAudioPCMBuffer
    ) throws -> [Float] {
        guard buffer.format.commonFormat == .pcmFormatFloat32,
              !buffer.format.isInterleaved,
              let channelData = buffer.floatChannelData else {
            throw Lane3AppleOfflineRendererError.pcmAccessUnavailable
        }
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        var result = [Float](repeating: 0, count: channels * frames)
        for frame in 0..<frames {
            for channel in 0..<channels {
                result[frame * channels + channel] = channelData[channel][frame]
            }
        }
        return result
    }
}
#endif
