import Combine
import Foundation
@preconcurrency import Supabase
import UIKit

struct ScanLabLocation: Codable, Hashable { let latitude: Double; let longitude: Double; let label: String? }
struct ScanLabAuthor: Codable, Hashable { let id: UUID; let handle: String; let displayName: String }
struct ScanLabPublicScan: Codable, Identifiable, Hashable { let id: UUID; let title: String; let caption: String; let visibility: String; let publishedAt: String?; let location: ScanLabLocation?; let author: ScanLabAuthor?; let likeCount: Int; let modelUrl: URL?; let previewUrl: URL? }
struct ScanLabPublicEnvelope: Decodable { let items: [ScanLabPublicScan] }

enum ScanLabVisibility: String, CaseIterable, Identifiable, Codable {
    case `private`, unlisted, `public`; var id: String { rawValue }
    var title: String { switch self { case .private: "非公開"; case .unlisted: "リンクを知っている人のみ"; case .public: "マップ・Discoverに公開" } }
    var explanation: String { switch self { case .private: "クラウドへ保存しますが、自分以外には公開しません。"; case .unlisted: "検索やマップには出さず、専用URLを知る人だけが見られます。"; case .public: "公開場所としてマップとDiscoverに表示されます。位置情報と安全確認が必要です。" } }
}

struct ScanLabProfile: Decodable, Hashable {
    let id: UUID; let handle: String; let displayName: String; let avatarPath: String?
    enum CodingKeys: String, CodingKey { case id, handle; case displayName = "display_name"; case avatarPath = "avatar_path" }
}
private struct ScanLabProfileUpdate: Encodable { let handle: String; let displayName: String; enum CodingKeys: String, CodingKey { case handle; case displayName = "display_name" } }
struct ScanLabBlockedUser: Decodable, Identifiable, Hashable { let blockedId: UUID; let createdAt: String; var id: UUID { blockedId }; enum CodingKeys: String, CodingKey { case blockedId = "blocked_id"; case createdAt = "created_at" } }

struct ScanLabOwnerScan: Decodable, Identifiable, Hashable {
    let id: UUID; let title: String; let caption: String; let visibility: String; let status: String; let moderationStatus: String; let shareToken: UUID; let assetPath: String; let previewPath: String?; let latitude: Double?; let longitude: Double?; let locationLabel: String?; let publishedAt: String?; let createdAt: String
    enum CodingKeys: String, CodingKey { case id, title, caption, visibility, status; case moderationStatus = "moderation_status"; case shareToken = "share_token"; case assetPath = "asset_path"; case previewPath = "preview_path"; case latitude, longitude; case locationLabel = "location_label"; case publishedAt = "published_at"; case createdAt = "created_at" }
}

private struct ScanLabCreatedScan: Decodable { let id: UUID }
private struct ScanLabDraftInsert: Encodable {
    let ownerId: UUID; let title: String; let caption: String; let visibility: String; let status: String; let assetPath: String; let previewPath: String?; let latitude: Double?; let longitude: Double?; let locationLabel: String?; let publicPlaceConfirmed: Bool; let privacyConfirmed: Bool; let rightsConfirmed: Bool; let contentConfirmed: Bool
    enum CodingKeys: String, CodingKey { case ownerId = "owner_id"; case title, caption, visibility, status; case assetPath = "asset_path"; case previewPath = "preview_path"; case latitude, longitude; case locationLabel = "location_label"; case publicPlaceConfirmed = "public_place_confirmed"; case privacyConfirmed = "privacy_confirmed"; case rightsConfirmed = "rights_confirmed"; case contentConfirmed = "content_confirmed" }
}
struct ScanLabPublishResponse: Decodable, Hashable { let id: UUID; let visibility: String; let publishedAt: String?; let shareUrl: URL? }
private struct ScanLabPublishRequest: Encodable { let scanId: String }
private struct ScanLabDeleteAccountResponse: Decodable { let deleted: Bool }
private struct ScanLabScanStatusUpdate: Encodable { let status: String }
private struct ScanLabLikeInsert: Encodable { let scanId: UUID; let userId: UUID; enum CodingKeys: String, CodingKey { case scanId = "scan_id"; case userId = "user_id" } }
private struct ScanLabReportInsert: Encodable { let scanId: UUID; let reporterId: UUID; let reason: String; let details: String; enum CodingKeys: String, CodingKey { case scanId = "scan_id"; case reporterId = "reporter_id"; case reason, details } }
private struct ScanLabBlockInsert: Encodable { let blockerId: UUID; let blockedId: UUID; enum CodingKeys: String, CodingKey { case blockerId = "blocker_id"; case blockedId = "blocked_id" } }

