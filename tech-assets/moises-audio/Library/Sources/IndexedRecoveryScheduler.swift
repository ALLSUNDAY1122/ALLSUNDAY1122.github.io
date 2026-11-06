import Foundation

public struct Lane2IndexedRecoveryBudget: Equatable, Sendable {
    public static let defaultOwnershipOnlyPerPass = 64
    public static let minimumOwnershipOnlyPerPass = 8
    public static let maximumOwnershipOnlyPerPass = 256

    public let ownershipOnlyPerPass: Int

    public init(ownershipOnlyPerPass: Int = Self.defaultOwnershipOnlyPerPass) {
        self.ownershipOnlyPerPass = min(
            max(ownershipOnlyPerPass, Self.minimumOwnershipOnlyPerPass),
            Self.maximumOwnershipOnlyPerPass
        )
    }

    public func selectedCount(availableOwnershipOnlyRecords: Int) -> Int {
        min(max(availableOwnershipOnlyRecords, 0), ownershipOnlyPerPass)
    }

    public func passCount(forOwnershipOnlyRecordCount count: Int) -> Int {
        let count = max(count, 0)
        guard count > 0 else { return 0 }
        return (count + ownershipOnlyPerPass - 1) / ownershipOnlyPerPass
    }
}

public struct Lane2DeletionOwnershipSlice: Sendable {
    public let records: [Lane2DeletionOwnershipRecord]
    public let hasMore: Bool
    public let limit: Int

    public init(records: [Lane2DeletionOwnershipRecord], hasMore: Bool, limit: Int) {
        self.records = records
        self.hasMore = hasMore
        self.limit = limit
    }
}

public struct Lane2IndexedRecoveryDiagnostics: Hashable, Sendable {
    public let prioritizedDeletionJournals: Int
    public let ownershipOnlyRecordsSelected: Int
    public let ownershipOnlyRecordsDeferred: Bool
    public let ownershipOnlyLimit: Int

    public init(
        prioritizedDeletionJournals: Int,
        ownershipOnlyRecordsSelected: Int,
        ownershipOnlyRecordsDeferred: Bool,
        ownershipOnlyLimit: Int
    ) {
        self.prioritizedDeletionJournals = prioritizedDeletionJournals
        self.ownershipOnlyRecordsSelected = ownershipOnlyRecordsSelected
        self.ownershipOnlyRecordsDeferred = ownershipOnlyRecordsDeferred
        self.ownershipOnlyLimit = ownershipOnlyLimit
    }

    public static func empty(limit: Int) -> Self {
        Self(
            prioritizedDeletionJournals: 0,
            ownershipOnlyRecordsSelected: 0,
            ownershipOnlyRecordsDeferred: false,
            ownershipOnlyLimit: limit
        )
    }
}
