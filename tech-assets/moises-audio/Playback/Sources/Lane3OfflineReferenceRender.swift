import Foundation

public enum Lane3OfflineRenderError: Error, Equatable, Sendable {
    case invalidOutputSampleRate(Double)
    case noStems
    case invalidProjectRange(start: Double, end: Double)
    case invalidTempoRatio(Double)
    case invalidPitchSemitones(Double)
    case invalidCountInClicks(Int)
    case missingCountInBeatInterval
    case invalidCountInBeatInterval(Double)
    case invalidDownbeatStride(Int)
    case duplicateStemID(String)
    case invalidStem(String)
    case invalidGain(stemID: String, gain: Double)
    case invalidBeatTime(Double)
    case nonMonotonicBeatGrid
    case duplicateRenderClickFrame(Int64)
    case invalidPCMConfiguration
    case timelineOverflow
}

public struct Lane3ReferenceStemDescriptor: Equatable, Codable, Sendable {
    public let id: String
    public let startSeconds: Double
    public let frameCount: Int64
    public let sampleRate: Double
    public let gain: Double

    public init(id: String, startSeconds: Double, frameCount: Int64, sampleRate: Double, gain: Double) {
        self.id = id
        self.startSeconds = startSeconds
        self.frameCount = frameCount
        self.sampleRate = sampleRate
        self.gain = gain
    }

    public var durationSeconds: Double { Double(frameCount) / sampleRate }
}

public struct Lane3ReferencePracticeSettings: Equatable, Codable, Sendable {
    public let tempoRatio: Double
    public let pitchSemitones: Double
    public let metronomeEnabled: Bool
    public let countInClicks: Int?
    public let downbeatStride: Int

    public init(
        tempoRatio: Double = 1,
        pitchSemitones: Double = 0,
        metronomeEnabled: Bool = false,
        countInClicks: Int? = nil,
        downbeatStride: Int = 4
    ) {
        self.tempoRatio = tempoRatio
        self.pitchSemitones = pitchSemitones
        self.metronomeEnabled = metronomeEnabled
        self.countInClicks = countInClicks
        self.downbeatStride = downbeatStride
    }
}

public struct Lane3ReferenceRenderRequest: Equatable, Codable, Sendable {
    public let fixtureID: String
    public let stems: [Lane3ReferenceStemDescriptor]
    public let projectStartSeconds: Double
    public let projectEndSeconds: Double
    public let outputSampleRate: Double
    public let practice: Lane3ReferencePracticeSettings
    public let beatTimesSeconds: [Double]
    public let countInBeatIntervalSeconds: Double?

    public init(
        fixtureID: String,
        stems: [Lane3ReferenceStemDescriptor],
        projectStartSeconds: Double,
        projectEndSeconds: Double,
        outputSampleRate: Double,
        practice: Lane3ReferencePracticeSettings,
        beatTimesSeconds: [Double] = [],
        countInBeatIntervalSeconds: Double? = nil
    ) {
        self.fixtureID = fixtureID
        self.stems = stems
        self.projectStartSeconds = projectStartSeconds
        self.projectEndSeconds = projectEndSeconds
        self.outputSampleRate = outputSampleRate
        self.practice = practice
        self.beatTimesSeconds = beatTimesSeconds
        self.countInBeatIntervalSeconds = countInBeatIntervalSeconds
    }
}

public struct Lane3ReferenceStemWindow: Equatable, Codable, Sendable {
    public let stemID: String
    public let sourceStartFrame: Int64
    public let sourceFrameCount: Int64
    public let renderStartFrame: Int64
    public let renderFrameCount: Int64
    public let gain: Double
}

public enum Lane3ReferenceRenderEventKind: String, Codable, Sendable, CaseIterable {
    case countInClick
    case practiceState
    case musicStart
    case stemStart
    case metronomeClick
    case stemEnd
    case musicEnd
}

public struct Lane3ReferenceRenderEvent: Equatable, Codable, Sendable {
    public let kind: Lane3ReferenceRenderEventKind
    public let frame: Int64
    public let stemID: String?
    public let accent: Bool?
    public let detail: String?

