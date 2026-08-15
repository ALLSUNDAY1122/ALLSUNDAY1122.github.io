import Foundation
@preconcurrency import Supabase
import UIKit

private struct ScanLabTrustedCreatedScan: Decodable {
    let id: UUID
}

private struct ScanLabTrustedPublishRequest: Encodable {
    let scanId: String
}

private struct ScanLabTrustedDraftInsert: Encodable {
    let ownerId: UUID
    let title: String
    let caption: String
    let visibility: String
    let status: String
    let assetPath: String
    let previewPath: String?
    let latitude: Double?
    let longitude: Double?
    let locationLabel: String?
    let publicPlaceConfirmed: Bool
    let privacyConfirmed: Bool
    let rightsConfirmed: Bool
    let contentConfirmed: Bool

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case title, caption, visibility, status
        case assetPath = "asset_path"
        case previewPath = "preview_path"
        case latitude, longitude
        case locationLabel = "location_label"
        case publicPlaceConfirmed = "public_place_confirmed"
        case privacyConfirmed = "privacy_confirmed"
        case rightsConfirmed = "rights_confirmed"
        case contentConfirmed = "content_confirmed"
    }
}

extension ScanLabBackend {
    /// Explicit network-publish path. The local completed result is first converted into C2's
    /// browser-share contract (`scene.spz` + `manifest.json` + optional preview) and only those
    /// package artifacts are uploaded. The raw reconstruction `.splat` never leaves the device.
    func publishTrustedPackage(
        resultURL: URL,
        previewImage: UIImage?,
        title: String,
        caption: String,
        visibility: ScanLabVisibility,
        location: ScanLabLocation?,
        publicPlaceConfirmed: Bool,
        privacyConfirmed: Bool,
        rightsConfirmed: Bool,
        contentConfirmed: Bool
    ) async throws -> ScanLabPublishResponse {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(trimmedTitle.count) else { throw ScanLabBackendError.invalidTitle }
        guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }
        let user = session.user

        if visibility != .private && !contentConfirmed {
            throw ScanLabBackendError.contentConfirmationRequired
        }
        if visibility == .public {
            guard location != nil else { throw ScanLabBackendError.invalidPublicLocation }
            guard publicPlaceConfirmed, privacyConfirmed, rightsConfirmed else {
                throw ScanLabBackendError.safetyConfirmationRequired
            }
        }

        let previewJPEG = previewImage?.jpegData(compressionQuality: 0.82)
        let package = try await SplatExportService.makeBrowserSharePackage(
            sourceURL: resultURL,
            previewJPEG: previewJPEG
        )
        defer { try? FileManager.default.removeItem(at: package.directoryURL) }

        let assetAttributes = try FileManager.default.attributesOfItem(atPath: package.assetURL.path)
        guard let assetSize = assetAttributes[.size] as? NSNumber, assetSize.intValue > 0 else {
            throw ScanLabBackendError.invalidAsset
        }
        guard assetSize.intValue <= ScanLabConfig.maximumAssetBytes else {
            throw ScanLabBackendError.assetTooLarge
        }

        let uploadID = UUID().uuidString.lowercased()
        let prefix = "\(user.id.uuidString.lowercased())/\(uploadID)"
        let assetPath = "\(prefix)/scene.spz"
        let manifestPath = "\(prefix)/manifest.json"
        let previewPath = package.previewURL == nil ? nil : "\(prefix)/preview.jpg"
        var uploadedPaths: [String] = []

        do {
            try await client.storage.from("scanlab-assets").upload(
                assetPath,
                fileURL: package.assetURL,
                options: FileOptions(contentType: "application/octet-stream")
            )
            uploadedPaths.append(assetPath)

            // The existing private bucket only permits binary/image MIME types. Keep the JSON
            // filename and bytes intact while using octet-stream so deployed bucket policy does
            // not need to widen merely to transport the integrity sidecar.
            try await client.storage.from("scanlab-assets").upload(
                manifestPath,
                fileURL: package.manifestURL,
                options: FileOptions(contentType: "application/octet-stream")
            )
            uploadedPaths.append(manifestPath)

            if let previewPath, let previewURL = package.previewURL {
                try await client.storage.from("scanlab-assets").upload(
                    previewPath,
                    fileURL: previewURL,
                    options: FileOptions(contentType: "image/jpeg")
                )
                uploadedPaths.append(previewPath)
            }

            let draft = ScanLabTrustedDraftInsert(
                ownerId: user.id,
                title: trimmedTitle,
                caption: String(caption.prefix(500)),
                visibility: visibility.rawValue,
                status: "draft",
                assetPath: assetPath,
                previewPath: previewPath,
                latitude: location?.latitude,
                longitude: location?.longitude,
                locationLabel: location?.label,
                publicPlaceConfirmed: publicPlaceConfirmed,
                privacyConfirmed: privacyConfirmed,
                rightsConfirmed: rightsConfirmed,
                contentConfirmed: contentConfirmed
            )
            let created: ScanLabTrustedCreatedScan = try await client
                .from("scanlab_scans")
                .insert(draft)
                .select("id")
                .single()
                .execute()
                .value

            let published: ScanLabPublishResponse = try await client.functions.invoke(
                "scanlab-publish",
                options: FunctionInvokeOptions(
                    region: .apSoutheast1,
                    body: ScanLabTrustedPublishRequest(scanId: created.id.uuidString.lowercased()),
                    timeoutInterval: 30
                )
            )
            await loadOwnerScans()
            if visibility == .public { await loadPublicScans() }
            return published
        } catch {
            if !uploadedPaths.isEmpty {
                try? await client.storage.from("scanlab-assets").remove(paths: uploadedPaths)
            }
            throw error
        }
    }
}