enum ScanLabBackendError: LocalizedError {
    case signInRequired, invalidTitle, invalidPublicLocation, safetyConfirmationRequired, contentConfirmationRequired, invalidAsset, invalidProfile, invalidBlockTarget, assetTooLarge, invalidServerResponse
    var errorDescription: String? { switch self { case .signInRequired: "公開・クラウド保存にはログインが必要です。"; case .invalidTitle: "タイトルを1〜80文字で入力してください。"; case .invalidPublicLocation: "マップ公開には位置情報が必要です。"; case .safetyConfirmationRequired: "公開場所・プライバシー・権利の3項目を確認してください。"; case .contentConfirmationRequired: "共有前にコンテンツ安全性の確認が必要です。"; case .invalidAsset: "3Dデータを読み込めませんでした。"; case .invalidProfile: "表示名は1〜40文字、ユーザーIDは英小文字・数字・_ の3〜24文字で入力してください。"; case .invalidBlockTarget: "このユーザーはブロックできません。"; case .assetTooLarge: "3Dデータが128MBを超えています。"; case .invalidServerResponse: "サーバーから正しい応答を受け取れませんでした。" } }
}

enum ScanLabConfig {
    static let supabaseURL = URL(string: "https://gybchnyqlqwmajwkhsly.supabase.co")!
    static let publishableKey = "sb_publishable_jYM9b6kivVT80sbAQ2syFw_zSUANBHV"
    static let publicFunctionURL = URL(string: "https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public")!
    static let viewerBaseURL = URL(string: "https://allsunday1122.github.io/splat-native-ios/viewer/")!
    static let supportURL = URL(string: "https://allsunday1122.github.io/splat-native-ios/support.html")!
    static let maximumAssetBytes = 128 * 1024 * 1024
}

@MainActor final class ScanLabBackend: ObservableObject {
    let client: SupabaseClient
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var publicScans: [ScanLabPublicScan] = []
    @Published private(set) var ownerScans: [ScanLabOwnerScan] = []
    @Published private(set) var blockedUsers: [ScanLabBlockedUser] = []
    @Published private(set) var profile: ScanLabProfile?
    @Published private(set) var isLoadingPublic = false
    @Published private(set) var isLoadingOwner = false
    @Published var notice: String?

