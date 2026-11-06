import Foundation

public enum Lane3RepresentativeCodecFaultExpectation: String, Codable, Sendable, CaseIterable {
    case clean
    case truncated
    case corrupted
}

public enum Lane3RepresentativeCodecExecutionEnvironment: String, Codable, Sendable {
    case portableStructural
    case selectedAppleAVFAudio
    case physicalIPhoneAVFAudio
}

public enum Lane3RepresentativeCodecFailureCode: String, Codable, Sendable {
    case openRejected
    case invalidProcessingFormat
    case emptySource
    case sourceClosed
    case sourceMetadataChanged
    case policyRejected
    case bufferAllocationFailed
    case seekFailed
    case readFailed
    case shortRead
    case pcmAccessUnavailable
    case positionMismatch
    case unexpectedReadFailure
    case invalidFixtureDescriptor
    case sourceMetadataMismatch
    case nonFinitePCM
}

public struct Lane3RepresentativeCodecReadFailure: Error, Equatable, Sendable {
    public let code: Lane3RepresentativeCodecFailureCode

    public init(_ code: Lane3RepresentativeCodecFailureCode) {
        self.code = code
    }
}

public enum Lane3RepresentativeCodecExecutionError: Error, Equatable, Sendable {
    case invalidFixtureID
    case invalidCodecLabel
    case invalidExpectedChannels(Int)
    case invalidExpectedSampleRate(Double)
    case invalidBaselineFrameCount(Int64)
    case invalidChunkFrames(Int)
    case sourceMetadataMismatch
    case integerOverflow
}

public struct Lane3RepresentativeCodecFixtureDescriptor: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let fixtureID: String
    public let declaredCodecLabel: String
    public let faultExpectation: Lane3RepresentativeCodecFaultExpectation
    public let expectedChannels: Int
    public let expectedSampleRate: Double
    public let baselineFrameCount: Int64
    public let rightsCleared: Bool
    public let sourcePathIncluded: Bool
    public let rawCompressedBytesIncluded: Bool
    public let parityPromotionAllowed: Bool

    public init(
        fixtureID: String,
        declaredCodecLabel: String,
        faultExpectation: Lane3RepresentativeCodecFaultExpectation,
        expectedChannels: Int,
        expectedSampleRate: Double,
        baselineFrameCount: Int64,
        rightsCleared: Bool
    ) throws {
        guard Self.validIdentifier(fixtureID, maximumLength: 128) else {
            throw Lane3RepresentativeCodecExecutionError.invalidFixtureID
        }
        guard Self.validIdentifier(declaredCodecLabel, maximumLength: 64) else {
            throw Lane3RepresentativeCodecExecutionError.invalidCodecLabel
        }
        guard expectedChannels > 0, expectedChannels <= 64 else {
            throw Lane3RepresentativeCodecExecutionError.invalidExpectedChannels(expectedChannels)
        }
        guard expectedSampleRate.isFinite, expectedSampleRate > 0, expectedSampleRate <= 768_000 else {
            throw Lane3RepresentativeCodecExecutionError.invalidExpectedSampleRate(expectedSampleRate)
        }
        guard baselineFrameCount > 0 else {
            throw Lane3RepresentativeCodecExecutionError.invalidBaselineFrameCount(baselineFrameCount)
        }
        self.schemaVersion = 1
        self.fixtureID = fixtureID
        self.declaredCodecLabel = declaredCodecLabel
        self.faultExpectation = faultExpectation
        self.expectedChannels = expectedChannels
        self.expectedSampleRate = expectedSampleRate
        self.baselineFrameCount = baselineFrameCount
        self.rightsCleared = rightsCleared
        self.sourcePathIncluded = false
        self.rawCompressedBytesIncluded = false
        self.parityPromotionAllowed = false
    }

    public var baselineDurationSeconds: Double {
        Double(baselineFrameCount) / expectedSampleRate
    }

    public var representsAtLeastThirtyMinutes: Bool {
        baselineDurationSeconds >= 1_800
    }

    private static func validIdentifier(_ value: String, maximumLength: Int) -> Bool {
        guard !value.isEmpty, value.count <= maximumLength else { return false }
        return value.unicodeScalars.allSatisfy { scalar in
            let v = scalar.value
            return (48...57).contains(v) || (65...90).contains(v) || (97...122).contains(v) || v == 45 || v == 46 || v == 95
        }
    }
}

