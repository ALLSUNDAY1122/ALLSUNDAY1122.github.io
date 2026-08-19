import SwiftUI

/// HQ composition that makes the locally durable Splat/Mesh libraries part of the production shell.
/// Worker-owned feature views remain unchanged; this layer only wires their end-to-end navigation.
struct IntegratedScanLabShellView: View {
    @EnvironmentObject private var meshModel: MeshScanModel
    @StateObject private var meshDurability = MeshDurabilityCoordinator()

    var body: some View {
        TabView {
            IntegratedScanTab()
                .tabItem { Label("Scan", systemImage: "viewfinder") }

            ScanLabLibraryHubView()
                .tabItem { Label("Library", systemImage: "square.grid.2x2") }

            ScanLabMapView()
                .tabItem { Label("Map", systemImage: "map") }

            ScanLabDiscoverView()
                .tabItem { Label("Discover", systemImage: "sparkles.rectangle.stack") }

            ScanLabAccountView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
        .tint(.mint)
        .preferredColorScheme(.dark)
        .task {
            meshDurability.recoverPendingProjects()
            meshDurability.reconcile(model: meshModel)
        }
        .onChange(of: meshModel.phase) { _, _ in
            meshDurability.reconcile(model: meshModel)
        }
        .onChange(of: meshModel.resultURL) { _, _ in
            meshDurability.reconcile(model: meshModel)
        }
        .overlay(alignment: .top) {
            if let blocking = meshDurability.blockingMessage {
                ZStack {
                    Color.black.opacity(0.82)
                        .ignoresSafeArea()

                    VStack(spacing: 14) {
                        Image(systemName: "externaldrive.badge.exclamationmark")
                            .font(.system(size: 42))
                            .foregroundStyle(.orange)
                        Text("Meshを保護できません")
                            .font(.title3.bold())
                        Text(blocking)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        Button {
                            meshDurability.retry(model: meshModel)
                        } label: {
                            Label("保存を再試行", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                    }
                    .padding(22)
                    .frame(maxWidth: 360)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(20)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Mesh保存保護エラー。保存を再試行してください。")
            } else if let warning = meshDurability.warningMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .multilineTextAlignment(.leading)
                    Button {
                        meshDurability.retry(model: meshModel)
                    } label: {
                        Label("保存を再試行", systemImage: "arrow.clockwise")
                            .font(.footnote.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(.mint)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .accessibilityLabel("Mesh保存エラー: \(warning)。保存を再試行できます。")
            }
        }
    }
}

/// Production Scan tab: preserve D2 publish affordance while restoring C's saved-Splat entry point.
private struct IntegratedScanTab: View {
    @EnvironmentObject private var model: ScanModel
    @State private var showingPublish = false

    var body: some View {
        ScanHomeView()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if model.phase == .finished, model.resultURL != nil {
                    Button {
                        showingPublish = true
                    } label: {
                        Label("オンライン共有・公開", systemImage: "icloud.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(.black)
                    .foregroundStyle(.mint)
                }
            }
            .sheet(isPresented: $showingPublish) {
                if let resultURL = model.resultURL {
                    PublishScanView(resultURL: resultURL, previewImage: model.previewImage)
                }
            }
    }
}
