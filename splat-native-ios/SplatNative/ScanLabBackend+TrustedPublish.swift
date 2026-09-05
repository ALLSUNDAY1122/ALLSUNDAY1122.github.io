import Foundation
@preconcurrency import Supabase
import UIKit

private struct ScanLabUploadInitRequest: Encodable {
    let action = "init"
    let title: String
    let caption: String
}

private struct ScanLabUploadValidateRequest: Encodable {
    let action = "validate"
    let scanId: String
}

private struct ScanLabUploadPaths: Decodable {
    let scene: String
    let manifest: String
    let previewJpeg: String
    let previewPng: String
}

private struct ScanLabUploadInitResponse: Decodable {
    let scanId: UUID
    let paths: ScanLabUploadPaths
    let required: [String]
}

private struct ScanLabUploadValidateResponse: Decodable {
    let scanId: UUID
    let ready: Bool
}

private struct ScanLabTrustedPublishRequest: Encodable { let scanId: String }
private struct ScanLabDeleteDraftRequest: Encodable { let scanId: String }

private struct ScanLabTrustedDraftSettings: Encodable {
    let visibility: String
    let previewPath: String?
    let latitude: Double?
    let longitude: Double?
    let locationLabel: String?
    let publicPlaceConfirmed: Bool
    let privacyConfirmed: Bool
    let rightsConfirmed: Bool
    let contentConfirmed: Bool

    enum CodingKeys: String, CodingKey {
        case visibility
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

        if visibility != .private && !contentConfirmed {
            throw ScanLabBackendError.contentConfirmationRequired
        }

        let publishLocation = ScanLabGeotagPolicy.normalized(
            visibility: visibility,
            location: location,
            label: location?.label
        )
        if visibility == .public {
            guard ScanLabGeotagPolicy.canPublishPublic(
                location: publishLocation,
                publicPlaceConfirmed: publicPlaceConfirmed,
                privacyConfirmed: privacyConfirmed,
                rightsConfirmed: rightsConfirmed
            ) else {
                throw ScanLabBackendError.safetyConfirmationRequired
            }
        }

        let package: ScanLabPublishPackage
        do {
            package = try ScanLabPublishPackageBuilder.build(
                from: resultURL,
                maximumBytes: ScanLabConfig.maximumAssetBytes
            )
        } catch ScanLabPublishPackageError.sourceTooLarge {
            throw ScanLabBackendError.assetTooLarge
        } catch {
            throw ScanLabBackendError.invalidAsset
        }
        defer { ScanLabPublishPackageBuilder.cleanup(package) }

        // D2-004 + D2-015 convergence: create the owner-bound draft first.
        // The final Storage policy intentionally rejects uploads that are not attached
        // to a live draft, which also prevents assets from being resurrected while a
        // deletion is in progress.
        let initialized: ScanLabUploadInitResponse = try await client.functions.invoke(
            "scanlab-upload",
            options: FunctionInvokeOptions(
                region: .apSoutheast1,
                body: ScanLabUploadInitRequest(
                    title: trimmedTitle,
                    caption: String(caption.prefix(500))
                ),
                timeoutInterval: 30
            )
        )

        let scanID = initialized.scanId
        let expectedPrefix = "\(session.user.id.uuidString.lowercased())/\(scanID.uuidString.lowercased())"
        guard initialized.paths.scene == "\(expectedPrefix)/scene.spz",
              initialized.paths.manifest == "\(expectedPrefix)/manifest.json",
              initialized.paths.previewJpeg == "\(expectedPrefix)/preview.jpg",
              initialized.paths.previewPng == "\(expectedPrefix)/preview.png",
              Set(initialized.required) == Set(["scene.spz", "manifest.json"]) else {
            await cleanupFailedDraft(scanID)
            throw ScanLabBackendError.invalidServerResponse
        }

        let previewPath = previewImage == nil ? nil : initialized.paths.previewJpeg

        do {
            try await client.storage.from("scanlab-assets").upload(
                initialized.paths.scene,
                fileURL: package.sceneURL,
                options: FileOptions(contentType: ScanLabPublishPackage.sceneMediaType)
            )
            try await client.storage.from("scanlab-assets").upload(
                initialized.paths.manifest,
                fileURL: package.manifestURL,
                options: FileOptions(contentType: "application/json")
            )
            if let previewPath, let previewData = previewImage?.jpegData(compressionQuality: 0.82) {
                try await client.storage.from("scanlab-assets").upload(
                    previewPath,
                    data: previewData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            }

            let settings = ScanLabTrustedDraftSettings(
                visibility: visibility.rawValue,
                previewPath: previewPath,
                latitude: publishLocation?.latitude,
                longitude: publishLocation?.longitude,
                locationLabel: publishLocation?.label,
                publicPlaceConfirmed: visibility == .public && publishLocation != nil && publicPlaceConfirmed,
                privacyConfirmed: visibility == .public && privacyConfirmed,
                rightsConfirmed: visibility == .public && rightsConfirmed,
                contentConfirmed: visibility != .private && contentConfirmed
            )
            try await client.from("scanlab_scans")
                .update(settings)
                .eq("id", value: scanID)
                .eq("owner_id", value: session.user.id)
                .eq("status", value: "draft")
                .execute()

            let validation: ScanLabUploadValidateResponse = try await client.functions.invoke(
                "scanlab-upload",
                options: FunctionInvokeOptions(
                    region: .apSoutheast1,
                    body: ScanLabUploadValidateRequest(
                        scanId: scanID.uuidString.lowercased()
                    ),
                    timeoutInterval: 30
                )
            )
            guard validation.scanId == scanID, validation.ready else {
                throw ScanLabBackendError.invalidServerResponse
            }

            // Private cloud storage intentionally remains an owner-only draft. A private
            // row must never enter the published lifecycle or receive a share URL.
            if visibility == .private {
                await loadOwnerScans()
                return ScanLabPublishResponse(
                    id: scanID,
                    visibility: ScanLabVisibility.private.rawValue,
                    publishedAt: nil,
                    shareUrl: nil
                )
            }

            let published: ScanLabPublishResponse = try await client.functions.invoke(
                "scanlab-publish",
                options: FunctionInvokeOptions(
                    region: .apSoutheast1,
                    body: ScanLabTrustedPublishRequest(
                        scanId: scanID.uuidString.lowercased()
                    ),
                    timeoutInterval: 30
                )
            )
            guard published.id == scanID else { throw ScanLabBackendError.invalidServerResponse }

            await loadOwnerScans()
            if visibility == .public { await loadPublicScans() }
            return published
        } catch {
            await cleanupFailedDraft(scanID)
            throw error
        }
    }

    private func cleanupFailedDraft(_ scanID: UUID) async {
        // D2-015 is idempotent and also cleans an orphaned canonical folder when the
        // metadata row has already disappeared, so it is the only rollback path used.
        let _: ScanLabDeleteDraftResponse? = try? await client.functions.invoke(
            "scanlab-delete-scan",
            options: FunctionInvokeOptions(
                region: .apSoutheast1,
                body: ScanLabDeleteDraftRequest(scanId: scanID.uuidString.lowercased()),
                timeoutInterval: 30
            )
        )
    }
}

private struct ScanLabDeleteDraftResponse: Decodable {
    let deleted: Bool
}