    public init(
        kind: Lane3ReferenceRenderEventKind,
        frame: Int64,
        stemID: String? = nil,
        accent: Bool? = nil,
        detail: String? = nil
    ) {
        self.kind = kind
        self.frame = frame
        self.stemID = stemID
        self.accent = accent
        self.detail = detail
    }
}

public struct Lane3ReferenceRenderPlan: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fixtureID: String
    public let outputSampleRate: Double
    public let projectStartSeconds: Double
    public let projectEndSeconds: Double
    public let musicStartFrame: Int64
    public let outputFrameCount: Int64
    public let practice: Lane3ReferencePracticeSettings
    public let stemWindows: [Lane3ReferenceStemWindow]
    public let events: [Lane3ReferenceRenderEvent]
    public let controlSignatureFNV1A64: String

    public init(
        fixtureID: String,
        outputSampleRate: Double,
        projectStartSeconds: Double,
        projectEndSeconds: Double,
        musicStartFrame: Int64,
        outputFrameCount: Int64,
        practice: Lane3ReferencePracticeSettings,
        stemWindows: [Lane3ReferenceStemWindow],
        events: [Lane3ReferenceRenderEvent],
        controlSignatureFNV1A64: String
    ) {
        self.schemaVersion = 1
        self.evidenceScope = "LANE3_OFFLINE_CONTROL_REFERENCE_NON_PARITY"
        self.fixtureID = fixtureID
        self.outputSampleRate = outputSampleRate
        self.projectStartSeconds = projectStartSeconds
        self.projectEndSeconds = projectEndSeconds
        self.musicStartFrame = musicStartFrame
        self.outputFrameCount = outputFrameCount
        self.practice = practice
        self.stemWindows = stemWindows
        self.events = events
        self.controlSignatureFNV1A64 = controlSignatureFNV1A64
    }
}

