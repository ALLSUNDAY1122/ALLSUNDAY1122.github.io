import Combine
import Foundation

private struct ScanLabDiscoverEnvelope: Decodable {
    let items: [ScanLabPublicScan]
    let nextCursor: String?
}

@MainActor
final class ScanLabDiscoverStore: ObservableObject {
    @Published private(set) var scans: [ScanLabPublicScan] = []
    @Published private(set) var nextCursor: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    func loadInitialIfNeeded(backend: ScanLabBackend) async {
        guard !hasLoaded else { return }
        await reload(backend: backend)
    }

    func reload(backend: ScanLabBackend) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let page = try await requestPage(cursor: nil, backend: backend)
            scans = page.items
            nextCursor = page.nextCursor
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(backend: ScanLabBackend) async {
        guard !isLoading, let cursor = nextCursor else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await requestPage(cursor: cursor, backend: backend)
            let existing = Set(scans.map(\.id))
            scans.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            if page.nextCursor == cursor {
                nextCursor = nil
                errorMessage = "Discoverの続きを安全に取得できなかったため、読み込みを停止しました。"
            } else {
                nextCursor = page.nextCursor
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestPage(cursor: String?, backend: ScanLabBackend) async throws -> ScanLabDiscoverEnvelope {
        var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "mode", value: "feed"),
            URLQueryItem(name: "limit", value: "24"),
        ]
        if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
        components.queryItems = items
        guard let url = components.url else { throw ScanLabBackendError.invalidServerResponse }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        if let session = try? await backend.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ScanLabBackendError.invalidServerResponse
        }
        return try JSONDecoder().decode(ScanLabDiscoverEnvelope.self, from: data)
    }
}
