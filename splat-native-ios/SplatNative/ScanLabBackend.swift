import Combine
import Foundation
@preconcurrency import Supabase
import UIKit

struct ScanLabLocation: Codable, Hashable {
    let latitude: Double
    let longitude: Double
    let label: String?
}

struct ScanLabAuthor: Codable, Hashable {
    let id: UUID
    let handle: String
    let displayName: String
}

struct ScanLabPublicScan: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let caption: String
    let visibility: String
    let publishedAt: String?
    let location: ScanLabLocation?
    let author: ScanLabAuthor?
    let likeCount: Int
    let modelUrl: URL?
    let previewUrl: URL?
    let previewImageUrl: URL?
}

struct ScanLabPublicEnvelope: Decodable { let items: [ScanLabPublicScan] }

enum ScanLabVisibility: String, CaseIterable, Identifiable, Codable {
    case `private`
    case unlisted
    case `public`
    var id: String { rawValue }
    var title: String {
        switch self {
        case .private: "非公開"
        case .unlisted: "リンクを知っている人のみ"
        case .public: "Discoverに公開"
        }
    }
    var explanation: String {
        switch self {
        case .private: "クラウドへ保存しますが、自分以外には公開しません。"
        case .unlisted: "検索やマップには出さず、専用URLを知る人だけが見られます。"
        case .public: "Discoverに公開します。位置情報を明示的に付与した場合だけMapにも表示されます。"
        }
    }
}

struct ScanLabProfile: Decodable, Hashable {
    let id: UUID
    let handle: String
    let displayName: String
    let avatarPath: String?
    enum CodingKeys: String, CodingKey {
        case id, handle
        case displayName = "display_name"
        case avatarPath = "avatar_path"
    }
}

private struct ScanLabProfileUpdate: Encodable {
    let handle: String
    let displayName: String
    enum CodingKeys: String, CodingKey {
        case handle
        case displayName = "display_name"
    }
}

struct ScanLabBlockedUser: Decodable, Identifiable, Hashable {
    let blockedId: UUID
    let createdAt: String
    var id: UUID { blockedId }
    enum CodingKeys: String, CodingKey {
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}

struct ScanLabOwnerScan: Decodable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let caption: String
    let visibility: String
    let status: String
    let moderationStatus: String
    let shareToken: UUID
    let assetPath: String
    let previewPath: String?
    let latitude: Double?
    let longitude: Double?
    let locationLabel: String?
    let publishedAt: String?
    let createdAt: String
    enum CodingKeys: String, CodingKey {
        case id, title, caption, visibility, status
        case moderationStatus = "moderation_status"
        case shareToken = "share_token"
        case assetPath = "asset_path"
        case previewPath = "preview_path"
        case latitude, longitude
        case locationLabel = "location_label"
        case publishedAt = "published_at"
        case createdAt = "created_at"
    }
}

struct ScanLabPublishResponse: Decodable, Hashable {
    let id: UUID
    let visibility: String
    let publishedAt: String?
    let shareUrl: URL?
}

private struct ScanLabPublishRequest: Encodable {
    let scanId: String
    let title: String?
    let description: String?
    init(scanId: String, title: String? = nil, description: String? = nil) {
        self.scanId = scanId
        self.title = title
        self.description = description
    }
}

private struct ScanLabDeleteAccountResponse: Decodable { let deleted: Bool }
private struct ScanLabDeleteScanResponse: Decodable { let deleted: Bool; let scanId: UUID }
private struct ScanLabLikeInsert: Encodable {
    let scanId: UUID
    let userId: UUID
    enum CodingKeys: String, CodingKey { case scanId = "scan_id"; case userId = "user_id" }
}
private struct ScanLabBlockInsert: Encodable {
    let blockerId: UUID
    let blockedId: UUID
    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}

enum ScanLabBackendError: LocalizedError {
    case signInRequired, invalidTitle, invalidPublicLocation, safetyConfirmationRequired, contentConfirmationRequired, invalidAsset, invalidProfile, invalidBlockTarget, assetTooLarge, invalidServerResponse
    var errorDescription: String? {
        switch self {
        case .signInRequired: "公開・クラウド保存にはログインが必要です。"
        case .invalidTitle: "タイトルを1〜80文字で入力してください。"
        case .invalidPublicLocation: "位置情報を付与する場合は有効な公開地点を指定してください。"
        case .safetyConfirmationRequired: "公開前にプライバシーと権利を確認してください。位置情報を付与する場合は公開可能な場所であることも確認してください。"
        case .contentConfirmationRequired: "共有前にコンテンツ安全性の確認が必要です。"
        case .invalidAsset: "3Dデータを読み込めませんでした。"
        case .invalidProfile: "表示名は1〜40文字、ユーザーIDは英小文字・数字・_ の3〜24文字で入力してください。"
        case .invalidBlockTarget: "このユーザーはブロックできません。"
        case .assetTooLarge: "3Dデータが128MBを超えています。"
        case .invalidServerResponse: "サーバーから正しい応答を受け取れませんでした。"
        }
    }
}