public enum Lane3OfflineReferencePlanner {
    public static func makePlan(_ request: Lane3ReferenceRenderRequest) throws -> Lane3ReferenceRenderPlan {
        try validate(request)

        let beatFrames = try countInBeatFrames(request)
        let countInClicks = request.practice.countInClicks ?? 0
        let (musicStartFrame, countInOverflow) = beatFrames.multipliedReportingOverflow(by: Int64(countInClicks))
        guard !countInOverflow else { throw Lane3OfflineRenderError.timelineOverflow }

        let musicFrames = try mappedFrame(
            sourceTimeSeconds: request.projectEndSeconds,
            sourceOriginSeconds: request.projectStartSeconds,
            renderOriginFrame: 0,
            tempoRatio: request.practice.tempoRatio,
            sampleRate: request.outputSampleRate
        )
        guard musicFrames >= 0 else { throw Lane3OfflineRenderError.timelineOverflow }
        let (outputFrameCount, outputOverflow) = musicStartFrame.addingReportingOverflow(musicFrames)
        guard !outputOverflow else { throw Lane3OfflineRenderError.timelineOverflow }

        let windows = try request.stems.compactMap { stem -> Lane3ReferenceStemWindow? in
            let stemEnd = stem.startSeconds + stem.durationSeconds
            guard stemEnd.isFinite else { throw Lane3OfflineRenderError.timelineOverflow }
            let intersectionStart = max(stem.startSeconds, request.projectStartSeconds)
            let intersectionEnd = min(stemEnd, request.projectEndSeconds)
            guard intersectionEnd > intersectionStart else { return nil }

            let sourceStartDouble = ((intersectionStart - stem.startSeconds) * stem.sampleRate).rounded(.down)
            let sourceEndDouble = ((intersectionEnd - stem.startSeconds) * stem.sampleRate).rounded(.up)
            guard sourceStartDouble.isFinite, sourceEndDouble.isFinite,
                  sourceStartDouble >= 0, sourceEndDouble >= sourceStartDouble,
                  sourceEndDouble <= Double(Int64.max) else {
                throw Lane3OfflineRenderError.timelineOverflow
            }
            let sourceStart = min(Int64(sourceStartDouble), stem.frameCount)
            let sourceEnd = min(Int64(sourceEndDouble), stem.frameCount)

            let renderStartRelative = try mappedFrame(
                sourceTimeSeconds: intersectionStart,
                sourceOriginSeconds: request.projectStartSeconds,
                renderOriginFrame: 0,
                tempoRatio: request.practice.tempoRatio,
                sampleRate: request.outputSampleRate
            )
            let renderEndRelative = try mappedFrame(
                sourceTimeSeconds: intersectionEnd,
                sourceOriginSeconds: request.projectStartSeconds,
                renderOriginFrame: 0,
                tempoRatio: request.practice.tempoRatio,
                sampleRate: request.outputSampleRate
            )
            let (renderStart, startOverflow) = musicStartFrame.addingReportingOverflow(renderStartRelative)
            guard !startOverflow, renderEndRelative >= renderStartRelative else {
                throw Lane3OfflineRenderError.timelineOverflow
            }
            return Lane3ReferenceStemWindow(
                stemID: stem.id,
                sourceStartFrame: sourceStart,
                sourceFrameCount: sourceEnd - sourceStart,
                renderStartFrame: renderStart,
                renderFrameCount: renderEndRelative - renderStartRelative,
                gain: stem.gain
            )
        }.sorted { lhs, rhs in
            if lhs.renderStartFrame == rhs.renderStartFrame { return lhs.stemID < rhs.stemID }
            return lhs.renderStartFrame < rhs.renderStartFrame
        }

        var events: [Lane3ReferenceRenderEvent] = []
        events.append(Lane3ReferenceRenderEvent(
            kind: .practiceState,
            frame: 0,
            detail: "tempo=\(request.practice.tempoRatio.bitPattern);pitch=\(request.practice.pitchSemitones.bitPattern)"
        ))

        if countInClicks > 0 {
            for index in 0..<countInClicks {
                let (offset, overflow) = beatFrames.multipliedReportingOverflow(by: Int64(index))
                guard !overflow else { throw Lane3OfflineRenderError.timelineOverflow }
                events.append(Lane3ReferenceRenderEvent(
                    kind: .countInClick,
                    frame: offset,
                    accent: index % request.practice.downbeatStride == 0,
                    detail: "index=\(index)"
                ))
            }
        }

        events.append(Lane3ReferenceRenderEvent(kind: .musicStart, frame: musicStartFrame))
        for window in windows {
            events.append(Lane3ReferenceRenderEvent(kind: .stemStart, frame: window.renderStartFrame, stemID: window.stemID, detail: "gainBits=\(window.gain.bitPattern)"))
            let (end, overflow) = window.renderStartFrame.addingReportingOverflow(window.renderFrameCount)
            guard !overflow else { throw Lane3OfflineRenderError.timelineOverflow }
            events.append(Lane3ReferenceRenderEvent(kind: .stemEnd, frame: end, stemID: window.stemID))
        }

        if request.practice.metronomeEnabled {
            var usedClickFrames = Set<Int64>()
            for (index, beat) in request.beatTimesSeconds.enumerated() {
                guard beat >= request.projectStartSeconds else { continue }
                guard beat <= request.projectEndSeconds else { break }
                let relative = try mappedFrame(
                    sourceTimeSeconds: beat,
                    sourceOriginSeconds: request.projectStartSeconds,
                    renderOriginFrame: 0,
                    tempoRatio: request.practice.tempoRatio,
                    sampleRate: request.outputSampleRate
                )
                let (frame, overflow) = musicStartFrame.addingReportingOverflow(relative)
                guard !overflow else { throw Lane3OfflineRenderError.timelineOverflow }
                guard usedClickFrames.insert(frame).inserted else {
                    throw Lane3OfflineRenderError.duplicateRenderClickFrame(frame)
                }
                events.append(Lane3ReferenceRenderEvent(
                    kind: .metronomeClick,
                    frame: frame,
                    accent: index % request.practice.downbeatStride == 0,
                    detail: "beatIndex=\(index)"
                ))
            }
        }
        events.append(Lane3ReferenceRenderEvent(kind: .musicEnd, frame: outputFrameCount))
        events.sort(by: eventLessThan)

        let unsigned = Lane3ReferenceRenderPlan(
            fixtureID: request.fixtureID,
            outputSampleRate: request.outputSampleRate,
            projectStartSeconds: request.projectStartSeconds,
            projectEndSeconds: request.projectEndSeconds,
            musicStartFrame: musicStartFrame,
            outputFrameCount: outputFrameCount,
            practice: request.practice,
            stemWindows: windows,
            events: events,
            controlSignatureFNV1A64: "pending"
        )
        let signature = stableSignature(unsigned)
        return Lane3ReferenceRenderPlan(
            fixtureID: unsigned.fixtureID,
            outputSampleRate: unsigned.outputSampleRate,
            projectStartSeconds: unsigned.projectStartSeconds,
            projectEndSeconds: unsigned.projectEndSeconds,
            musicStartFrame: unsigned.musicStartFrame,
            outputFrameCount: unsigned.outputFrameCount,
            practice: unsigned.practice,
            stemWindows: unsigned.stemWindows,
            events: unsigned.events,
            controlSignatureFNV1A64: signature
        )
    }