public struct Lane3RepresentativeCodecExecutionReport: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let fixture: Lane3RepresentativeCodecFixtureDescriptor
    public let environment: Lane3RepresentativeCodecExecutionEnvironment
    public let decoderOpened: Bool
    public let actualChannels: Int?
    public let actualSampleRate: Double?
    public let actualFrameCount: Int64?
    public let readCalls: UInt64
    public let framesRead: UInt64
    public let maximumChunkFrames: Int
    public let completeSequentialSweep: Bool
    public let nonFiniteSampleCount: UInt64
    public let rollingPCMChecksumFNV1A64: UInt64?
    public let failureCode: Lane3RepresentativeCodecFailureCode?
    public let metadataTruncationObserved: Bool
    public let expectedFaultObserved: Bool
    public let cleanDecodeContractSatisfied: Bool
    public let rightsCleared: Bool
    public let representativeLongTrack: Bool
    public let boundedChunkedRead: Bool
    public let rawPCMRetained: Bool
    public let sourcePathIncluded: Bool
    public let authoritativePhysicalEvidenceAllowed: Bool
    public let parityPromotionAllowed: Bool
}

private struct Lane3RepresentativeCodecSourceMetadataSnapshot: Equatable, Sendable {
    let channels: Int
    let sampleRate: Double
    let frameCount: Int64

    func exactlyMatches(_ other: Lane3RepresentativeCodecSourceMetadataSnapshot) -> Bool {
        channels == other.channels
            && sampleRate.bitPattern == other.sampleRate.bitPattern
            && frameCount == other.frameCount
    }
}

