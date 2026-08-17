import Combine
import Foundation

private struct ScanLabDiscoverEnvelope: Decodable {
    let items: [ScanLabPublicScan]
    let nextCursor: String?
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
    private var nextCursor: String?
    private var loadedQuery = ""
    private var generation = UUID()

    func reload(using backend: ScanLabBackend) async {
        generation = UUID()
        let requestGeneration = generation
        let requestQuery = normalizedQuery(query)
        nextCursor = nil
        hasMore = true
        errorMessage = nil
        isLoadingInitial = true
        defer {
            if generation == requestGeneration { isLoadingInitial = false }
        }

        do {
            let page = try await fetchVisiblePage(startingAt: nil, query: requestQuery, using: backend)
            guard generation == requestGeneration else { return }
            items = unique(page.items)
            nextCursor = page.nextCursor
            loadedQuery = requestQuery
            hasMore = page.nextCursor != nil
        } catch {
            guard generation == requestGeneration else { return }
            if isCancellation(error) { return }
            items = []
            nextCursor = nil
            hasMore = false
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage(using backend: ScanLabBackend) async {
        let currentQuery = normalizedQuery(query)
        guard hasMore, errorMessage == nil, !isLoadingInitial, !isLoadingMore, let cursor = nextCursor else { return }
        guard currentQuery == loadedQuery else { return }
        let requestGeneration = generation
        isLoadingMore = true
        defer {
            if generation == requestGeneration { isLoadingMore = false }
        }

        do {
            let page = try await fetchVisiblePage(startingAt: cursor, query: loadedQuery, using: backend)
            guard generation == requestGeneration else { return }
            let existing = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            nextCursor = page.nextCursor
            hasMore = page.nextCursor != nil
            errorMessage = nil
        } catch {
            guard generation == requestGeneration else { return }
            if isCancellation(error) { return }
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    private func fetchVisiblePage(startingAt cursor: String?, query: String, using backend: ScanLabBackend) async throws -> ScanLabDiscoverEnvelope {
        var currentCursor = cursor
        var seenCursors = Set<String>()
        for _ in 0..<6 {
            try Task.checkCancellation()
            let page = try await fetchPage(cursor: currentCursor, query: query, using: backend)
            if !page.items.isEmpty || page.nextCursor == nil { return page }
            guard let next = page.nextCursor, next != currentCursor, seenCursors.insert(next).inserted else { return page }
            currentCursor = next
        }
        try Task.checkCancellation()
        return try await fetchPage(cursor: currentCursor, query: query, using: backend)
    }

    private func fetchPage(cursor: String?, query: String, using backend: ScanLabBackend) async throws -> ScanLabDiscoverEnvelope {
        var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
        var queryItems = [
            URLQueryItem(name: "mode", value: "feed"),
            URLQueryItem(name: "limit", value: String(pageSize))
        ]
        if let cursor, !cursor.isEmpty {
            queryItems.append(URLQueryItem(name: "cursor", value: cursor))
        }
        let trimmed = query
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

    private func normalizedQuery(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    }

    private func isCancellation(_ error: Error) -> Bool {
        if Task.isCancelled { return true }
        return (error as? URLError)?.code == .cancelled
    }

    private func unique(_ scans: [ScanLabPublicScan]) -> [ScanLabPublicScan] {
        var seen = Set<UUID>()
        return scans.filter { seen.insert($0.id).inserted }
    }
}