    private static func validate(_ request: Lane3ReferenceRenderRequest) throws {
        guard !request.stems.isEmpty else { throw Lane3OfflineRenderError.noStems }
        guard request.outputSampleRate.isFinite, request.outputSampleRate > 0,
              request.outputSampleRate <= 768_000 else {
            throw Lane3OfflineRenderError.invalidOutputSampleRate(request.outputSampleRate)
        }
        guard request.projectStartSeconds.isFinite, request.projectEndSeconds.isFinite,
              request.projectStartSeconds >= 0, request.projectEndSeconds > request.projectStartSeconds else {
            throw Lane3OfflineRenderError.invalidProjectRange(start: request.projectStartSeconds, end: request.projectEndSeconds)
        }
        guard request.practice.tempoRatio.isFinite,
              (0.03125...32.0).contains(request.practice.tempoRatio) else {
            throw Lane3OfflineRenderError.invalidTempoRatio(request.practice.tempoRatio)
        }
        guard request.practice.pitchSemitones.isFinite,
              (-24...24).contains(request.practice.pitchSemitones) else {
            throw Lane3OfflineRenderError.invalidPitchSemitones(request.practice.pitchSemitones)
        }
        guard request.practice.downbeatStride > 0 else {
            throw Lane3OfflineRenderError.invalidDownbeatStride(request.practice.downbeatStride)
        }
        if let clicks = request.practice.countInClicks {
            guard (1...32).contains(clicks) else { throw Lane3OfflineRenderError.invalidCountInClicks(clicks) }
            guard let interval = request.countInBeatIntervalSeconds else { throw Lane3OfflineRenderError.missingCountInBeatInterval }
            guard interval.isFinite, interval > 0 else { throw Lane3OfflineRenderError.invalidCountInBeatInterval(interval) }
        }

        var stemIDs = Set<String>()
        for stem in request.stems {
            guard !stem.id.isEmpty, stemIDs.insert(stem.id).inserted else {
                if stem.id.isEmpty { throw Lane3OfflineRenderError.invalidStem(stem.id) }
                throw Lane3OfflineRenderError.duplicateStemID(stem.id)
            }
            guard stem.startSeconds.isFinite, stem.startSeconds >= 0,
                  stem.frameCount > 0,
                  stem.sampleRate.isFinite, stem.sampleRate > 0 else {
                throw Lane3OfflineRenderError.invalidStem(stem.id)
            }
            guard stem.gain.isFinite, (0...1).contains(stem.gain) else {
                throw Lane3OfflineRenderError.invalidGain(stemID: stem.id, gain: stem.gain)
            }
            guard stem.durationSeconds.isFinite else { throw Lane3OfflineRenderError.timelineOverflow }
        }

        var previous = -Double.infinity
        for beat in request.beatTimesSeconds {
            guard beat.isFinite else { throw Lane3OfflineRenderError.invalidBeatTime(beat) }
            guard beat > previous else { throw Lane3OfflineRenderError.nonMonotonicBeatGrid }
            previous = beat
        }
    }

    private static func countInBeatFrames(_ request: Lane3ReferenceRenderRequest) throws -> Int64 {
        guard request.practice.countInClicks != nil else { return 0 }
        guard let interval = request.countInBeatIntervalSeconds else { throw Lane3OfflineRenderError.missingCountInBeatInterval }
        let frames = (interval / request.practice.tempoRatio * request.outputSampleRate).rounded()
        guard frames.isFinite, frames >= 1, frames <= Double(Int64.max) else {
            throw Lane3OfflineRenderError.timelineOverflow
        }
        return Int64(frames)
    }

