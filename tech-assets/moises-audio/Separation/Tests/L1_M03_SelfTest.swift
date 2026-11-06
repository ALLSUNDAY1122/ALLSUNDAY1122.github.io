import Foundation

@main private struct Main {
    static func main() async throws {
        try await testPrepareCommitDeleteHappyPath()
        try await testExpiringURLRejectedBeforeFetch()
        try await testDuplicateRoleRejected()
        try await testDuplicateStemIDRejected()
        try await testCorruptWAVLeavesExistingFinalUntouched()
        try await testSampleRateMismatchRejected()
        try await testFrameCountMismatchRejected()
        try await testExpectedHashMismatchRejected()
        try await testInvalidCostAndRetentionRejected()
        try await testDeleteProtectsNewerRun()
        try await testCrashRecoveryRestoresBackup()
        try await testFileLedgerRoundTrip()
        try await testMissingOutputRejected()
        try await testUnsupportedContainerRejected()
        try await testExpectedByteCountMismatchRejected()
        try await testDeleteProtectsAdditionalNewerStem()
        try await testAssuredProviderUsesManifestSeamAndCachesCommittedResult()
        try await testFlatLiveManifestCodecFeedsAssurance()
        print("L1_M03_SELF_TEST_PASS scenarios=18")
    }
}
