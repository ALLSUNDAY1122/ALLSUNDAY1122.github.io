import Foundation

public enum Lane3CombinedRecoveryError: Error, Equatable, Sendable {
    case invalidStemCount(Int)
    case invalidStemIndex(Int)
    case invalidGain(Double)
    case invalidTempoRatio(Double)
    case invalidPitchSemitones(Double)
    case invalidCountInClicks(Int)
    case invalidLoop(start: Double, end: Double)
    case invalidSeekPosition(Double)
    case generationOverflow
    case poisoned
    case playWhileInterrupted
}

public enum Lane3CombinedRecoveryDiscontinuityReason: String, Codable, Sendable, CaseIterable {
    case mediaLoad
    case mediaReplacement
    case play
    case pause
    case seek
    case loopChange
    case tempoChange
    case interruptionBegan
    case interruptionEnded
    case recovery
}

public struct Lane3CombinedRecoveryBinding: Equatable, Codable, Sendable {
    public let playbackGeneration: UInt64
    public let clickGeneration: UInt64
    public let reason: Lane3CombinedRecoveryDiscontinuityReason
}

public struct Lane3CombinedRecoveryState: Equatable, Codable, Sendable {
    public var playbackGeneration: UInt64
    public var clickGeneration: UInt64
    public var binding: Lane3CombinedRecoveryBinding?
    public var gains: [Double]
    public var tempoRatio: Double
    public var pitchSemitones: Double
    public var metronomeEnabled: Bool
    public var pendingCountInClicks: Int?
    public var loopStartSeconds: Double?
    public var loopEndSeconds: Double?
    public var positionSeconds: Double
    public var playing: Bool
    public var interrupted: Bool
    public var poisoned: Bool

    public init(
        stemCount: Int,
        playbackGeneration: UInt64 = 0,
        clickGeneration: UInt64 = 0
    ) throws {
        guard stemCount > 0, stemCount <= 64 else {
            throw Lane3CombinedRecoveryError.invalidStemCount(stemCount)
        }
        self.playbackGeneration = playbackGeneration
        self.clickGeneration = clickGeneration
        self.binding = nil
        self.gains = [Double](repeating: 1, count: stemCount)
        self.tempoRatio = 1
        self.pitchSemitones = 0
        self.metronomeEnabled = false
        self.pendingCountInClicks = nil
        self.loopStartSeconds = nil
        self.loopEndSeconds = nil
        self.positionSeconds = 0
        self.playing = false
        self.interrupted = false
        self.poisoned = false
    }
}

public enum Lane3CombinedRecoveryOperation: Equatable, Sendable {
    case setGain(stemIndex: Int, gain: Double)
    case setPitch(Double)
    case setTempo(Double)
    case setMetronome(Bool)
    case scheduleCountIn(Int)
    case consumeCountIn
    case seek(Double)
    case setLoop(start: Double, end: Double)
    case clearLoop
    case play
    case pause
    case interruptionBegan
    case interruptionEnded(resume: Bool)
    case forceHalfInvalidationFailure
    case recover(resume: Bool)
    case staleCompletion(playbackGeneration: UInt64)
    case staleReplacement(binding: Lane3CombinedRecoveryBinding?)
}

public struct Lane3CombinedRecoveryCounters: Equatable, Codable, Sendable {
    public var applied: Int = 0
    public var rejected: Int = 0
    public var forcedHalfFailures: Int = 0
    public var recoveries: Int = 0
    public var staleCompletionAttempts: Int = 0
    public var staleCompletionRejected: Int = 0
    public var staleReplacementAttempts: Int = 0
    public var staleReplacementRejected: Int = 0
    public var clickOnlyInvalidations: Int = 0
    public var transportInvalidations: Int = 0
}

public struct Lane3CombinedRecoveryStressReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let seed: UInt64
    public let requestedOperations: Int
    public let counters: Lane3CombinedRecoveryCounters
    public let finalState: Lane3CombinedRecoveryState
    public let finalInvariantPassed: Bool
    public let checksumFNV1A64: String
    public let physicalDeviceEvidence: Bool
    public let realAudioEvidence: Bool
    public let audibleArtifactClaimAllowed: Bool
    public let parityPromotionAllowed: Bool
}

/// Deterministic portable state/recovery oracle for Lane 3. It deliberately couples mixer,
/// transport, tempo/pitch, metronome/count-in and interruption/recovery mutations so stale schedule
/// generations are exercised under interleaving rather than in isolated unit tests.
///
/// This is an evidence/hardening model, not an AVAudioEngine substitute. Passing it cannot prove
/// click/pop freedom, device timing, audible quality or Moises parity.
