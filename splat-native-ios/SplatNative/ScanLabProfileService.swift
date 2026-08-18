import Foundation
@preconcurrency import PostgREST
@preconcurrency import Supabase

struct ScanLabEditableProfile: Decodable, Hashable {
    let id: UUID
    let handle: String
    let displayName: String
    let bio: String?
    let avatarURL: URL?

    enum CodingKeys: String, CodingKey {
        case id, handle, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

struct ScanLabPublicProfile: Decodable, Identifiable, Hashable {
    let id: UUID
    let handle: String
    let displayName: String
    let bio: String?
    let avatarURL: URL?
    let publicScanCount: Int

    enum CodingKeys: String, CodingKey {
        case id, handle, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
        case publicScanCount = "public_scan_count"
    }
}

private struct ScanLabEditableProfileUpdate: Encodable {
    let handle: String
    let displayName: String
    let bio: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case handle, bio
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

struct ScanLabProfileService {
    let client: SupabaseClient

    func loadMine() async throws -> ScanLabEditableProfile {
        let session = try await client.auth.session
        return try await client.from("scanlab_profiles")
            .select("id,handle,display_name,bio,avatar_url")
            .eq("id", value: session.user.id)
            .single().execute().value
    }

    func save(handle: String, displayName: String, bio: String, avatarURL: String) async throws -> ScanLabEditableProfile {
        guard ScanLabProfilePolicy.validate(handle: handle, displayName: displayName, bio: bio, avatarURL: avatarURL) else {
            throw ScanLabBackendError.invalidProfile
        }
        let session = try await client.auth.session
        let normalizedAvatar = avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : ScanLabProfilePolicy.normalizedAvatarURL(avatarURL)?.absoluteString
        let update = ScanLabEditableProfileUpdate(
            handle: ScanLabProfilePolicy.normalizedHandle(handle),
            displayName: ScanLabProfilePolicy.normalizedDisplayName(displayName),
            bio: ScanLabProfilePolicy.normalizedBio(bio),
            avatarURL: normalizedAvatar
        )
        return try await client.from("scanlab_profiles")
            .update(update)
            .eq("id", value: session.user.id)
            .select("id,handle,display_name,bio,avatar_url")
            .single().execute().value
    }

    func loadPublic(handle: String) async throws -> ScanLabPublicProfile? {
        let normalized = ScanLabProfilePolicy.normalizedHandle(handle)
        guard ScanLabProfilePolicy.handleRange.contains(normalized.count) else { return nil }
        let rows: [ScanLabPublicProfile] = try await client.rpc("scanlab_public_profile", params: ["p_handle": normalized]).execute().value
        return rows.first
    }
}