enum ScanLabConfig {
    static let supabaseURL = URL(string: "https://gybchnyqlqwmajwkhsly.supabase.co")!
    static let publishableKey = "sb_publishable_jYM9b6kivVT80sbAQ2syFw_zSUANBHV"
    static let publicFunctionURL = URL(string: "https://gybchnyqlqwmajwkhsly.supabase.co/functions/v1/scanlab-public")!
    static let viewerBaseURL = URL(string: "https://allsunday1122.github.io/splat-native-ios/viewer/")!
    static let supportURL = URL(string: "https://allsunday1122.github.io/splat-native-ios/support.html")!
    static let maximumAssetBytes = 128 * 1024 * 1024
}

@MainActor
final class ScanLabBackend: ObservableObject {
    let client: SupabaseClient
    @Published private(set) var authPhase: ScanLabAuthPhase = .resolving
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var publicScans: [ScanLabPublicScan] = []
    @Published private(set) var ownerScans: [ScanLabOwnerScan] = []
    @Published private(set) var blockedUsers: [ScanLabBlockedUser] = []
    @Published private(set) var profile: ScanLabProfile?
    @Published private(set) var isLoadingPublic = false
    @Published private(set) var isLoadingOwner = false
    @Published var notice: String?

    init() {
        client = SupabaseClient(supabaseURL: ScanLabConfig.supabaseURL, supabaseKey: ScanLabConfig.publishableKey)
        Task { [weak self] in await self?.observeAuth() }
    }

    private func observeAuth() async {
        var waitingForInitialRefresh = false
        for await state in client.auth.authStateChanges {
            let event: ScanLabSessionEvent
            let signal: ScanLabAuthSignal
            switch state.event {
            case .initialSession:
                event = .initialSession(hasSession: state.session != nil, isExpired: state.session?.isExpired ?? false)
                signal = .sessionResolved(hasSession: state.session != nil)
                waitingForInitialRefresh = ScanLabSessionPolicy.needsRefreshBeforePrivateData(after: event)
            case .signedIn, .mfaChallengeVerified:
                event = .signedIn
                signal = .sessionResolved(hasSession: state.session != nil)
            case .signedOut, .userDeleted:
                event = .signedOut
                signal = .signedOut
                waitingForInitialRefresh = false
            case .tokenRefreshed:
                event = .tokenRefreshed
                signal = .sessionResolved(hasSession: state.session != nil)
            case .userUpdated:
                event = .userUpdated
                signal = .sessionResolved(hasSession: state.session != nil)
            case .passwordRecovery:
                event = .passwordRecovery
                signal = .sessionResolved(hasSession: state.session != nil)
            }

            authPhase = ScanLabAuthStatePolicy.reduce(current: authPhase, signal: signal)

            if let session = state.session, ScanLabSessionPolicy.isAuthenticated(after: event) {
                applyAuthenticatedSession(session)
                let shouldHydrate = ScanLabSessionPolicy.shouldReloadPrivateData(after: event)
                    || (event == .tokenRefreshed && waitingForInitialRefresh)
                if shouldHydrate {
                    waitingForInitialRefresh = false
                    async let scans: Void = loadOwnerScans()
                    async let loadedProfile: Void = loadProfile()
                    async let blocks: Void = loadBlockedUsers()
                    _ = await (scans, loadedProfile, blocks)
                    await loadPublicScans()
                }
            } else {
                waitingForInitialRefresh = false
                clearAuthenticatedState(requireSignInNotice: false)
                if event == .signedOut { await loadPublicScans() }
            }
        }
    }

    private func applyAuthenticatedSession(_ session: Session) {
        authPhase = .signedIn
        isAuthenticated = true
        currentUserEmail = session.user.email
    }

    private func clearAuthenticatedState(requireSignInNotice: Bool) {
        authPhase = .signedOut
        isAuthenticated = false
        currentUserEmail = nil
        ownerScans = []
        blockedUsers = []
        profile = nil
        if requireSignInNotice { notice = "ログインの有効期限が切れました。もう一度ログインしてください。" }
    }

