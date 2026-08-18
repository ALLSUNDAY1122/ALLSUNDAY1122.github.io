import Foundation
@preconcurrency import Supabase

private struct ScanReportSubmitRPCParams: Encodable {
    let targetScanID: UUID
    let reportReason: String
    let reportDetails: String

    enum CodingKeys: String, CodingKey {
        case targetScanID = "target_scan_id"
        case reportReason = "report_reason"
        case reportDetails = "report_details"
    }
}

private struct ScanReportStatusRPCParams: Encodable {
    let targetScanID: UUID

    enum CodingKeys: String, CodingKey {
        case targetScanID = "target_scan_id"
    }
}

@MainActor
extension ScanLabBackend {
    func hasReported(_ scan: ScanLabPublicScan) async throws -> Bool {
        guard isAuthenticated else { return false }
        return try await client
            .rpc("scanlab_has_reported", params: ScanReportStatusRPCParams(targetScanID: scan.id))
            .execute()
            .value
    }

    @discardableResult
    func submitReport(
        _ scan: ScanLabPublicScan,
        reason: ScanReportReason,
        details: String = ""
    ) async throws -> ScanReportSubmissionState {
        guard isAuthenticated else { throw ScanLabBackendError.signInRequired }

        let draft = try ScanReportDraft(scanID: scan.id, reason: reason, details: details)
        let receipts: [ScanReportReceipt] = try await client
            .rpc(
                "scanlab_submit_report",
                params: ScanReportSubmitRPCParams(
                    targetScanID: draft.scanID,
                    reportReason: draft.reason.rawValue,
                    reportDetails: draft.details
                )
            )
            .execute()
            .value

        guard let receipt = receipts.first else {
            throw ScanLabBackendError.invalidServerResponse
        }

        let state = ScanReportPolicy.state(from: receipt)
        switch state {
        case .persisted:
            notice = "報告を受け付けました。内容は運営確認用に保存されます。"
        case .duplicate:
            notice = "この3Dはすでに報告済みです。最初の報告内容を保持しています。"
        case .ready, .submitting, .failed:
            break
        }
        return state
    }
}
