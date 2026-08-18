import Foundation
@preconcurrency import Supabase
import UIKit

private struct ScanLabTrustedCreatedScan: Decodable { let id: UUID }
private struct ScanLabTrustedPublishRequest: Encodable { let scanId: String }
private struct ScanLabTrustedDraftInsert: Encodable {
    let id: UUID; let ownerId: UUID; let title: String; let caption: String; let visibility: String; let status: String
    let assetPath: String; let previewPath: String?; let latitude: Double?; let longitude: Double?; let locationLabel: String?
    let publicPlaceConfirmed: Bool; let privacyConfirmed: Bool; let rightsConfirmed: Bool; let contentConfirmed: Bool
    enum CodingKeys: String, CodingKey {
        case id; case ownerId = "owner_id"; case title, caption, visibility, status; case assetPath = "asset_path"; case previewPath = "preview_path"
        case latitude, longitude; case locationLabel = "location_label"; case publicPlaceConfirmed = "public_place_confirmed"
        case privacyConfirmed = "privacy_confirmed"; case rightsConfirmed = "rights_confirmed"; case contentConfirmed = "content_confirmed"
    }
}

extension ScanLabBackend {
    func publishTrustedPackage(resultURL: URL, previewImage: UIImage?, title: String, caption: String, visibility: ScanLabVisibility, location: ScanLabLocation?, publicPlaceConfirmed: Bool, privacyConfirmed: Bool, rightsConfirmed: Bool, contentConfirmed: Bool) async throws -> ScanLabPublishResponse {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(trimmedTitle.count) else { throw ScanLabBackendError.invalidTitle }
        guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }
        let user = session.user
        if visibility != .private && !contentConfirmed { throw ScanLabBackendError.contentConfirmationRequired }
        let publishLocation = ScanLabGeotagPolicy.normalized(visibility: visibility, location: location, label: location?.label)
        if visibility == .public {
            guard ScanLabGeotagPolicy.canPublishPublic(location: publishLocation, publicPlaceConfirmed: publicPlaceConfirmed, privacyConfirmed: privacyConfirmed, rightsConfirmed: rightsConfirmed) else { throw ScanLabBackendError.safetyConfirmationRequired }
        }
        let package: ScanLabPublishPackage
        do { package = try ScanLabPublishPackageBuilder.build(from: resultURL, maximumBytes: ScanLabConfig.maximumAssetBytes) }
        catch ScanLabPublishPackageError.sourceTooLarge { throw ScanLabBackendError.assetTooLarge }
        catch { throw ScanLabBackendError.invalidAsset }
        defer { ScanLabPublishPackageBuilder.cleanup(package) }

        let scanID = UUID()
        let prefix = "\(user.id.uuidString.lowercased())/\(scanID.uuidString.lowercased())"
        let assetPath = "\(prefix)/scene.spz"
        let manifestPath = "\(prefix)/manifest.json"
        let previewPath = previewImage == nil ? nil : "\(prefix)/preview.jpg"
        var uploadedPaths: [String] = []
        do {
            try await client.storage.from("scanlab-assets").upload(assetPath, fileURL: package.sceneURL, options: FileOptions(contentType: ScanLabPublishPackage.sceneMediaType)); uploadedPaths.append(assetPath)
            try await client.storage.from("scanlab-assets").upload(manifestPath, fileURL: package.manifestURL, options: FileOptions(contentType: "application/json")); uploadedPaths.append(manifestPath)
            if let previewPath, let previewData = previewImage?.jpegData(compressionQuality: 0.82) {
                try await client.storage.from("scanlab-assets").upload(previewPath, data: previewData, options: FileOptions(contentType: "image/jpeg")); uploadedPaths.append(previewPath)
            }
            let draft = ScanLabTrustedDraftInsert(id: scanID, ownerId: user.id, title: trimmedTitle, caption: String(caption.prefix(500)), visibility: visibility.rawValue, status: "draft", assetPath: assetPath, previewPath: previewPath, latitude: publishLocation?.latitude, longitude: publishLocation?.longitude, locationLabel: publishLocation?.label, publicPlaceConfirmed: visibility == .public && publishLocation != nil && publicPlaceConfirmed, privacyConfirmed: visibility == .public && privacyConfirmed, rightsConfirmed: visibility == .public && rightsConfirmed, contentConfirmed: contentConfirmed)
            let created: ScanLabTrustedCreatedScan = try await client.from("scanlab_scans").insert(draft).select("id").single().execute().value
            let published: ScanLabPublishResponse = try await client.functions.invoke("scanlab-publish", options: FunctionInvokeOptions(region: .apSoutheast1, body: ScanLabTrustedPublishRequest(scanId: created.id.uuidString.lowercased()), timeoutInterval: 30))
            await loadOwnerScans(); if visibility == .public { await loadPublicScans() }; return published
        } catch {
            if !uploadedPaths.isEmpty { try? await client.storage.from("scanlab-assets").remove(paths: uploadedPaths) }
            throw error
        }
    }
}
