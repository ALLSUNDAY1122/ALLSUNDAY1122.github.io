import Foundation

/// Captured before destructive work begins so Lane 1 processing identity is not lost when
/// Lane 2 removes the project/library record. Provider-specific Asset/Task identifiers must
/// remain behind the Lane 1 backend boundary and are deliberately not exposed here.
public struct AccountDeletionProjectScope: Hashable, Sendable {
    public let projectID: ProjectID
    public let processingJobID: ProcessingJobID?

    public init(projectID: ProjectID, processingJobID: ProcessingJobID?) {
        self.projectID = projectID
        self.processingJobID = processingJobID
    }
}

/// App-facing Lane 2 deletion seam. A production adapter must delegate to the durable Lane 2
/// project/source/library deletion path rather than deleting files directly from the App layer.
public protocol AccountLibraryDataDeleting: Sendable {
    func deleteProjectAndOwnedArtifacts(projectID: ProjectID) async throws
}

/// App-facing Lane 1 privacy/retention seam. A production adapter resolves provider identity
/// server-side and must route through PrivacyRetentionService (or semantically equivalent logic).
public protocol AccountProcessingDataDeleting: Sendable {
    func deleteProcessingData(
        projectID: ProjectID,
        processingJobID: ProcessingJobID?
    ) async throws
}

public enum AccountDataDeletionSubsystem: String, Hashable, Sendable {
    case processing
    case library
}

public struct AccountDataDeletionFailure: Equatable, Sendable {
    public let projectID: ProjectID
    public let subsystem: AccountDataDeletionSubsystem
    public let stableErrorCode: String

    public init(
        projectID: ProjectID,
        subsystem: AccountDataDeletionSubsystem,
        stableErrorCode: String
    ) {
        self.projectID = projectID
        self.subsystem = subsystem
        self.stableErrorCode = stableErrorCode
    }
}

public struct AccountDataDeletionReport: Equatable, Sendable {
    public let requestedProjectCount: Int
    public let processingConfirmedProjectIDs: [ProjectID]
    public let libraryConfirmedProjectIDs: [ProjectID]
    public let failures: [AccountDataDeletionFailure]

    public init(
        requestedProjectCount: Int,
        processingConfirmedProjectIDs: [ProjectID],
        libraryConfirmedProjectIDs: [ProjectID],
        failures: [AccountDataDeletionFailure]
    ) {
        self.requestedProjectCount = requestedProjectCount
        self.processingConfirmedProjectIDs = processingConfirmedProjectIDs
        self.libraryConfirmedProjectIDs = libraryConfirmedProjectIDs
        self.failures = failures
    }

    public var isComplete: Bool {
        failures.isEmpty
            && processingConfirmedProjectIDs.count == requestedProjectCount
            && libraryConfirmedProjectIDs.count == requestedProjectCount
    }
}

public enum AccountDataDeletionError: Error, Equatable, Sendable {
    /// Duplicate scopes are rejected before any side effect because ambiguous account inventory
    /// makes completion accounting and retry semantics unsafe.
    case duplicateProjectScope(ProjectID)
    /// Both subsystems have already been attempted independently for every unique scope.
    case incomplete(AccountDataDeletionReport)
}

/// Coordinates account/user-data deletion across the two independent ownership domains.
///
/// This actor intentionally does not short-circuit the second subsystem when the first fails:
/// privacy deletion and library/source deletion have distinct ownership and must both be attempted.
/// Operations behind both seams are required to be idempotent because a failed account deletion
/// can be retried. This coordinator is a composition/correctness gate only; it is not evidence that
/// a live provider accepted or completed remote erasure.
public actor AccountDataDeletionCoordinator {
    private let processingDeletion: any AccountProcessingDataDeleting
    private let libraryDeletion: any AccountLibraryDataDeleting

    public init(
        processingDeletion: any AccountProcessingDataDeleting,
        libraryDeletion: any AccountLibraryDataDeleting
    ) {
        self.processingDeletion = processingDeletion
        self.libraryDeletion = libraryDeletion
    }

    @discardableResult
    public func deleteAccountData(
        scopes: [AccountDeletionProjectScope]
    ) async throws -> AccountDataDeletionReport {
        var seen = Set<ProjectID>()
        for scope in scopes {
            guard seen.insert(scope.projectID).inserted else {
                throw AccountDataDeletionError.duplicateProjectScope(scope.projectID)
            }
        }

        var processingConfirmed: [ProjectID] = []
        var libraryConfirmed: [ProjectID] = []
        var failures: [AccountDataDeletionFailure] = []
        processingConfirmed.reserveCapacity(scopes.count)
        libraryConfirmed.reserveCapacity(scopes.count)

        for scope in scopes {
            do {
                try await processingDeletion.deleteProcessingData(
                    projectID: scope.projectID,
                    processingJobID: scope.processingJobID
                )
                processingConfirmed.append(scope.projectID)
            } catch {
                failures.append(
                    AccountDataDeletionFailure(
                        projectID: scope.projectID,
                        subsystem: .processing,
                        stableErrorCode: "ACCOUNT_PROCESSING_DELETE_FAILED"
                    )
                )
            }

            do {
                try await libraryDeletion.deleteProjectAndOwnedArtifacts(
                    projectID: scope.projectID
                )
                libraryConfirmed.append(scope.projectID)
            } catch {
                failures.append(
                    AccountDataDeletionFailure(
                        projectID: scope.projectID,
                        subsystem: .library,
                        stableErrorCode: "ACCOUNT_LIBRARY_DELETE_FAILED"
                    )
                )
            }
        }

        let report = AccountDataDeletionReport(
            requestedProjectCount: scopes.count,
            processingConfirmedProjectIDs: processingConfirmed,
            libraryConfirmedProjectIDs: libraryConfirmed,
            failures: failures
        )
        guard report.isComplete else {
            throw AccountDataDeletionError.incomplete(report)
        }
        return report
    }
}