    private func authenticatedSession() async throws -> Session {
        do {
            let session = try await client.auth.session
            applyAuthenticatedSession(session)
            return session
        } catch {
            switch ScanLabSessionPolicy.recoveryDecision(hasCachedSessionAfterFailure: client.auth.currentSession != nil) {
            case .keepAuthenticatedAndRetry:
                notice = "ログイン状態を更新できませんでした。通信状態を確認して再試行してください。"
                throw error
            case .requireSignIn:
                clearAuthenticatedState(requireSignInNotice: true)
                throw ScanLabBackendError.signInRequired
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        notice = response.session == nil ? "確認メールを送信しました。メール内のリンクで登録を完了してください。" : "アカウントを作成しました。"
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
        notice = nil
    }

    func signOut() async {
        do { try await client.auth.signOut() }
        catch { notice = error.localizedDescription }
    }

    func loadPublicScans(boundingBox: (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double)? = nil) async {
        guard !isLoadingPublic else { return }
        isLoadingPublic = true
        defer { isLoadingPublic = false }
        do {
            var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
            var items = [URLQueryItem(name: "mode", value: "feed"), URLQueryItem(name: "limit", value: "40")]
            if let boundingBox {
                items += [
                    URLQueryItem(name: "minLat", value: String(boundingBox.minLat)),
                    URLQueryItem(name: "maxLat", value: String(boundingBox.maxLat)),
                    URLQueryItem(name: "minLon", value: String(boundingBox.minLon)),
                    URLQueryItem(name: "maxLon", value: String(boundingBox.maxLon))
                ]
            }
            components.queryItems = items
            guard let url = components.url else { throw ScanLabBackendError.invalidServerResponse }
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let session = try? await client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw ScanLabBackendError.invalidServerResponse }
            publicScans = try JSONDecoder().decode(ScanLabPublicEnvelope.self, from: data).items
        } catch {
            notice = "公開スキャンを取得できませんでした: \(error.localizedDescription)"
        }
    }

    func loadProfile() async {
        guard isAuthenticated else { return }
        do {
            let session = try await authenticatedSession()
            let row: ScanLabProfile = try await client.from("scanlab_profiles").select("id,handle,display_name,avatar_path").eq("id", value: session.user.id).single().execute().value
            profile = row
        } catch {
            if !isAuthenticated { return }
            notice = "プロフィールを取得できませんでした: \(error.localizedDescription)"
        }
    }

    func updateProfile(handle: String, displayName: String) async throws {
        let h = ScanLabProfilePolicy.normalizedHandle(handle)
        let n = ScanLabProfilePolicy.normalizedDisplayName(displayName)
        guard ScanLabProfilePolicy.validate(handle: h, displayName: n, bio: "", avatarURL: "") else { throw ScanLabBackendError.invalidProfile }
        let session = try await authenticatedSession()
        do {
            try await client.from("scanlab_profiles").update(ScanLabProfileUpdate(handle: h, displayName: n)).eq("id", value: session.user.id).execute()
        } catch let error as PostgrestError where ScanLabProfilePolicy.mapsToHandleUnavailable(postgrestCode: error.code) {
            throw ScanLabProfileUpdateError.handleUnavailable
        }
        await loadProfile()
    }

    func loadOwnerScans() async {
        guard isAuthenticated, !isLoadingOwner else { return }
        isLoadingOwner = true
        defer { isLoadingOwner = false }
        do {
            _ = try await authenticatedSession()
            let rows: [ScanLabOwnerScan] = try await client.from("scanlab_scans").select("id,title,caption,visibility,status,moderation_status,share_token,asset_path,preview_path,latitude,longitude,location_label,published_at,created_at").order("created_at", ascending: false).execute().value
            ownerScans = rows
        } catch {
            if !isAuthenticated { return }
            notice = "自分のスキャンを取得できませんでした: \(error.localizedDescription)"
        }
    }

    func loadBlockedUsers() async {
        guard isAuthenticated else { blockedUsers = []; return }
        do {
            _ = try await authenticatedSession()
            let rows: [ScanLabBlockedUser] = try await client.from("scanlab_blocks").select("blocked_id,created_at").order("created_at", ascending: false).execute().value
            blockedUsers = rows
        } catch {
            if !isAuthenticated { return }
            notice = "ブロック一覧を取得できませんでした: \(error.localizedDescription)"
        }
    }

    @available(*, deprecated, message: "Use publishTrustedPackage; retained as a secure compatibility shim.")
    func publish(resultURL: URL, previewImage: UIImage?, title: String, caption: String, visibility: ScanLabVisibility, location: ScanLabLocation?, publicPlaceConfirmed: Bool, privacyConfirmed: Bool, rightsConfirmed: Bool, contentConfirmed: Bool) async throws -> ScanLabPublishResponse {
        try await publishTrustedPackage(resultURL: resultURL, previewImage: previewImage, title: title, caption: caption, visibility: visibility, location: location, publicPlaceConfirmed: publicPlaceConfirmed, privacyConfirmed: privacyConfirmed, rightsConfirmed: rightsConfirmed, contentConfirmed: contentConfirmed)
    }

    func updatePublishedMetadata(_ scan: ScanLabOwnerScan, title: String, caption: String) async throws {
        guard scan.status == "published" else { throw ScanLabBackendError.invalidServerResponse }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...80).contains(trimmedTitle.count) else { throw ScanLabBackendError.invalidTitle }
        _ = try await authenticatedSession()
        let request = ScanLabPublishRequest(scanId: scan.id.uuidString.lowercased(), title: trimmedTitle, description: String(caption.prefix(500)))
        let response: ScanLabPublishResponse = try await client.functions.invoke("scanlab-publish", options: FunctionInvokeOptions(region: .apSoutheast1, body: request, timeoutInterval: 30))
        guard response.id == scan.id else { throw ScanLabBackendError.invalidServerResponse }
        await loadOwnerScans()
        if scan.visibility == ScanLabVisibility.public.rawValue { await loadPublicScans() }
    }