    private static func mappedFrame(
        sourceTimeSeconds: Double,
        sourceOriginSeconds: Double,
        renderOriginFrame: Int64,
        tempoRatio: Double,
        sampleRate: Double
    ) throws -> Int64 {
        let seconds = (sourceTimeSeconds - sourceOriginSeconds) / tempoRatio
        let frameDouble = (seconds * sampleRate).rounded()
        guard frameDouble.isFinite,
              frameDouble >= Double(Int64.min), frameDouble <= Double(Int64.max) else {
            throw Lane3OfflineRenderError.timelineOverflow
        }
        let (result, overflow) = renderOriginFrame.addingReportingOverflow(Int64(frameDouble))
        guard !overflow else { throw Lane3OfflineRenderError.timelineOverflow }
        return result
    }

    private static func eventLessThan(_ lhs: Lane3ReferenceRenderEvent, _ rhs: Lane3ReferenceRenderEvent) -> Bool {
        if lhs.frame != rhs.frame { return lhs.frame < rhs.frame }
        let lhsOrder = eventOrder(lhs.kind)
        let rhsOrder = eventOrder(rhs.kind)
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
        if lhs.stemID != rhs.stemID { return (lhs.stemID ?? "") < (rhs.stemID ?? "") }
        return (lhs.detail ?? "") < (rhs.detail ?? "")
    }

    private static func eventOrder(_ kind: Lane3ReferenceRenderEventKind) -> Int {
        switch kind {
        case .practiceState: return 0
        case .countInClick: return 1
        case .musicStart: return 2
        case .stemStart: return 3
        case .metronomeClick: return 4
        case .stemEnd: return 5
        case .musicEnd: return 6
        }
    }

    private static func stableSignature(_ plan: Lane3ReferenceRenderPlan) -> String {
        var canonical = "v1|scope:\(plan.evidenceScope)|fixture:\(lengthPrefixed(plan.fixtureID))"
        canonical += "|sr:\(plan.outputSampleRate.bitPattern)|ps:\(plan.projectStartSeconds.bitPattern)|pe:\(plan.projectEndSeconds.bitPattern)"
        canonical += "|ms:\(plan.musicStartFrame)|of:\(plan.outputFrameCount)"
        canonical += "|tempo:\(plan.practice.tempoRatio.bitPattern)|pitch:\(plan.practice.pitchSemitones.bitPattern)|metro:\(plan.practice.metronomeEnabled ? 1 : 0)|count:\(plan.practice.countInClicks ?? -1)|stride:\(plan.practice.downbeatStride)"
        for window in plan.stemWindows {
            canonical += "|w:\(lengthPrefixed(window.stemID)),\(window.sourceStartFrame),\(window.sourceFrameCount),\(window.renderStartFrame),\(window.renderFrameCount),\(window.gain.bitPattern)"
        }
        for event in plan.events {
            canonical += "|e:\(event.kind.rawValue),\(event.frame),\(lengthPrefixed(event.stemID ?? "")),\(event.accent.map { $0 ? 1 : 0 } ?? -1),\(lengthPrefixed(event.detail ?? ""))"
        }
        return fnv1a64(canonical.utf8)
    }

    private static func lengthPrefixed(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static func fnv1a64<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return String(format: "%016llx", hash)
    }
}

public enum Lane3ReferenceEvidenceEncoder {
    public static func encodePlanJSON(_ plan: Lane3ReferenceRenderPlan) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(plan)
    }

    public static func observationTemplate(for plan: Lane3ReferenceRenderPlan) -> Lane3ReferenceObservation {
        Lane3ReferenceObservation(
            fixtureID: plan.fixtureID,
            controlSignatureFNV1A64: plan.controlSignatureFNV1A64,
            outputFrameCount: plan.outputFrameCount,
            events: plan.events.filter { $0.kind != .practiceState }.map {
                Lane3ObservedRenderEvent(kind: $0.kind, frame: $0.frame, stemID: $0.stemID)
            },
            audioSummary: nil,
            actualAudioCaptured: false
        )
    }
}

