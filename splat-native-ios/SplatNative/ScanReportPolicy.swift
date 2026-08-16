import Foundation

enum ScanReportReason: String, CaseIterable, Codable, Sendable {
    case privacy
    case unsafeLocation = "unsafe_location"
    case copyright
    case harassment
    case sexual
    case violence
    case spam
    case other

    var title: String {
        switch self {
        case .privacy: return "Privacy"
        case .unsafeLocation: return "Unsafe location"
        case .copyright: return "Copyright"
        case .harassment: return "Harassment"
        case .sexual: return "Sexual content"
        case .violence: return "Violence"
        case .spam: return "Spam"
        case .other: return "Other"
        }
    }
}

struct ScanReportDraft: Equatable, Sendable {
    static let maximumDetailsLength = 1_000

    let scanID: UUID
    let reason: ScanReportReason
    let details: String

    init(scanID: UUID, reason: ScanReportReason, details: String) throws {
        guard details.count <= Self.maximumDetailsLength else {
            throw ScanReportValidationError.detailsTooLong
        }
        self.scanID = scanID
        self.reason = reason
        self.details = details
    }
}

enum ScanReportValidationError: Error, Equatable, Sendable {
    case detailsTooLong
}

struct ScanReportReceipt: Decodable, Equatable, Sendable {
    let reportID: Int64
    let duplicate: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case reportID = "report_id"
        case duplicate
        case createdAt = "created_at"
    }
}

enum ScanReportSubmissionState: Equatable, Sendable {
    case ready
    case submitting
    case persisted(reportID: Int64, createdAt: Date)
    case duplicate(reportID: Int64, createdAt: Date)
    case failed(message: String)

    var disablesSubmit: Bool {
        switch self {
        case .submitting, .persisted, .duplicate: return true
        case .ready, .failed: return false
        }
    }
}

enum ScanReportPolicy {
    static func state(from receipt: ScanReportReceipt) -> ScanReportSubmissionState {
        if receipt.duplicate {
            return .duplicate(reportID: receipt.reportID, createdAt: receipt.createdAt)
        }
        return .persisted(reportID: receipt.reportID, createdAt: receipt.createdAt)
    }
}
