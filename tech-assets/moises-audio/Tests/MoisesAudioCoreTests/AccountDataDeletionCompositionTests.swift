import Foundation
import XCTest
@testable import MoisesAudioCore

final class AccountDataDeletionCompositionTests: XCTestCase {
    func testBothOwnershipDomainsReceiveExactCapturedScope() async throws {
        let projectID = ProjectID(rawValue: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let scope = AccountDeletionProjectScope(projectID: projectID, processingJobID: jobID)
        let processing = RecordingProcessingDeleter()
        let library = RecordingLibraryDeleter()
        let coordinator = AccountDataDeletionCoordinator(
            processingDeletion: processing,
            libraryDeletion: library
        )

        let report = try await coordinator.deleteAccountData(scopes: [scope])
        let processingCalls = await processing.calls
        let libraryCalls = await library.calls

        XCTAssertTrue(report.isComplete)
        XCTAssertEqual(report.processingConfirmedProjectIDs, [projectID])
        XCTAssertEqual(report.libraryConfirmedProjectIDs, [projectID])
        XCTAssertEqual(processingCalls, [scope])
        XCTAssertEqual(libraryCalls, [projectID])
    }

    func testProcessingFailureDoesNotSuppressIndependentLane2Deletion() async {
        let projectID = ProjectID(rawValue: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let scope = AccountDeletionProjectScope(projectID: projectID, processingJobID: nil)
        let processing = RecordingProcessingDeleter(failingProjectIDs: [projectID])
        let library = RecordingLibraryDeleter()
        let coordinator = AccountDataDeletionCoordinator(
            processingDeletion: processing,
            libraryDeletion: library
        )

        do {
            _ = try await coordinator.deleteAccountData(scopes: [scope])
            XCTFail("expected incomplete deletion")
        } catch AccountDataDeletionError.incomplete(let report) {
            XCTAssertEqual(report.processingConfirmedProjectIDs, [])
            XCTAssertEqual(report.libraryConfirmedProjectIDs, [projectID])
            XCTAssertEqual(
                report.failures,
                [AccountDataDeletionFailure(
                    projectID: projectID,
                    subsystem: .processing,
                    stableErrorCode: "ACCOUNT_PROCESSING_DELETE_FAILED"
                )]
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let processingCalls = await processing.calls
        let libraryCalls = await library.calls
        XCTAssertEqual(processingCalls, [scope])
        XCTAssertEqual(libraryCalls, [projectID])
    }

    func testLibraryFailureDoesNotSuppressIndependentLane1Deletion() async {
        let projectID = ProjectID(rawValue: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!)
        let jobID = ProcessingJobID(rawValue: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!)
        let scope = AccountDeletionProjectScope(projectID: projectID, processingJobID: jobID)
        let processing = RecordingProcessingDeleter()
        let library = RecordingLibraryDeleter(failingProjectIDs: [projectID])
        let coordinator = AccountDataDeletionCoordinator(
            processingDeletion: processing,
            libraryDeletion: library
        )

        do {
            _ = try await coordinator.deleteAccountData(scopes: [scope])
            XCTFail("expected incomplete deletion")
        } catch AccountDataDeletionError.incomplete(let report) {
            XCTAssertEqual(report.processingConfirmedProjectIDs, [projectID])
            XCTAssertEqual(report.libraryConfirmedProjectIDs, [])
            XCTAssertEqual(
                report.failures,
                [AccountDataDeletionFailure(
                    projectID: projectID,
                    subsystem: .library,
                    stableErrorCode: "ACCOUNT_LIBRARY_DELETE_FAILED"
                )]
            )
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let processingCalls = await processing.calls
        let libraryCalls = await library.calls
        XCTAssertEqual(processingCalls, [scope])
        XCTAssertEqual(libraryCalls, [projectID])
    }

    func testDuplicateProjectScopeFailsBeforeAnyDeletionSideEffect() async {
        let projectID = ProjectID(rawValue: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!)
        let scopeA = AccountDeletionProjectScope(projectID: projectID, processingJobID: nil)
        let scopeB = AccountDeletionProjectScope(
            projectID: projectID,
            processingJobID: ProcessingJobID(rawValue: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!)
        )
        let processing = RecordingProcessingDeleter()
        let library = RecordingLibraryDeleter()
        let coordinator = AccountDataDeletionCoordinator(
            processingDeletion: processing,
            libraryDeletion: library
        )

        do {
            _ = try await coordinator.deleteAccountData(scopes: [scopeA, scopeB])
            XCTFail("expected duplicate scope rejection")
        } catch AccountDataDeletionError.duplicateProjectScope(let duplicateID) {
            XCTAssertEqual(duplicateID, projectID)
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        let processingCalls = await processing.calls
        let libraryCalls = await library.calls
        XCTAssertEqual(processingCalls, [])
        XCTAssertEqual(libraryCalls, [])
    }
}

private enum AccountDeletionTestFailure: Error {
    case forced
}

private actor RecordingProcessingDeleter: AccountProcessingDataDeleting {
    private let failingProjectIDs: Set<ProjectID>
    private(set) var calls: [AccountDeletionProjectScope] = []

    init(failingProjectIDs: Set<ProjectID> = []) {
        self.failingProjectIDs = failingProjectIDs
    }

    func deleteProcessingData(
        projectID: ProjectID,
        processingJobID: ProcessingJobID?
    ) async throws {
        calls.append(
            AccountDeletionProjectScope(
                projectID: projectID,
                processingJobID: processingJobID
            )
        )
        if failingProjectIDs.contains(projectID) {
            throw AccountDeletionTestFailure.forced
        }
    }
}

private actor RecordingLibraryDeleter: AccountLibraryDataDeleting {
    private let failingProjectIDs: Set<ProjectID>
    private(set) var calls: [ProjectID] = []

    init(failingProjectIDs: Set<ProjectID> = []) {
        self.failingProjectIDs = failingProjectIDs
    }

    func deleteProjectAndOwnedArtifacts(projectID: ProjectID) async throws {
        calls.append(projectID)
        if failingProjectIDs.contains(projectID) {
            throw AccountDeletionTestFailure.forced
        }
    }
}