public struct Lane3AudioSummary: Equatable, Codable, Sendable {
    public let sampleRate: Double
    public let channels: Int
    public let frameCount: Int64
    public let peakAbsolute: Double
    public let rms: Double
    public let dcOffset: Double
    public let nonFiniteSampleCount: Int64
}

public enum Lane3PCMAnalyzer {
    public static func summarize(
        interleavedSamples: [Float],
        channels: Int,
        sampleRate: Double
    ) throws -> Lane3AudioSummary {
        guard channels > 0, sampleRate.isFinite, sampleRate > 0,
              interleavedSamples.count % channels == 0 else {
            throw Lane3OfflineRenderError.invalidPCMConfiguration
        }
        var peak = 0.0
        var sumSquares = 0.0
        var sum = 0.0
        var finiteCount: Int64 = 0
        var nonFiniteCount: Int64 = 0
        for sample in interleavedSamples {
            let value = Double(sample)
            if value.isFinite {
                peak = max(peak, abs(value))
                sumSquares += value * value
                sum += value
                finiteCount += 1
            } else {
                nonFiniteCount += 1
            }
        }
        let rms = finiteCount > 0 ? sqrt(sumSquares / Double(finiteCount)) : 0
        let dc = finiteCount > 0 ? sum / Double(finiteCount) : 0
        return Lane3AudioSummary(
            sampleRate: sampleRate,
            channels: channels,
            frameCount: Int64(interleavedSamples.count / channels),
            peakAbsolute: peak,
            rms: rms,
            dcOffset: dc,
            nonFiniteSampleCount: nonFiniteCount
        )
    }
}

public struct Lane3ObservedRenderEvent: Equatable, Codable, Sendable {
    public let kind: Lane3ReferenceRenderEventKind
    public let frame: Int64
    public let stemID: String?

    public init(kind: Lane3ReferenceRenderEventKind, frame: Int64, stemID: String? = nil) {
        self.kind = kind
        self.frame = frame
        self.stemID = stemID
    }
}

public struct Lane3ReferenceObservation: Equatable, Codable, Sendable {
    public let fixtureID: String
    public let controlSignatureFNV1A64: String
    public let outputFrameCount: Int64
    public let events: [Lane3ObservedRenderEvent]
    public let audioSummary: Lane3AudioSummary?
    public let actualAudioCaptured: Bool

    public init(
        fixtureID: String,
        controlSignatureFNV1A64: String,
        outputFrameCount: Int64,
        events: [Lane3ObservedRenderEvent],
        audioSummary: Lane3AudioSummary?,
        actualAudioCaptured: Bool
    ) {
        self.fixtureID = fixtureID
        self.controlSignatureFNV1A64 = controlSignatureFNV1A64
        self.outputFrameCount = outputFrameCount
        self.events = events
        self.audioSummary = audioSummary
        self.actualAudioCaptured = actualAudioCaptured
    }
}

public struct Lane3ReferenceComparisonTolerances: Equatable, Codable, Sendable {
    public let durationFrames: Int64
    public let eventFrames: Int64
    public let rmsDeltaDB: Double
    public let peakDeltaDB: Double

    public init(durationFrames: Int64 = 2, eventFrames: Int64 = 2, rmsDeltaDB: Double = 1, peakDeltaDB: Double = 1) {
        self.durationFrames = durationFrames
        self.eventFrames = eventFrames
        self.rmsDeltaDB = rmsDeltaDB
        self.peakDeltaDB = peakDeltaDB
    }
}

public struct Lane3ReferenceComparisonResult: Equatable, Codable, Sendable {
    public let passed: Bool
    public let signatureMatched: Bool
    public let durationDeltaFrames: Int64
    public let maxEventDeltaFrames: Int64?
    public let rmsDeltaDB: Double?
    public let peakDeltaDB: Double?
    public let blockers: [String]
    public let parityPromotionAllowed: Bool
}