public enum Lane3RepresentativeCodecExecutionProbe {
    public static func openRejected(
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        environment: Lane3RepresentativeCodecExecutionEnvironment,
        failureCode: Lane3RepresentativeCodecFailureCode
    ) -> Lane3RepresentativeCodecExecutionReport {
        let faultObserved = descriptor.faultExpectation != .clean
        return Lane3RepresentativeCodecExecutionReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
            fixture: descriptor,
            environment: environment,
            decoderOpened: false,
            actualChannels: nil,
            actualSampleRate: nil,
            actualFrameCount: nil,
            readCalls: 0,
            framesRead: 0,
            maximumChunkFrames: 0,
            completeSequentialSweep: false,
            nonFiniteSampleCount: 0,
            rollingPCMChecksumFNV1A64: nil,
            failureCode: failureCode,
            metadataTruncationObserved: false,
            expectedFaultObserved: faultObserved,
            cleanDecodeContractSatisfied: false,
            rightsCleared: descriptor.rightsCleared,
            representativeLongTrack: descriptor.representsAtLeastThirtyMinutes,
            boundedChunkedRead: true,
            rawPCMRetained: false,
            sourcePathIncluded: false,
            authoritativePhysicalEvidenceAllowed: environment == .physicalIPhoneAVFAudio && descriptor.rightsCleared,
            parityPromotionAllowed: false
        )
    }

    public static func sweep(
        source: any Lane3PCMChunkReadable,
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        environment: Lane3RepresentativeCodecExecutionEnvironment,
        chunkFrames: Int = 16_384
    ) throws -> Lane3RepresentativeCodecExecutionReport {
        guard chunkFrames > 0, chunkFrames <= 1_048_576 else {
            throw Lane3RepresentativeCodecExecutionError.invalidChunkFrames(chunkFrames)
        }

        // AW50: freeze protocol-visible metadata before the first read. The second snapshot catches a
        // source that is already unstable during preflight. Loop bounds, sample-count expectations and
        // the final report are all derived from this frozen snapshot rather than live getters.
        let metadata = sourceMetadata(source)
        let confirmation = sourceMetadata(source)
        let metadataTruncation = metadata.frameCount >= 0
            && metadata.frameCount < descriptor.baselineFrameCount

        if !metadata.exactlyMatches(confirmation) {
            return reportRuntimeMetadataChange(
                metadata: metadata,
                descriptor: descriptor,
                environment: environment,
                metadataTruncation: metadataTruncation,
                maximumChunkFrames: chunkFrames
            )
        }

        let metadataMatches = metadata.channels == descriptor.expectedChannels
            && abs(metadata.sampleRate - descriptor.expectedSampleRate) <= 0.5
        if !metadataMatches || metadata.frameCount <= 0 {
            return reportMetadataFailure(
                metadata: metadata,
                descriptor: descriptor,
                environment: environment,
                metadataTruncation: metadataTruncation
            )
        }

        var readCalls: UInt64 = 0
        var framesRead: UInt64 = 0
        var nonFinite: UInt64 = 0
        var checksum: UInt64 = 0xcbf29ce484222325
        var frame: Int64 = 0
        var failureCode: Lane3RepresentativeCodecFailureCode?
        var complete = false

        while frame < metadata.frameCount {
            guard metadataStable(source, expected: metadata) else {
                failureCode = .sourceMetadataChanged
                break
            }

            let remaining = metadata.frameCount - frame
            let count = min(chunkFrames, Int(remaining))
            do {
                let samples = try source.readInterleavedFrames(startFrame: frame, frameCount: count)
                guard metadataStable(source, expected: metadata) else {
                    failureCode = .sourceMetadataChanged
                    break
                }

                let expected = Int64(count).multipliedReportingOverflow(by: Int64(metadata.channels))
                guard !expected.overflow,
                      expected.partialValue >= 0,
                      expected.partialValue <= Int64(Int.max) else {
                    throw Lane3RepresentativeCodecExecutionError.integerOverflow
                }
                guard samples.count == Int(expected.partialValue) else {
                    failureCode = .shortRead
                    break
                }

                readCalls = saturatingAdd(readCalls, 1)
                framesRead = saturatingAdd(framesRead, UInt64(count))
                for sample in samples {
                    if !sample.isFinite {
                        nonFinite = saturatingAdd(nonFinite, 1)
                    }
                    checksum ^= UInt64(sample.bitPattern)
                    checksum = checksum &* 0x100000001b3
                }
                if nonFinite > 0 {
                    failureCode = .nonFinitePCM
                    break
                }
                frame += Int64(count)
            } catch let failure as Lane3RepresentativeCodecReadFailure {
                failureCode = metadataStable(source, expected: metadata)
                    ? failure.code
                    : .sourceMetadataChanged
                break
            } catch is Lane3RepresentativeCodecExecutionError {
                throw Lane3RepresentativeCodecExecutionError.integerOverflow
            } catch {
                failureCode = metadataStable(source, expected: metadata)
                    ? .unexpectedReadFailure
                    : .sourceMetadataChanged
                break
            }
        }

        if failureCode == nil {
            guard metadataStable(source, expected: metadata) else {
                failureCode = .sourceMetadataChanged
                return finalReport(
                    metadata: metadata,
                    descriptor: descriptor,
                    environment: environment,
                    chunkFrames: chunkFrames,
                    metadataTruncation: metadataTruncation,
                    readCalls: readCalls,
                    framesRead: framesRead,
                    nonFinite: nonFinite,
                    checksum: checksum,
                    failureCode: failureCode,
                    complete: false
                )
            }
            if frame == metadata.frameCount {
                complete = true
            }
        }

        return finalReport(
            metadata: metadata,
            descriptor: descriptor,
            environment: environment,
            chunkFrames: chunkFrames,
            metadataTruncation: metadataTruncation,
            readCalls: readCalls,
            framesRead: framesRead,
            nonFinite: nonFinite,
            checksum: checksum,
            failureCode: failureCode,
            complete: complete
        )
    }

    private static func finalReport(
        metadata: Lane3RepresentativeCodecSourceMetadataSnapshot,
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        environment: Lane3RepresentativeCodecExecutionEnvironment,
        chunkFrames: Int,
        metadataTruncation: Bool,
        readCalls: UInt64,
        framesRead: UInt64,
        nonFinite: UInt64,
        checksum: UInt64,
        failureCode: Lane3RepresentativeCodecFailureCode?,
        complete: Bool
    ) -> Lane3RepresentativeCodecExecutionReport {
        let cleanSatisfied = descriptor.faultExpectation == .clean
            && !metadataTruncation
            && metadata.frameCount == descriptor.baselineFrameCount
            && complete
            && nonFinite == 0
            && failureCode == nil
        let faultObserved: Bool
        switch descriptor.faultExpectation {
        case .clean:
            faultObserved = false
        case .truncated:
            faultObserved = metadataTruncation || failureCode != nil
        case .corrupted:
            faultObserved = failureCode != nil
        }

        return Lane3RepresentativeCodecExecutionReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
            fixture: descriptor,
            environment: environment,
            decoderOpened: true,
            actualChannels: metadata.channels,
            actualSampleRate: metadata.sampleRate,
            actualFrameCount: metadata.frameCount,
            readCalls: readCalls,
            framesRead: framesRead,
            maximumChunkFrames: chunkFrames,
            completeSequentialSweep: complete,
            nonFiniteSampleCount: nonFinite,
            rollingPCMChecksumFNV1A64: readCalls > 0 ? checksum : nil,
            failureCode: failureCode,
            metadataTruncationObserved: metadataTruncation,
            expectedFaultObserved: faultObserved,
            cleanDecodeContractSatisfied: cleanSatisfied,
            rightsCleared: descriptor.rightsCleared,
            representativeLongTrack: descriptor.representsAtLeastThirtyMinutes,
            boundedChunkedRead: true,
            rawPCMRetained: false,
            sourcePathIncluded: false,
            authoritativePhysicalEvidenceAllowed: environment == .physicalIPhoneAVFAudio && descriptor.rightsCleared,
            parityPromotionAllowed: false
        )
    }

    private static func reportRuntimeMetadataChange(
        metadata: Lane3RepresentativeCodecSourceMetadataSnapshot,
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        environment: Lane3RepresentativeCodecExecutionEnvironment,
        metadataTruncation: Bool,
        maximumChunkFrames: Int
    ) -> Lane3RepresentativeCodecExecutionReport {
        finalReport(
            metadata: metadata,
            descriptor: descriptor,
            environment: environment,
            chunkFrames: maximumChunkFrames,
            metadataTruncation: metadataTruncation,
            readCalls: 0,
            framesRead: 0,
            nonFinite: 0,
            checksum: 0xcbf29ce484222325,
            failureCode: .sourceMetadataChanged,
            complete: false
        )
    }

    private static func reportMetadataFailure(
        metadata: Lane3RepresentativeCodecSourceMetadataSnapshot,
        descriptor: Lane3RepresentativeCodecFixtureDescriptor,
        environment: Lane3RepresentativeCodecExecutionEnvironment,
        metadataTruncation: Bool
    ) -> Lane3RepresentativeCodecExecutionReport {
        let faultObserved = descriptor.faultExpectation != .clean && metadataTruncation
        return Lane3RepresentativeCodecExecutionReport(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW43_REPRESENTATIVE_CODEC_EXECUTION_NON_PARITY",
            fixture: descriptor,
            environment: environment,
            decoderOpened: true,
            actualChannels: metadata.channels,
            actualSampleRate: metadata.sampleRate,
            actualFrameCount: metadata.frameCount,
            readCalls: 0,
            framesRead: 0,
            maximumChunkFrames: 0,
            completeSequentialSweep: false,
            nonFiniteSampleCount: 0,
            rollingPCMChecksumFNV1A64: nil,
            failureCode: .sourceMetadataMismatch,
            metadataTruncationObserved: metadataTruncation,
            expectedFaultObserved: faultObserved,
            cleanDecodeContractSatisfied: false,
            rightsCleared: descriptor.rightsCleared,
            representativeLongTrack: descriptor.representsAtLeastThirtyMinutes,
            boundedChunkedRead: true,
            rawPCMRetained: false,
            sourcePathIncluded: false,
            authoritativePhysicalEvidenceAllowed: environment == .physicalIPhoneAVFAudio && descriptor.rightsCleared,
            parityPromotionAllowed: false
        )
    }

    private static func sourceMetadata(
        _ source: any Lane3PCMChunkReadable
    ) -> Lane3RepresentativeCodecSourceMetadataSnapshot {
        Lane3RepresentativeCodecSourceMetadataSnapshot(
            channels: source.channels,
            sampleRate: source.sampleRate,
            frameCount: source.frameCount
        )
    }

    private static func metadataStable(
        _ source: any Lane3PCMChunkReadable,
        expected: Lane3RepresentativeCodecSourceMetadataSnapshot
    ) -> Bool {
        expected.exactlyMatches(sourceMetadata(source))
    }

    private static func saturatingAdd(_ value: UInt64, _ delta: UInt64) -> UInt64 {
        let result = value.addingReportingOverflow(delta)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

public struct Lane3RepresentativeCodecEvidenceMatrixSummary: Equatable, Codable, Sendable {
    public let schemaVersion: Int
    public let evidenceScope: String
    public let requiredCodecLabels: [String]
    public let reportCount: Int
    public let cleanContractsSatisfied: Int
    public let expectedFaultsObserved: Int
    public let missingContractCells: [String]
    public let rightsOrDurationFailures: Int
    public let physicalIPhoneReports: Int
    public let contractCoverageComplete: Bool
    public let physicalEvidenceComplete: Bool
    public let rawPCMIncluded: Bool
    public let sourcePathIncluded: Bool
    public let parityPromotionAllowed: Bool
}

public enum Lane3RepresentativeCodecEvidenceMatrixEvaluator {
    public static func evaluate(
        reports: [Lane3RepresentativeCodecExecutionReport],
        requiredCodecLabels: [String]
    ) -> Lane3RepresentativeCodecEvidenceMatrixSummary {
        let required = Array(Set(requiredCodecLabels)).sorted()
        var missing: [String] = []
        var cleanSatisfied = 0
        var faultsObserved = 0
        var rightsOrDurationFailures = 0
        var physical = 0

        for report in reports {
            if report.fixture.faultExpectation == .clean, report.cleanDecodeContractSatisfied {
                cleanSatisfied += 1
            }
            if report.fixture.faultExpectation != .clean, report.expectedFaultObserved {
                faultsObserved += 1
            }
            if !report.rightsCleared || !report.representativeLongTrack {
                rightsOrDurationFailures += 1
            }
            if report.environment == .physicalIPhoneAVFAudio {
                physical += 1
            }
        }

        for codec in required {
            for expectation in Lane3RepresentativeCodecFaultExpectation.allCases {
                let matches = reports.filter {
                    $0.fixture.declaredCodecLabel == codec && $0.fixture.faultExpectation == expectation
                }
                let cellSatisfied: Bool
                switch expectation {
                case .clean:
                    cellSatisfied = matches.contains { $0.cleanDecodeContractSatisfied && $0.rightsCleared && $0.representativeLongTrack }
                case .truncated, .corrupted:
                    cellSatisfied = matches.contains { $0.expectedFaultObserved && $0.rightsCleared && $0.representativeLongTrack }
                }
                if !cellSatisfied {
                    missing.append("\(codec):\(expectation.rawValue)")
                }
            }
        }

        let contractComplete = !required.isEmpty && missing.isEmpty && rightsOrDurationFailures == 0
        let physicalComplete = contractComplete && reports.allSatisfy {
            $0.environment == .physicalIPhoneAVFAudio && $0.authoritativePhysicalEvidenceAllowed
        }
        return Lane3RepresentativeCodecEvidenceMatrixSummary(
            schemaVersion: 1,
            evidenceScope: "LANE3_AW43_REPRESENTATIVE_CODEC_MATRIX_NON_PARITY",
            requiredCodecLabels: required,
            reportCount: reports.count,
            cleanContractsSatisfied: cleanSatisfied,
            expectedFaultsObserved: faultsObserved,
            missingContractCells: missing.sorted(),
            rightsOrDurationFailures: rightsOrDurationFailures,
            physicalIPhoneReports: physical,
            contractCoverageComplete: contractComplete,
            physicalEvidenceComplete: physicalComplete,
            rawPCMIncluded: false,
            sourcePathIncluded: false,
            parityPromotionAllowed: false
        )
    }
}
