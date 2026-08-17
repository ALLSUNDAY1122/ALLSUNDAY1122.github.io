import Foundation
@preconcurrency import Supabase

private struct ScanLabLifecycleRequest: Encodable {
    let scanId: String
}

private struct ScanLabUnpublishResponse: Decodable {
    let id: UUID
    let status: String
    let visibility: String
    let publishedAt: String?
    let unpublished: Bool
}

extension ScanLabBackend {
    func unpublishPublishedScan(_ scan: ScanLabOwnerScan) async throws {
        let response: ScanLabUnpublishResponse = try await client.functions.invoke(
            "scanlab-unpublish",
            options: FunctionInvokeOptions(
                region: .apSoutheast1,
                body: ScanLabLifecycleRequest(scanId: scan.id.uuidString.lowercased()),
                timeoutInterval: 30
            )
        )
        guard response.id == scan.id, response.status != "published" else {
            throw ScanLabBackendError.invalidServerResponse
        }
        await loadOwnerScans()
        await loadPublicScans()
    }

    @discardableResult
    func republish(_ scan: ScanLabOwnerScan) async throws -> ScanLabPublishResponse {
        let response: ScanLabPublishResponse = try await client.functions.invoke(
            "scanlab-publish",
            options: FunctionInvokeOptions(
                region: .apSoutheast1,
                body: ScanLabLifecycleRequest(scanId: scan.id.uuidString.lowercased()),
                timeoutInterval: 30
            )
        )
        guard response.id == scan.id else {
            throw ScanLabBackendError.invalidServerResponse
        }
        await loadOwnerScans()
        await loadPublicScans()
        return response
    }
}
