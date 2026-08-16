import Foundation
@preconcurrency import Supabase

private struct ScanLabVisibilityChangeRequest: Encodable {
    let scanId: String
    let visibility: String
    let latitude: Double?
    let longitude: Double?
    let locationLabel: String?
    let contentConfirmed: Bool
    let publicPlaceConfirmed: Bool
    let privacyConfirmed: Bool
    let rightsConfirmed: Bool
}

extension ScanLabBackend {
    func changeVisibility(
        _ scan: ScanLabOwnerScan,
        to visibility: ScanLabVisibility,
        location: ScanLabLocation?,
        contentConfirmed: Bool,
        publicPlaceConfirmed: Bool,
        privacyConfirmed: Bool,
        rightsConfirmed: Bool
    ) async throws {
        guard scan.status == "published", scan.moderationStatus == "approved" else {
            throw ScanLabBackendError.invalidServerResponse
        }
        if visibility != .private && !contentConfirmed {
            throw ScanLabBackendError.contentConfirmationRequired
        }
        if visibility == .public {
            guard location != nil else { throw ScanLabBackendError.invalidPublicLocation }
            guard publicPlaceConfirmed, privacyConfirmed, rightsConfirmed else {
                throw ScanLabBackendError.safetyConfirmationRequired
            }
        }

        let request = ScanLabVisibilityChangeRequest(
            scanId: scan.id.uuidString.lowercased(),
            visibility: visibility.rawValue,
            latitude: visibility == .public ? location?.latitude : nil,
            longitude: visibility == .public ? location?.longitude : nil,
            locationLabel: visibility == .public ? location?.label : nil,
            contentConfirmed: visibility == .private ? false : contentConfirmed,
            publicPlaceConfirmed: visibility == .public ? publicPlaceConfirmed : false,
            privacyConfirmed: visibility == .public ? privacyConfirmed : false,
            rightsConfirmed: visibility == .public ? rightsConfirmed : false
        )

        let _: ScanLabPublishResponse = try await client.functions.invoke(
            "scanlab-visibility",
            options: FunctionInvokeOptions(
                region: .apSoutheast1,
                body: request,
                timeoutInterval: 30
            )
        )
        await loadOwnerScans()
        await loadPublicScans()
    }
}
