import Combine
import Foundation

private struct ScanLabDiscoverEnvelope: Decodable {
    let items: [ScanLabPublicScan]
    let nextCursor: String?
}

private enum ScanLabDiscoverAuthScope: Equatable {
    case unresolved
    case anonymous
    case user(UUID)
}

@MainActor
final class ScanLabDiscoverStore: ObservableObject {
    @Published private(set) var scans: [ScanLabPublicScan] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = true
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private var authScope: ScanLabDiscoverAuthScope = .unresolved
    private var bearerToken: String?
    private var requestGeneration = 0

    func observeAuthAndLoad(backend: ScanLabBackend) async {
        for await state in backend.client.auth.authStateChanges {
            if Task.isCancelled { return }
            let scope = state.session.map { ScanLabDiscoverAuthScope.user($0.user.id) } ?? .anonymous
            await synchronizeAuthSession(scope: scope, bearerToken: state.session?.accessToken)
        }
    }

    func reload() async {
        guard authScope != .unresolved else { return }
        await reload(scope: authScope)
    }

    func loadMore() async {
        guard !isLoading, let cursor = nextCursor, authScope != .unresolved else { return }
        let scope = authScope
        let token = bearerToken
        let generation = beginRequest()
        defer {
            if isCurrent(generation: generation, scope: scope) {
                isLoading = false
            }
        }

        do {
            let page = try await requestPage(cursor: cursor, bearerToken: token)
            guard isCurrent(generation: generation, scope: scope) else { return }

            let existing = Set(scans.map(\.id))
            scans.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            if page.nextCursor == cursor {
                nextCursor = nil
                errorMessage = "Discoverの続きを安全に取得できなかったため、読み込みを停止しました。"
            } else {
                nextCursor = page.nextCursor
            }
        } catch {
            guard isCurrent(generation: generation, scope: scope) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func synchronizeAuthSession(scope: ScanLabDiscoverAuthScope, bearerToken: String?) async {
        let changed = scope != authScope
        self.bearerToken = bearerToken

        if changed {
            authScope = scope
            requestGeneration += 1
            scans = []
            nextCursor = nil
            errorMessage = nil
            hasLoaded = false
            isLoading = false
        }

        guard changed || (!hasLoaded && !isLoading) else { return }
        await reload(scope: scope)
    }

    private func reload(scope: ScanLabDiscoverAuthScope) async {
        guard scope == authScope else { return }
        let token = bearerToken
        let generation = beginRequest()
        defer {
            if isCurrent(generation: generation, scope: scope) {
                isLoading = false
                hasLoaded = true
            }
        }

        do {
            let page = try await requestPage(cursor: nil, bearerToken: token)
            guard isCurrent(generation: generation, scope: scope) else { return }
            scans = page.items
            nextCursor = page.nextCursor
        } catch {
            guard isCurrent(generation: generation, scope: scope) else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func beginRequest() -> Int {
        requestGeneration += 1
        isLoading = true
        errorMessage = nil
        return requestGeneration
    }

    private func isCurrent(generation: Int, scope: ScanLabDiscoverAuthScope) -> Bool {
        generation == requestGeneration && scope == authScope
    }

    private func requestPage(cursor: String?, bearerToken: String?) async throws -> ScanLabDiscoverEnvelope {
        var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "mode", value: "feed"),
            URLQueryItem(name: "limit", value: "24"),
            URLQueryItem(name: "includeModel", value: "0"),
        ]
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        components.queryItems = items
        guard let url = components.url else { throw ScanLabBackendError.invalidServerResponse }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ScanLabBackendError.invalidServerResponse
        }
        let envelope = try JSONDecoder().decode(ScanLabDiscoverEnvelope.self, from: data)
        guard envelope.items.allSatisfy({ $0.modelUrl == nil }) else {
            throw ScanLabBackendError.invalidServerResponse
        }
        return envelope
    }
}