    init() { client = SupabaseClient(supabaseURL: ScanLabConfig.supabaseURL, supabaseKey: ScanLabConfig.publishableKey); Task { [weak self] in await self?.observeAuth() } }
    private func observeAuth() async {
        for await state in client.auth.authStateChanges {
            guard [.initialSession, .signedIn, .signedOut, .userUpdated].contains(state.event) else { continue }
            isAuthenticated = state.session != nil; currentUserEmail = state.session?.user.email
            if state.session == nil { ownerScans = []; blockedUsers = []; profile = nil; await loadPublicScans() }
            else { async let scans: Void = loadOwnerScans(); async let loadedProfile: Void = loadProfile(); async let blocks: Void = loadBlockedUsers(); _ = await (scans, loadedProfile, blocks); await loadPublicScans() }
        }
    }
    func signUp(email: String, password: String) async throws { let response = try await client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password); notice = response.session == nil ? "確認メールを送信しました。メール内のリンクで登録を完了してください。" : "アカウントを作成しました。" }
    func signIn(email: String, password: String) async throws { try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password); notice = nil }
    func signOut() async { do { try await client.auth.signOut() } catch { notice = error.localizedDescription } }

    func loadPublicScans(boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = nil) async {
        guard !isLoadingPublic else { return }; isLoadingPublic = true; defer { isLoadingPublic = false }
        do {
            var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
            var items = [URLQueryItem(name: "mode", value: "feed"), URLQueryItem(name: "limit", value: "40")]
            if let boundingBox { items += [URLQueryItem(name: "minLat", value: String(boundingBox.minLat)), URLQueryItem(name: "maxLat", value: String(boundingBox.maxLat)), URLQueryItem(name: "minLon", value: String(boundingBox.minLon)), URLQueryItem(name: "maxLon", value: String(boundingBox.maxLon))] }
            components.queryItems = items; guard let url = components.url else { throw ScanLabBackendError.invalidServerResponse }
            var request = URLRequest(url: url); request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let session = try? await client.auth.session { request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization") }
            let (data, response) = try await URLSession.shared.data(for: request); guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw ScanLabBackendError.invalidServerResponse }
            publicScans = try JSONDecoder().decode(ScanLabPublicEnvelope.self, from: data).items
        } catch { notice = "公開スキャンを取得できませんでした: \(error.localizedDescription)" }
    }
    func loadProfile() async { guard isAuthenticated, let session = try? await client.auth.session else { return }; do { profile = try await client.from("scanlab_profiles").select("id,handle,display_name,avatar_path").eq("id", value: session.user.id).single().execute().value } catch { notice = "プロフィールを取得できませんでした: \(error.localizedDescription)" } }
    func updateProfile(handle: String, displayName: String) async throws { let h = handle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), n = displayName.trimmingCharacters(in: .whitespacesAndNewlines); let re = try NSRegularExpression(pattern: "^[a-z0-9_]{3,24}$"), range = NSRange(h.startIndex..., in: h); guard re.firstMatch(in: h, range: range) != nil, (1...40).contains(n.count) else { throw ScanLabBackendError.invalidProfile }; guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; try await client.from("scanlab_profiles").update(ScanLabProfileUpdate(handle: h, displayName: n)).eq("id", value: session.user.id).execute(); await loadProfile() }
    func loadOwnerScans() async { guard isAuthenticated, !isLoadingOwner else { return }; isLoadingOwner = true; defer { isLoadingOwner = false }; do { ownerScans = try await client.from("scanlab_scans").select("id,title,caption,visibility,status,moderation_status,share_token,asset_path,preview_path,latitude,longitude,location_label,published_at,created_at").order("created_at", ascending: false).execute().value } catch { notice = "自分のスキャンを取得できませんでした: \(error.localizedDescription)" } }
    func loadBlockedUsers() async { guard isAuthenticated else { blockedUsers = []; return }; do { blockedUsers = try await client.from("scanlab_blocks").select("blocked_id,created_at").order("created_at", ascending: false).execute().value } catch { notice = "ブロック一覧を取得できませんでした: \(error.localizedDescription)" } }

    func publish(resultURL: URL, previewImage: UIImage?, title: String, caption: String, visibility: ScanLabVisibility, location: ScanLabLocation?, publicPlaceConfirmed: Bool, privacyConfirmed: Bool, rightsConfirmed: Bool, contentConfirmed: Bool) async throws -> ScanLabPublishResponse {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines); guard (1...80).contains(trimmedTitle.count) else { throw ScanLabBackendError.invalidTitle }; guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; let user = session.user
        if visibility != .private && !contentConfirmed { throw ScanLabBackendError.contentConfirmationRequired }; if visibility == .public { guard location != nil else { throw ScanLabBackendError.invalidPublicLocation }; guard publicPlaceConfirmed, privacyConfirmed, rightsConfirmed else { throw ScanLabBackendError.safetyConfirmationRequired } }
        let attributes = try FileManager.default.attributesOfItem(atPath: resultURL.path); guard let size = attributes[.size] as? NSNumber, size.intValue > 0 else { throw ScanLabBackendError.invalidAsset }; guard size.intValue <= ScanLabConfig.maximumAssetBytes else { throw ScanLabBackendError.assetTooLarge }
        let uploadID = UUID().uuidString.lowercased(), prefix = "\(user.id.uuidString.lowercased())/\(uploadID)", assetPath = "\(prefix)/result.splat", previewPath = previewImage == nil ? nil : "\(prefix)/preview.jpg"; var uploadedPaths: [String] = []
        do { try await client.storage.from("scanlab-assets").upload(assetPath, fileURL: resultURL, options: FileOptions(contentType: "application/octet-stream")); uploadedPaths.append(assetPath); if let previewPath, let previewData = previewImage?.jpegData(compressionQuality: 0.82) { try await client.storage.from("scanlab-assets").upload(previewPath, data: previewData, options: FileOptions(contentType: "image/jpeg")); uploadedPaths.append(previewPath) }; let draft = ScanLabDraftInsert(ownerId: user.id, title: trimmedTitle, caption: String(caption.prefix(500)), visibility: visibility.rawValue, status: "draft", assetPath: assetPath, previewPath: previewPath, latitude: location?.latitude, longitude: location?.longitude, locationLabel: location?.label, publicPlaceConfirmed: publicPlaceConfirmed, privacyConfirmed: privacyConfirmed, rightsConfirmed: rightsConfirmed, contentConfirmed: contentConfirmed); let created: ScanLabCreatedScan = try await client.from("scanlab_scans").insert(draft).select("id").single().execute().value; let published: ScanLabPublishResponse = try await client.functions.invoke("scanlab-publish", options: FunctionInvokeOptions(region: .apSoutheast1, body: ScanLabPublishRequest(scanId: created.id.uuidString.lowercased()), timeoutInterval: 30)); await loadOwnerScans(); if visibility == .public { await loadPublicScans() }; return published } catch { if !uploadedPaths.isEmpty { try? await client.storage.from("scanlab-assets").remove(paths: uploadedPaths) }; throw error }
    }
    func unpublish(_ scan: ScanLabOwnerScan) async throws { try await client.from("scanlab_scans").update(ScanLabScanStatusUpdate(status: "hidden")).eq("id", value: scan.id).execute(); await loadOwnerScans(); await loadPublicScans() }
    func delete(_ scan: ScanLabOwnerScan) async throws { let paths = [scan.assetPath, scan.previewPath].compactMap { $0 }; if !paths.isEmpty { try await client.storage.from("scanlab-assets").remove(paths: paths) }; try await client.from("scanlab_scans").delete().eq("id", value: scan.id).execute(); await loadOwnerScans(); await loadPublicScans() }
    func like(_ scan: ScanLabPublicScan) async throws { guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; try await client.from("scanlab_likes").insert(ScanLabLikeInsert(scanId: scan.id, userId: session.user.id)).execute(); await loadPublicScans() }
    func report(_ scan: ScanLabPublicScan, reason: String) async throws { guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; try await client.from("scanlab_reports").insert(ScanLabReportInsert(scanId: scan.id, reporterId: session.user.id, reason: reason, details: "")).execute(); notice = "報告を受け付け、公開3Dを確認のため非表示にしました。"; await loadPublicScans() }
    func block(_ scan: ScanLabPublicScan) async throws { guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; guard let author = scan.author, author.id != session.user.id else { throw ScanLabBackendError.invalidBlockTarget }; do { try await client.from("scanlab_blocks").insert(ScanLabBlockInsert(blockerId: session.user.id, blockedId: author.id)).execute() } catch { let message = error.localizedDescription.lowercased(); if !message.contains("duplicate") && !message.contains("unique") { throw error } }; notice = "このユーザーをブロックしました。お互いの投稿と新しい操作を非表示にします。"; await loadBlockedUsers(); await loadPublicScans() }
    func unblock(_ blockedUser: ScanLabBlockedUser) async throws { guard let session = try? await client.auth.session else { throw ScanLabBackendError.signInRequired }; try await client.from("scanlab_blocks").delete().eq("blocker_id", value: session.user.id).eq("blocked_id", value: blockedUser.blockedId).execute(); notice = "ブロックを解除しました。"; await loadBlockedUsers(); await loadPublicScans() }
    func deleteAccount() async throws { let response: ScanLabDeleteAccountResponse = try await client.functions.invoke("scanlab-delete-account", options: FunctionInvokeOptions(region: .apSoutheast1, body: ["confirm": true], timeoutInterval: 30)); guard response.deleted else { throw ScanLabBackendError.invalidServerResponse }; try? await client.auth.signOut() }
    func shareURL(for scan: ScanLabOwnerScan) -> URL? { guard scan.status == "published", scan.moderationStatus == "approved" else { return nil }; var components = URLComponents(url: ScanLabConfig.viewerBaseURL, resolvingAgainstBaseURL: false)!; switch scan.visibility { case ScanLabVisibility.public.rawValue: components.queryItems = [URLQueryItem(name: "id", value: scan.id.uuidString.lowercased())]; case ScanLabVisibility.unlisted.rawValue: components.queryItems = [URLQueryItem(name: "token", value: scan.shareToken.uuidString.lowercased())]; default: return nil }; return components.url }
}
