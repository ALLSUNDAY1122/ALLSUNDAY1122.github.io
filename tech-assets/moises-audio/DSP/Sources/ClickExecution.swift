import Foundation

public enum DSPClickExecutionError: Error, Equatable, Sendable {
    case invalidSampleRate(Double)
    case staleGeneration(active: UInt64, event: UInt64)
    case generationRegression(active: UInt64, requested: UInt64)
    case negativeSampleTime(Int64)
    case nonIncreasingSampleTime(previous: Int64, current: Int64)
    case eventBeforeRenderOrigin(event: Int64, renderOrigin: Int64)
    case eventNotBeforeMusicStart(event: Int64, musicStart: Int64)
    case appendOverlapsQueued(previousLast: Int64, nextFirst: Int64)
    case appendAnchorMismatch(expected: Int64, actual: Int64)
    case appendSampleRateMismatch(expected: Double, actual: Double)
    case appendKindMismatch
    case timelineOverflow
}

public enum DSPClickBatchKind: Equatable, Sendable {
    case metronome
    case countIn(musicStartSampleTime: Int64)
}

public struct DSPClickExecutionBatch: Equatable, Sendable {
    public let generation: UInt64
    public let kind: DSPClickBatchKind
    public let renderOriginSampleTime: Int64
    public let sampleRate: Double
    public let relativeEvents: [DSPClickEvent]
    public let firstProjectSampleTime: Int64?
    public let lastProjectSampleTime: Int64?

    public init(
        generation: UInt64,
        kind: DSPClickBatchKind,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        relativeEvents: [DSPClickEvent],
        firstProjectSampleTime: Int64?,
        lastProjectSampleTime: Int64?
    ) {
        self.generation = generation
        self.kind = kind
        self.renderOriginSampleTime = renderOriginSampleTime
        self.sampleRate = sampleRate
        self.relativeEvents = relativeEvents
        self.firstProjectSampleTime = firstProjectSampleTime
        self.lastProjectSampleTime = lastProjectSampleTime
    }
}

/// Converts absolute project-render sample times into one player-node-relative schedule only after
/// the whole batch has passed generation/timeline validation. This prevents a stale event late in a
/// batch from being discovered after earlier click buffers have already been queued.
public enum DSPClickExecutionPlanner {
    public static func preflight(
        events: [DSPClickEvent],
        activeGeneration: UInt64,
        renderOriginSampleTime: Int64,
        sampleRate: Double,
        kind: DSPClickBatchKind
    ) throws -> DSPClickExecutionBatch {
        guard sampleRate.isFinite, sampleRate > 0 else {
            throw DSPClickExecutionError.invalidSampleRate(sampleRate)
        }
        guard renderOriginSampleTime >= 0 else {
            throw DSPClickExecutionError.negativeSampleTime(renderOriginSampleTime)
        }
        if case .countIn(let musicStartSampleTime) = kind,
           musicStartSampleTime < 0 {
            throw DSPClickExecutionError.negativeSampleTime(musicStartSampleTime)
        }

        var previousProjectSampleTime: Int64?
        var relativeEvents: [DSPClickEvent] = []
        relativeEvents.reserveCapacity(events.count)

        for event in events {
            guard event.generation == activeGeneration else {
                throw DSPClickExecutionError.staleGeneration(
                    active: activeGeneration,
                    event: event.generation
                )
            }
            guard event.sampleTime >= 0 else {
                throw DSPClickExecutionError.negativeSampleTime(event.sampleTime)
            }
            if let previousProjectSampleTime,
               event.sampleTime <= previousProjectSampleTime {
                throw DSPClickExecutionError.nonIncreasingSampleTime(
                    previous: previousProjectSampleTime,
                    current: event.sampleTime
                )
            }
            previousProjectSampleTime = event.sampleTime

            guard event.sampleTime >= renderOriginSampleTime else {
                throw DSPClickExecutionError.eventBeforeRenderOrigin(
                    event: event.sampleTime,
                    renderOrigin: renderOriginSampleTime
                )
            }
            if case .countIn(let musicStartSampleTime) = kind,
               event.sampleTime >= musicStartSampleTime {
                throw DSPClickExecutionError.eventNotBeforeMusicStart(
                    event: event.sampleTime,
                    musicStart: musicStartSampleTime
                )
            }

            let (relativeSampleTime, overflow) = event.sampleTime
                .subtractingReportingOverflow(renderOriginSampleTime)
            guard !overflow else {
                throw DSPClickExecutionError.timelineOverflow
            }
            relativeEvents.append(
                DSPClickEvent(
                    sampleTime: relativeSampleTime,
                    beatIndex: event.beatIndex,
                    accent: event.accent,
                    generation: event.generation
                )
            )
        }

        return DSPClickExecutionBatch(
            generation: activeGeneration,
            kind: kind,
            renderOriginSampleTime: renderOriginSampleTime,
            sampleRate: sampleRate,
            relativeEvents: relativeEvents,
            firstProjectSampleTime: events.first?.sampleTime,
            lastProjectSampleTime: events.last?.sampleTime
        )
    }
}