    func unpublish(_ scan: ScanLabOwnerScan) async throws {
        try await unpublishPublishedScan(scan)
    }

    func delete(_ scan: ScanLabOwnerScan) async throws {
        _ = try await authenticatedSession()
        let response: ScanLabDeleteScanResponse = try await client.functions.invoke(
            "scanlab-delete-scan",
            options: FunctionInvokeOptions(region: .apSoutheast1, body: ScanLabPublishRequest(scanId: scan.id.uuidString.lowercased()), timeoutInterval: 30)
        )
        guard response.deleted, response.scanId == scan.id else { throw ScanLabBackendError.invalidServerResponse }
        await loadOwnerScans()
        await loadPublicScans()
    }

    func like(_ scan: ScanLabPublicScan) async throws {
        let session = try await authenticatedSession()
        try await client.from("scanlab_likes").insert(ScanLabLikeInsert(scanId: scan.id, userId: session.user.id)).execute()
        await loadPublicScans()
    }

    func report(_ scan: ScanLabPublicScan, reason: String) async throws {
        let mapped = ScanReportReason(rawValue: reason) ?? .other
        _ = try await submitReport(scan, reason: mapped)
        await loadPublicScans()
    }

    func block(_ scan: ScanLabPublicScan) async throws {
        let session = try await authenticatedSession()
        guard let author = scan.author, author.id != session.user.id else { throw ScanLabBackendError.invalidBlockTarget }
        do {
            try await client.from("scanlab_blocks").insert(ScanLabBlockInsert(blockerId: session.user.id, blockedId: author.id)).execute()
        } catch {
            let message = error.localizedDescription.lowercased()
            if !message.contains("duplicate") && !message.contains("unique") { throw error }
        }
        notice = "このユーザーをブロックしました。お互いの公開投稿と新しい操作を非表示にします。"
        await loadBlockedUsers()
        await loadPublicScans()
    }

    func unblock(_ blockedUser: ScanLabBlockedUser) async throws {
        let session = try await authenticatedSession()
        try await client.from("scanlab_blocks").delete().eq("blocker_id", value: session.user.id).eq("blocked_id", value: blockedUser.blockedId).execute()
        notice = "ブロックを解除しました。"
        await loadBlockedUsers()
        await loadPublicScans()
    }

    func deleteAccount() async throws {
        _ = try await authenticatedSession()
        let response: ScanLabDeleteAccountResponse = try await client.functions.invoke("scanlab-delete-account", options: FunctionInvokeOptions(region: .apSoutheast1, body: ["confirm": true], timeoutInterval: 30))
        guard response.deleted else { throw ScanLabBackendError.invalidServerResponse }
        clearAuthenticatedState(requireSignInNotice: false)
        try? await client.auth.signOut()
    }

    func shareURL(for scan: ScanLabOwnerScan) -> URL? {
        guard scan.status == "published", scan.moderationStatus == "approved" else { return nil }
        var components = URLComponents(url: ScanLabConfig.viewerBaseURL, resolvingAgainstBaseURL: false)!
        switch scan.visibility {
        case ScanLabVisibility.public.rawValue:
            components.queryItems = [URLQueryItem(name: "id", value: scan.id.uuidString.lowercased())]
        case ScanLabVisibility.unlisted.rawValue:
            components.queryItems = nil
            components.fragment = "token=\(scan.shareToken.uuidString.lowercased())"
        default:
            return nil
        }
        return components.url
    }
}
