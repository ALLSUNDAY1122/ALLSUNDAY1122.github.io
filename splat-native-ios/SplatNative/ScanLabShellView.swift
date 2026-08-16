import MapKit
import SwiftUI

struct ScanLabShellView: View {
    @EnvironmentObject var backend: ScanLabBackend
    var body: some View {
        TabView {
            ScanLabScanTab().tabItem { Label("Scan", systemImage: "viewfinder") }
            ScanLabMapView().tabItem { Label("Map", systemImage: "map") }
            ScanLabDiscoverView().tabItem { Label("Discover", systemImage: "sparkles.rectangle.stack") }
            ScanLabAccountView().tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(.mint)
        .preferredColorScheme(.dark)
    }
}

struct ScanLabScanTab: View {
    @EnvironmentObject var model: ScanModel
    @State private var showingPublish = false
    var body: some View {
        RootScanView()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.phase == .finished, model.resultURL != nil {
                    Button { showingPublish = true } label: {
                        Label("オンライン共有・公開", systemImage: "icloud.and.arrow.up").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .background(.black).foregroundStyle(.mint)
                }
            }
            .sheet(isPresented: $showingPublish) {
                if let resultURL = model.resultURL { PublishScanView(resultURL: resultURL, previewImage: model.previewImage) }
            }
    }
}

struct ScanLabDiscoverView: View {
    @EnvironmentObject var backend: ScanLabBackend
    private var browsableScans: [ScanLabPublicScan] { backend.publicScans.filter(PublicBrowsePolicy.isBrowsable) }
    var body: some View {
        NavigationStack {
            Group {
                if browsableScans.isEmpty && backend.isLoadingPublic { ProgressView("公開スキャンを取得中") }
                else if browsableScans.isEmpty {
                    ContentUnavailableView("まだ公開スキャンがありません", systemImage: "sparkles.rectangle.stack", description: Text("公開された3Dはここに表示されます。ダミー投稿は表示しません。"))
                } else {
                    List(browsableScans) { scan in NavigationLink { ScanLabRemoteScanView(scan: scan) } label: { ScanLabDiscoverRow(scan: scan) } }
                        .listStyle(.plain).refreshable { await backend.loadPublicScans() }
                }
            }
            .navigationTitle("Discover")
            .task { await backend.loadPublicScans() }
        }
    }
}

private struct ScanLabDiscoverRow: View {
    let scan: ScanLabPublicScan
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: scan.previewUrl) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default: ZStack { RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)); Image(systemName: "cube.transparent").foregroundStyle(.secondary) }
                }
            }
            .frame(width: 92, height: 92).clipShape(RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 6) {
                Text(scan.title).font(.headline).lineLimit(2)
                if let name = scan.author?.displayName { Text(name).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 12) {
                    Label("\(scan.likeCount)", systemImage: "heart")
                    if let label = scan.location?.label, !label.isEmpty { Label(label, systemImage: "mappin.and.ellipse").lineLimit(1) }
                }.font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 4)
    }
}

struct ScanLabPublicProfileView: View {
    @EnvironmentObject var backend: ScanLabBackend
    let author: ScanLabAuthor
    private var scans: [ScanLabPublicScan] { PublicBrowsePolicy.scans(for: author.id, in: backend.publicScans) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(author.displayName).font(.title2.bold())
                    Text("@\(author.handle)").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 6)
            }
            Section("公開3D") {
                if scans.isEmpty {
                    ContentUnavailableView("公開3Dはありません", systemImage: "cube.transparent")
                } else {
                    ForEach(scans) { scan in
                        NavigationLink { ScanLabRemoteScanView(scan: scan) } label: { ScanLabDiscoverRow(scan: scan) }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await backend.loadPublicScans() }
    }
}

struct ScanLabMapView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @State private var selected: ScanLabPublicScan?
    private var mappedScans: [ScanLabPublicScan] { backend.publicScans.filter { PublicBrowsePolicy.isBrowsable($0) && $0.location != nil } }
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map {
                    ForEach(mappedScans) { scan in
                        if let location = scan.location {
                            Annotation(scan.title, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                                Button { selected = scan } label: { Image(systemName: "cube.fill").font(.headline).foregroundStyle(.black).frame(width: 38, height: 38).background(.mint, in: Circle()).shadow(radius: 3) }.buttonStyle(.plain)
                            }
                        }
                    }
                }.mapStyle(.standard(pointsOfInterest: .excludingAll))
                if mappedScans.isEmpty {
                    Text(backend.isLoadingPublic ? "公開地点を取得中" : "公開地点はまだありません").font(.footnote.weight(.semibold)).padding(.horizontal, 14).padding(.vertical, 9).background(.ultraThinMaterial, in: Capsule()).padding(.bottom, 14)
                }
            }
            .navigationTitle("Map").task { await backend.loadPublicScans() }
            .sheet(item: $selected) { scan in NavigationStack { ScanLabRemoteScanView(scan: scan) } }
        }
    }
}

