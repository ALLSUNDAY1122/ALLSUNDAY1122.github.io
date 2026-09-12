import SwiftUI

struct ScanLabProfileView: View {
    @EnvironmentObject private var backend: ScanLabBackend
    @State private var profile: ScanLabEditableProfile?
    @State private var displayName = ""
    @State private var handle = ""
    @State private var bio = ""
    @State private var avatarURL = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("公開プロフィール") {
                HStack(spacing: 14) {
                    ScanLabAvatar(url: profile?.avatarURL, size: 64)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile?.displayName ?? "プロフィール").font(.headline)
                        if let handle = profile?.handle { Text("@\(handle)").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
                TextField("表示名", text: $displayName).textContentType(.name)
                TextField("ユーザーID", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                TextField("自己紹介（160文字まで）", text: $bio, axis: .vertical).lineLimit(3...6)
                TextField("アバター画像のHTTPS URL", text: $avatarURL).textInputAutocapitalization(.never).keyboardType(.URL).autocorrectionDisabled()
                Text("表示名・ユーザーID・自己紹介・アバターは公開プロフィールに表示されます。メールアドレスは公開されません。").font(.footnote).foregroundStyle(.secondary)
                Button("プロフィールを保存") { Task { await save() } }.disabled(busy || !ScanLabProfilePolicy.validate(handle: handle, displayName: displayName, bio: bio, avatarURL: avatarURL))
                if busy { ProgressView() }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.red) }
            }
        }
        .navigationTitle("プロフィール")
        .task { await load() }
    }

    private func load() async {
        guard !busy else { return }; busy = true; errorMessage = nil; defer { busy = false }
        do {
            let loaded = try await ScanLabProfileService(client: backend.client).loadMine()
            profile = loaded; displayName = loaded.displayName; handle = loaded.handle; bio = loaded.bio ?? ""; avatarURL = loaded.avatarURL?.absoluteString ?? ""
        } catch { errorMessage = "プロフィールを取得できませんでした: \(error.localizedDescription)" }
    }

    private func save() async {
        guard !busy else { return }; busy = true; errorMessage = nil; defer { busy = false }
        do {
            let saved = try await ScanLabProfileService(client: backend.client).save(handle: handle, displayName: displayName, bio: bio, avatarURL: avatarURL)
            profile = saved; displayName = saved.displayName; handle = saved.handle; bio = saved.bio ?? ""; avatarURL = saved.avatarURL?.absoluteString ?? ""
            await backend.loadProfile()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct ScanLabPublicProfileView: View {
    @EnvironmentObject private var backend: ScanLabBackend
    let handle: String
    @State private var profile: ScanLabPublicProfile?
    @State private var loading = true
    @State private var errorMessage: String?
    var body: some View {
        Group {
            if loading { ProgressView("プロフィールを取得中…") }
            else if let profile {
                List { Section {
                    HStack(spacing: 16) {
                        ScanLabAvatar(url: profile.avatarURL, size: 76)
                        VStack(alignment: .leading, spacing: 5) { Text(profile.displayName).font(.title3.bold()); Text("@\(profile.handle)").foregroundStyle(.secondary) }
                    }
                    if let bio = profile.bio, !bio.isEmpty { Text(bio) }
                    LabeledContent("公開スキャン", value: "\(profile.publicScanCount)")
                } }
            } else { ContentUnavailableView("プロフィールが見つかりません", systemImage: "person.crop.circle.badge.questionmark", description: Text(errorMessage ?? "ユーザーIDを確認してください。")) }
        }
        .navigationTitle("プロフィール")
        .task { await load() }
    }
    private func load() async {
        loading = true; defer { loading = false }
        do { profile = try await ScanLabProfileService(client: backend.client).loadPublic(handle: handle) } catch { errorMessage = error.localizedDescription }
    }
}

private struct ScanLabAvatar: View {
    let url: URL?
    let size: CGFloat
    var body: some View {
        AsyncImage(url: url) { phase in
            if case let .success(image) = phase { image.resizable().scaledToFill() }
            else { Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(.secondary) }
        }
        .frame(width: size, height: size).clipShape(Circle()).accessibilityLabel("プロフィール画像")
    }
}
