import Foundation

public struct IOStorageBudget: Equatable, Sendable {
    public let requiredBytes: Int64
    public let reserveBytes: Int64
    public let availableBytes: Int64

    public init(requiredBytes: Int64, reserveBytes: Int64, availableBytes: Int64) {
        self.requiredBytes = requiredBytes
        self.reserveBytes = reserveBytes
        self.availableBytes = availableBytes
    }

    public var totalRequiredBytes: Int64 {
        guard requiredBytes >= 0, reserveBytes >= 0 else { return Int64.max }
        let sum = requiredBytes.addingReportingOverflow(reserveBytes)
        return sum.overflow ? Int64.max : sum.partialValue
    }

    public var overflowed: Bool {
        guard requiredBytes >= 0, reserveBytes >= 0 else { return false }
        return requiredBytes.addingReportingOverflow(reserveBytes).overflow
    }

    public var hasCapacity: Bool {
        availableBytes >= 0 && !overflowed && availableBytes >= totalRequiredBytes
    }
}

public enum IOStoragePreflightPolicy {
    public static func validate(_ budget: IOStorageBudget) throws {
        guard budget.requiredBytes >= 0, budget.reserveBytes >= 0, budget.availableBytes >= 0 else {
            throw IOFileStore.StoreError.fileOperationFailed(code: "STORAGE_BUDGET_INVALID")
        }
        guard budget.hasCapacity else {
            throw IOFileStore.StoreError.insufficientStorage(
                requiredBytes: budget.totalRequiredBytes,
                availableBytes: budget.availableBytes
            )
        }
    }
}

public extension IOFileStore {
    /// Deterministic storage-pressure seam for tests and preflight callers that already know capacity.
    func preflight(requiredBytes: Int64, reserveBytes: Int64, availableBytes: Int64) throws {
        try IOStoragePreflightPolicy.validate(
            IOStorageBudget(
                requiredBytes: requiredBytes,
                reserveBytes: reserveBytes,
                availableBytes: availableBytes
            )
        )
    }
}
