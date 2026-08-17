import Combine
import Foundation

private struct ScanLabDiscoverEnvelope: Decodable {
    let items: [ScanLabPublicScan]
    let nextOffset: Int?
    let hasMore: Bool
}

@MainActor
final class ScanLabDiscoverFeedStore: ObservableObject {
    @Published var query = ""
    @Published private(set) var items: [ScanLabPublicScan] = []
    @Published private(set) var isLoadingInitial = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var hasMore = true
    @Published private(set) var errorMessage: String?

    private let pageSize = 20
    private var nextOffset = 0
    private var generation = UUID()

    func reload(using backend: ScanLabBackend) async {
        generation = UUID()
        let requestGeneration = generation
        nextOffset = 0
        hasMore = true
        errorMessage = nil
        isLoadingInitial = true
        defer {
            if generation == requestGeneration { isLoadingInitial = false }
        }

        do {
            let page = try await fetchVisiblePage(startingAt: 0, using: backend)
            guard generation == requestGeneration else { return }
            items = unique(page.items)
            nextOffset = page.nextOffset ?? items.count
            hasMore = page.hasMore
        } catch {
            guard generation == requestGeneration else { return }
            items = []
            hasMore = false
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage(using backend: ScanLabBackend) async {
        guard hasMore, errorMessage == nil, !isLoadingInitial, !isLoadingMore else { return }
        let requestGeneration = generation
        isLoadingMore = true
        defer {
            if generation == requestGeneration { isLoadingMore = false }
        }

        do {
            let page = try await fetchVisiblePage(startingAt: nextOffset, using: backend)
            guard generation == requestGeneration else { return }
            let existing = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            nextOffset = page.nextOffset ?? nextOffset + page.items.count
            hasMore = page.hasMore
            errorMessage = nil
        } catch {
            guard generation == requestGeneration else { return }
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func fetchVisiblePage(startingAt offset: Int, using backend: ScanLabBackend) async throws -> ScanLabDiscoverEnvelope {
        var currentOffset = offset
        for _ in 0..<5 {
            let page = try await fetchPage(offset: currentOffset, using: backend)
            if !page.items.isEmpty || !page.hasMore { return page }
            guard let next = page.nextOffset, next > currentOffset else { return page }
            currentOffset = next
        }
        return try await fetchPage(offset: currentOffset, using: backend)
    }

    private func fetchPage(offset: Int, using backend: ScanLabBackend) async throws -> ScanLabDiscoverEnvelope {
        var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "mode", value: "feed"),
            URLQueryItem(name: "limit", value: String(pageSize)),
            URLQueryItem(name: "offset", value: String(max(offset, 0)))
        ]
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: String(trimmed.prefix(80))))
        }
        components.queryItems = queryItems
        guard let url = components.url else { throw ScanLabBackendError.invalidServerResponse }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let session = try? await backend.client.auth.session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ScanLabBackendError.invalidServerResponse
        }
        return try JSONDecoder().decode(ScanLabDiscoverEnvelope.self, from: data)
    }

    private func unique(_ scans: [ScanLabPublicScan]) -> [ScanLabPublicScan] {
        var seen = Set<UUID>()
        return scans.filter { seen.insert($0.id).inserted }
    }
}
