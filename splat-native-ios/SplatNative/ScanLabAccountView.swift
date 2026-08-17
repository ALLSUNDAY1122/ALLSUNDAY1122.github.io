import SwiftUI

struct ScanLabAccountView: View {
    @EnvironmentObject var backend: ScanLabBackend
    var body: some View {
        NavigationStack {
            Group { if backend.isAuthenticated { ScanLabSignedInAccountView() } else { ScanLabAuthView() } }
                .navigationTitle("Account")
        }
    }
}

struct ScanLabAuthView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorMessage: String?
    enum Mode: String, CaseIterable, Identifiable { case signIn = "ログイン"; case signUp = "新規登録"; var id: String { rawValue } }

    var body: some View {
        Form {
            Section { Picker("認証", selection: $mode) { ForEach(Mode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
            Section("メールアドレス") {
                TextField("you@example.com", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).autocorrectionDisabled()
                SecureField("パスワード", text: $password).textContentType(mode == .signUp ? .newPassword : .password)
            }
            Section {
                Button(mode == .signIn ? "ログイン" : "アカウントを作成") { Task { await submit() } }
                    .disabled(busy || email.isEmpty || password.count < 6)
                if busy { ProgressView() }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                else if let notice = backend.notice { Text(notice).foregroundStyle(.secondary).font(.footnote) }
            }
            Section("プライバシー") {
                Text("スキャン作成と端末内3D生成はログイン不要です。クラウドへ送信するのは、公開・限定リンク・非公開クラウド保存を明示的に実行した場合だけです。").font(.footnote).foregroundStyle(.secondary)
                Link("サポート・お問い合わせ", destination: ScanLabConfig.supportURL)
                Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/splat-native-ios/privacy.html")!)
            }
        }
    }
    private func submit() async {
        busy = true; errorMessage = nil; defer { busy = false }
        do { if mode == .signIn { try await backend.signIn(email: email, password: password) } else { try await backend.signUp(email: email, password: password) } }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct ScanLabSignedInAccountView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @State private var displayName = ""
    @State private var handle = ""
    @State private var profileBusy = false
    @State private var profileError: String?
    @State private var deleteAccountConfirmation = false
    @State private var accountBusy = false

    var body: some View {
        List {
            Section("プロフィール") {
                Text(backend.currentUserEmail ?? "").font(.footnote).foregroundStyle(.secondary)
                TextField("表示名", text: $displayName).textContentType(.name)
                TextField("ユーザーID", text: $handle).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("プロフィールを保存") { Task { await saveProfile() } }.disabled(profileBusy || displayName.isEmpty || handle.isEmpty)
                if profileBusy { ProgressView() }
                if let profileError { Text(profileError).foregroundStyle(.red).font(.footnote) }
            }
            Section("自分のクラウドスキャン") {
                if backend.ownerScans.isEmpty { Text(backend.isLoadingOwner ? "取得中…" : "まだクラウドへ保存していません。").foregroundStyle(.secondary) }
                else { ForEach(backend.ownerScans) { scan in ScanLabOwnerScanRow(scan: scan) } }
            }
            Section("サポート") {
                Link("サポート・お問い合わせ", destination: ScanLabConfig.supportURL)
                Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/splat-native-ios/privacy.html")!)
            }
            Section {
                Button("ログアウト") { Task { await backend.signOut() } }
                Button("アカウントとクラウドデータを削除", role: .destructive) { deleteAccountConfirmation = true }.disabled(accountBusy)
            } footer: { Text("アカウント削除では、このアカウントに紐づく3Dファイルと公開情報を削除します。端末内に書き出したファイルは削除されません。") }
        }
        .task { await backend.loadProfile(); await backend.loadOwnerScans(); syncProfileFields() }
        .onChange(of: backend.profile) { _, _ in syncProfileFields() }
        .alert("アカウントを削除しますか？", isPresented: $deleteAccountConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("完全に削除", role: .destructive) { Task { await deleteAccount() } }
        } message: { Text("クラウド上の3D・プロフィール・公開状態を削除します。この操作は元に戻せません。") }
    }
    private func syncProfileFields() { guard let p = backend.profile else { return }; displayName = p.displayName; handle = p.handle }
    private func saveProfile() async { profileBusy = true; profileError = nil; defer { profileBusy = false }; do { try await backend.updateProfile(handle: handle, displayName: displayName) } catch { profileError = error.localizedDescription } }
    private func deleteAccount() async { accountBusy = true; defer { accountBusy = false }; do { try await backend.deleteAccount() } catch { backend.notice = "アカウントを削除できませんでした: \(error.localizedDescription)" } }
}

private struct ScanLabOwnerScanRow: View {
    @EnvironmentObject var backend: ScanLabBackend
    let scan: ScanLabOwnerScan
    @State private var busy = false
    @State private var deleteConfirmation = false
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text(scan.title).font(.headline); Text(statusText).font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Text(visibilityText).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.white.opacity(0.08), in: Capsule())
            }
            HStack {
                if let shareURL = backend.shareURL(for: scan) { ShareLink(item: shareURL) { Label("リンク共有", systemImage: "link") } }
                if scan.status == "published" {
                    Button("非公開化") { Task { await unpublish() } }
                } else if scan.status == "hidden", scan.visibility != ScanLabVisibility.private.rawValue {
                    Button("再公開") { Task { await republish() } }
                }
                Spacer()
                Button("削除", role: .destructive) { deleteConfirmation = true }
            }.buttonStyle(.borderless).font(.caption).disabled(busy)
        }
        .padding(.vertical, 4)
        .alert("このクラウドスキャンを削除しますか？", isPresented: $deleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) { Task { await deleteScan() } }
        } message: { Text("公開リンクも使えなくなり、クラウド上の3Dファイルも削除されます。") }
    }
    private var visibilityText: String { switch scan.visibility { case "public": "公開"; case "unlisted": "限定リンク"; default: "非公開" } }
    private var statusText: String { if scan.status == "hidden" { return "非公開化済み" }; if scan.moderationStatus == "pending" { return "公開確認中" }; return scan.status == "published" ? "公開中" : "下書き" }
    private func unpublish() async { busy = true; defer { busy = false }; do { try await backend.unpublishPublishedScan(scan) } catch { backend.notice = error.localizedDescription } }
    private func republish() async { busy = true; defer { busy = false }; do { _ = try await backend.republish(scan) } catch { backend.notice = error.localizedDescription } }
    private func deleteScan() async { busy = true; defer { busy = false }; do { try await backend.delete(scan) } catch { backend.notice = error.localizedDescription } }
}