public enum Lane3ReferenceComparator {
    public static func compare(
        plan: Lane3ReferenceRenderPlan,
        observation: Lane3ReferenceObservation,
        referenceAudioSummary: Lane3AudioSummary? = nil,
        tolerances: Lane3ReferenceComparisonTolerances = Lane3ReferenceComparisonTolerances()
    ) -> Lane3ReferenceComparisonResult {
        var blockers: [String] = []
        let signatureMatched = plan.controlSignatureFNV1A64 == observation.controlSignatureFNV1A64
        if !signatureMatched { blockers.append("CONTROL_SIGNATURE_MISMATCH") }
        if plan.fixtureID != observation.fixtureID { blockers.append("FIXTURE_ID_MISMATCH") }

        let durationDelta = absoluteDifference(plan.outputFrameCount, observation.outputFrameCount)
        if durationDelta > UInt64(max(0, tolerances.durationFrames)) { blockers.append("OUTPUT_DURATION_MISMATCH") }

        let expected = plan.events.filter { $0.kind != .practiceState }.map {
            Lane3ObservedRenderEvent(kind: $0.kind, frame: $0.frame, stemID: $0.stemID)
        }
        var maxEventDelta: Int64? = nil
        if expected.count != observation.events.count {
            blockers.append("EVENT_COUNT_MISMATCH")
        } else {
            var maxDelta: UInt64 = 0
            for (lhs, rhs) in zip(expected, observation.events) {
                if lhs.kind != rhs.kind || lhs.stemID != rhs.stemID {
                    blockers.append("EVENT_IDENTITY_MISMATCH")
                    break
                }
                maxDelta = max(maxDelta, absoluteDifference(lhs.frame, rhs.frame))
            }
            maxEventDelta = maxDelta > UInt64(Int64.max) ? Int64.max : Int64(maxDelta)
            if maxDelta > UInt64(max(0, tolerances.eventFrames)) { blockers.append("EVENT_TIMING_MISMATCH") }
        }

        var rmsDelta: Double? = nil
        var peakDelta: Double? = nil
        if let referenceAudioSummary {
            guardLike: do {
                guard let observed = observation.audioSummary else {
                    blockers.append("AUDIO_SUMMARY_MISSING")
                    break guardLike
                }
                if !observation.actualAudioCaptured { blockers.append("ACTUAL_AUDIO_CAPTURE_REQUIRED") }
                if observed.nonFiniteSampleCount > 0 { blockers.append("NONFINITE_AUDIO_SAMPLES") }
                if observed.channels != referenceAudioSummary.channels || observed.sampleRate != referenceAudioSummary.sampleRate {
                    blockers.append("AUDIO_FORMAT_MISMATCH")
                }
                rmsDelta = dbDelta(referenceAudioSummary.rms, observed.rms)
                peakDelta = dbDelta(referenceAudioSummary.peakAbsolute, observed.peakAbsolute)
                if let rmsDelta, rmsDelta > tolerances.rmsDeltaDB { blockers.append("RMS_SUMMARY_MISMATCH") }
                if let peakDelta, peakDelta > tolerances.peakDeltaDB { blockers.append("PEAK_SUMMARY_MISMATCH") }
            }
        }

        return Lane3ReferenceComparisonResult(
            passed: blockers.isEmpty,
            signatureMatched: signatureMatched,
            durationDeltaFrames: durationDelta > UInt64(Int64.max) ? Int64.max : Int64(durationDelta),
            maxEventDeltaFrames: maxEventDelta,
            rmsDeltaDB: rmsDelta,
            peakDeltaDB: peakDelta,
            blockers: blockers,
            parityPromotionAllowed: false
        )
    }

    private static func absoluteDifference(_ lhs: Int64, _ rhs: Int64) -> UInt64 {
        if (lhs >= 0) == (rhs >= 0) {
            let a = lhs.magnitude
            let b = rhs.magnitude
            return a >= b ? a - b : b - a
        }
        let (sum, overflow) = lhs.magnitude.addingReportingOverflow(rhs.magnitude)
        return overflow ? UInt64.max : sum
    }

    private static func dbDelta(_ lhs: Double, _ rhs: Double) -> Double {
        if lhs == rhs { return 0 }
        let floor = 1e-12
        return abs(20 * log10(max(lhs, floor) / max(rhs, floor)))
    }
}
