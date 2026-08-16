import Combine
import Foundation
import SwiftUI

private struct ScanLabDiscoverSingleEnvelope: Decodable {
    let item: ScanLabPublicScan
}

private enum ScanLabDiscoverOpenError: LocalizedError {
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "この公開3Dは現在利用できません。非公開化・削除・モデレーションにより公開が終了した可能性があります。"
        case .invalidResponse:
            "公開3Dの最新状態を確認できませんでした。通信状態を確認して再試行してください。"
        }
    }
}

@MainActor
private final class ScanLabDiscoverOpenStore: ObservableObject {
    @Published private(set) var scan: ScanLabPublicScan?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func load(scanID: UUID, backend: ScanLabBackend) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        scan = nil
        defer { isLoading = false }

        do {
            var components = URLComponents(url: ScanLabConfig.publicFunctionURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "mode", value: "share"),
                URLQueryItem(name: "id", value: scanID.uuidString.lowercased()),
            ]
            guard let url = components.url else { throw ScanLabDiscoverOpenError.invalidResponse }

            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if let session = try? await backend.client.auth.session {
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ScanLabDiscoverOpenError.invalidResponse
            }
            if http.statusCode == 404 {
                throw ScanLabDiscoverOpenError.unavailable
            }
            guard 200..<300 ~= http.statusCode else {
                throw ScanLabDiscoverOpenError.invalidResponse
            }

            let fresh = try JSONDecoder().decode(ScanLabDiscoverSingleEnvelope.self, from: data).item
            guard fresh.id == scanID, fresh.visibility == ScanLabVisibility.public.rawValue, fresh.modelUrl != nil else {
                throw ScanLabDiscoverOpenError.unavailable
            }
            scan = fresh
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct ScanLabDiscoverFreshOpenView: View {
    @EnvironmentObject private var backend: ScanLabBackend
    @StateObject private var store = ScanLabDiscoverOpenStore()
    let scanID: UUID

    var body: some View {
        Group {
            if let scan = store.scan {
                ScanLabRemoteScanView(scan: scan)
            } else if store.isLoading {
                ProgressView("公開状態と3D URLを確認中")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "公開3Dを開けません",
                        systemImage: "lock.slash",
                        description: Text(store.errorMessage ?? "公開状態を確認できませんでした。")
                    )
                    Button("再確認") {
                        Task { await store.load(scanID: scanID, backend: backend) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            if store.scan == nil, !store.isLoading {
                await store.load(scanID: scanID, backend: backend)
            }
        }
    }
}