struct ScanLabRemoteScanView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @Environment(\.dismiss) private var dismiss
    let scan: ScanLabPublicScan
    @StateObject private var viewerState = SplatViewerState()
    @State private var localURL: URL?
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var likeBusy = false
    @State private var reportBusy = false
    @State private var blockBusy = false
    @State private var showingReport = false
    @State private var showingBlock = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let localURL { SplatViewer(url: localURL, state: viewerState) }
                else if loading { ProgressView("3Dを読み込み中").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else { ContentUnavailableView("3Dを開けませんでした", systemImage: "exclamationmark.triangle", description: Text(errorMessage ?? "公開データの取得に失敗しました。")) }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(scan.title).font(.title3.bold())
                if !scan.caption.isEmpty { Text(scan.caption).font(.subheadline).foregroundStyle(.secondary) }
                if let author = PublicBrowsePolicy.author(for: scan) {
                    NavigationLink { ScanLabPublicProfileView(author: author) } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                            VStack(alignment: .leading, spacing: 1) {
                                Text(author.displayName).font(.subheadline.weight(.semibold))
                                Text("@\(author.handle) · 公開3Dを見る").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                    }.buttonStyle(.plain)
                }
                HStack {
                    Button { Task { likeBusy = true; defer { likeBusy = false }; do { try await backend.like(scan) } catch { backend.notice = error.localizedDescription } } } label: { Label("\(scan.likeCount)", systemImage: "heart") }.disabled(likeBusy)
                    Spacer()
                    if let shareURL = publicShareURL { ShareLink(item: shareURL) { Label("共有", systemImage: "square.and.arrow.up") } }
                    Menu {
                        Button("この3Dを報告", role: .destructive) { showingReport = true }
                        if backend.isAuthenticated, scan.author != nil { Button("このユーザーをブロック", role: .destructive) { showingBlock = true } }
                    } label: { Image(systemName: "ellipsis") }.disabled(reportBusy || blockBusy)
                }.buttonStyle(.bordered)
            }.padding(16).background(.black)
        }
        .navigationTitle(scan.author?.displayName ?? "Scan").navigationBarTitleDisplayMode(.inline)
        .task { await loadModel() }
        .confirmationDialog("報告理由", isPresented: $showingReport, titleVisibility: .visible) {
            Button("プライバシー上の問題", role: .destructive) { Task { await report("privacy") } }
            Button("危険・不適切な場所", role: .destructive) { Task { await report("unsafe_location") } }
            Button("著作権・権利の問題", role: .destructive) { Task { await report("copyright") } }
            Button("スパム", role: .destructive) { Task { await report("spam") } }
            Button("その他", role: .destructive) { Task { await report("other") } }
            Button("キャンセル", role: .cancel) {}
        } message: { Text("報告を受けた公開3Dは確認のため非表示になり、再公開はモデレーション保留になります。") }
        .alert("このユーザーをブロックしますか？", isPresented: $showingBlock) {
            Button("キャンセル", role: .cancel) {}
            Button("ブロック", role: .destructive) { Task { await blockAuthor() } }
        } message: { Text("このユーザーの公開3DをMapとDiscoverから除外します。") }
        .onDisappear { if let localURL { try? FileManager.default.removeItem(at: localURL) } }
    }

    private var publicShareURL: URL? {
        var components = URLComponents(url: ScanLabConfig.viewerBaseURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "id", value: scan.id.uuidString.lowercased())]
        return components.url
    }
    private func report(_ reason: String) async {
        reportBusy = true; defer { reportBusy = false }
        do { try await backend.report(scan, reason: reason); dismiss() } catch { backend.notice = error.localizedDescription }
    }
    private func blockAuthor() async {
        blockBusy = true; defer { blockBusy = false }
        do { try await backend.block(scan); dismiss() } catch { backend.notice = error.localizedDescription }
    }
    private func loadModel() async {
        guard localURL == nil, let modelURL = scan.modelUrl else { loading = false; if scan.modelUrl == nil { errorMessage = "3Dデータの署名URLがありません。" }; return }
        do {
            let (downloaded, response) = try await URLSession.shared.download(from: modelURL)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw ScanLabBackendError.invalidServerResponse }
            let remoteExtension = modelURL.pathExtension.lowercased()
            let supportedExtension = ["spz", "splat", "ply"].contains(remoteExtension) ? remoteExtension : "spz"
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("scanlab-\(scan.id.uuidString).\(supportedExtension)")
            try? FileManager.default.removeItem(at: target); try FileManager.default.moveItem(at: downloaded, to: target); localURL = target
        } catch { errorMessage = error.localizedDescription }
        loading = false
    }
}