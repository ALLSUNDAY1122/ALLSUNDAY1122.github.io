import SwiftUI

struct ScanLabPagedDiscoverView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @StateObject private var store = ScanLabDiscoverStore()

    var body: some View {
        NavigationStack {
            Group {
                if store.scans.isEmpty && store.isLoading {
                    ProgressView("公開スキャンを取得中")
                } else if store.scans.isEmpty {
                    VStack(spacing: 16) {
                        if let errorMessage = store.errorMessage {
                            ContentUnavailableView(
                                "Discoverを読み込めません",
                                systemImage: "wifi.exclamationmark",
                                description: Text(errorMessage)
                            )
                            Button("再試行") { Task { await store.reload(backend: backend) } }
                                .buttonStyle(.borderedProminent)
                        } else {
                            ContentUnavailableView(
                                "まだ公開スキャンがありません",
                                systemImage: "sparkles.rectangle.stack",
                                description: Text("公開された3Dはここに表示されます。ダミー投稿は表示しません。")
                            )
                            if store.nextCursor != nil {
                                Button("さらに探す") { Task { await store.loadMore(backend: backend) } }
                                    .buttonStyle(.bordered)
                            }
                        }
                    }
                } else {
                    List {
                        ForEach(store.scans) { scan in
                            NavigationLink {
                                ScanLabPagedRemoteContainer(scan: scan) {
                                    Task { await store.reload(backend: backend) }
                                }
                            } label: {
                                ScanLabPagedDiscoverRow(scan: scan)
                            }
                        }

                        if store.nextCursor != nil {
                            Section {
                                Button {
                                    Task { await store.loadMore(backend: backend) }
                                } label: {
                                    HStack {
                                        Spacer()
                                        if store.isLoading { ProgressView() }
                                        else { Label("さらに読み込む", systemImage: "arrow.down.circle") }
                                        Spacer()
                                    }
                                }
                                .disabled(store.isLoading)
                            }
                        }

                        if let errorMessage = store.errorMessage {
                            Section {
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await store.reload(backend: backend) }
                }
            }
            .navigationTitle("Discover")
            .task { await store.loadInitialIfNeeded(backend: backend) }
        }
    }
}

private struct ScanLabPagedRemoteContainer: View {
    let scan: ScanLabPublicScan
    let onReturn: () -> Void

    var body: some View {
        ScanLabDiscoverFreshOpenView(scanID: scan.id)
            .onDisappear(perform: onReturn)
    }
}

private struct ScanLabPagedDiscoverRow: View {
    let scan: ScanLabPublicScan

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: scan.previewUrl) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08))
                        Image(systemName: "cube.transparent").foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 92, height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(scan.title).font(.headline).lineLimit(2)
                if let name = scan.author?.displayName {
                    Text(name).font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label("\(scan.likeCount)", systemImage: "heart")
                    if let label = scan.location?.label, !label.isEmpty {
                        Label(label, systemImage: "mappin.and.ellipse").lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