/// Portable state mirrored by the Apple executor. A generation invalidation atomically forgets the
/// old queue/anchor. Rolling metronome windows may append only to the exact same generation, render
/// origin, sample rate and schedule kind; any anchor change requires replacement instead of append.
public struct DSPClickExecutionState: Equatable, Sendable {
    public private(set) var activeGeneration: UInt64
    public private(set) var queuedThroughProjectSampleTime: Int64?
    public private(set) var activeRenderOriginSampleTime: Int64?
    public private(set) var activeSampleRate: Double?
    public private(set) var activeKind: DSPClickBatchKind?

    public init(
        activeGeneration: UInt64,
        queuedThroughProjectSampleTime: Int64? = nil,
        activeRenderOriginSampleTime: Int64? = nil,
        activeSampleRate: Double? = nil,
        activeKind: DSPClickBatchKind? = nil
    ) {
        self.activeGeneration = activeGeneration
        self.queuedThroughProjectSampleTime = queuedThroughProjectSampleTime
        self.activeRenderOriginSampleTime = activeRenderOriginSampleTime
        self.activeSampleRate = activeSampleRate
        self.activeKind = activeKind
    }

    public mutating func invalidate(to generation: UInt64) throws {
        guard generation >= activeGeneration else {
            throw DSPClickExecutionError.generationRegression(
                active: activeGeneration,
                requested: generation
            )
        }
        activeGeneration = generation
        queuedThroughProjectSampleTime = nil
        activeRenderOriginSampleTime = nil
        activeSampleRate = nil
        activeKind = nil
    }

    public mutating func acceptReplacement(
        _ batch: DSPClickExecutionBatch
    ) throws {
        guard batch.generation == activeGeneration else {
            throw DSPClickExecutionError.staleGeneration(
                active: activeGeneration,
                event: batch.generation
            )
        }
        queuedThroughProjectSampleTime = batch.lastProjectSampleTime
        activeRenderOriginSampleTime = batch.renderOriginSampleTime
        activeSampleRate = batch.sampleRate
        activeKind = batch.kind
    }

    public mutating func acceptAppend(
        _ batch: DSPClickExecutionBatch
    ) throws {
        guard batch.generation == activeGeneration else {
            throw DSPClickExecutionError.staleGeneration(
                active: activeGeneration,
                event: batch.generation
            )
        }
        if let expected = activeRenderOriginSampleTime,
           expected != batch.renderOriginSampleTime {
            throw DSPClickExecutionError.appendAnchorMismatch(
                expected: expected,
                actual: batch.renderOriginSampleTime
            )
        }
        if let expected = activeSampleRate,
           abs(expected - batch.sampleRate) > 0.000_001 {
            throw DSPClickExecutionError.appendSampleRateMismatch(
                expected: expected,
                actual: batch.sampleRate
            )
        }
        if let expected = activeKind,
           expected != batch.kind {
            throw DSPClickExecutionError.appendKindMismatch
        }
        if let previousLast = queuedThroughProjectSampleTime,
           let nextFirst = batch.firstProjectSampleTime,
           nextFirst <= previousLast {
            throw DSPClickExecutionError.appendOverlapsQueued(
                previousLast: previousLast,
                nextFirst: nextFirst
            )
        }

        if activeRenderOriginSampleTime == nil {
            activeRenderOriginSampleTime = batch.renderOriginSampleTime
            activeSampleRate = batch.sampleRate
            activeKind = batch.kind
        }
        if let last = batch.lastProjectSampleTime {
            queuedThroughProjectSampleTime = last
        }
    }
}
