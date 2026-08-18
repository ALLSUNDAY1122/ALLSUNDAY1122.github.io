import SwiftUI

struct ScanLabAccountView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @EnvironmentObject var passwordRecovery: ScanLabPasswordRecoveryCoordinator

    var body: some View {
        NavigationStack {
            Group {
                if backend.authPhase == .signedIn && passwordRecovery.requiresPasswordUpdate {
                    ScanLabPasswordRecoveryView()
                } else {
                    switch backend.authPhase {
                    case .resolving:
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("セッションを確認中…").font(.footnote).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .signedIn:
                        ScanLabSignedInAccountView()
                    case .signedOut:
                        ScanLabAuthView()
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}

struct ScanLabAuthView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @EnvironmentObject var passwordRecovery: ScanLabPasswordRecoveryCoordinator
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var awaitingEmailConfirmation = false
    @State private var lastConfirmationSentAt: Date? = ScanLabEmailConfirmationStore.load()
    enum Mode: String, CaseIterable, Identifiable { case signIn = "ログイン"; case signUp = "新規登録"; var id: String { rawValue } }

    var body: some View {
        Form {
            Section { Picker("認証", selection: $mode) { ForEach(Mode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented) }
            Section("メールアドレス") {
                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .disabled(mode == .signUp && awaitingEmailConfirmation)
                SecureField("パスワード", text: $password).textContentType(mode == .signUp ? .newPassword : .password)
            }
            Section {
                Button(primaryActionTitle) { Task { await submit() } }.disabled(primaryActionDisabled)
                if mode == .signIn {
                    Button("パスワードを忘れた場合") { Task { await requestPasswordReset() } }.disabled(busy || normalizedEmail.isEmpty)
                } else {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = ScanLabEmailConfirmationPolicy.remainingSeconds(lastSentAt: lastConfirmationSentAt, now: context.date)
                        VStack(alignment: .leading, spacing: 10) {
                            Button(resendButtonTitle(remainingSeconds: remaining)) { Task { await resendConfirmation() } }
                                .disabled(busy || normalizedEmail.isEmpty || remaining > 0)
                            if awaitingEmailConfirmation {
                                Text("確認メールを送信済みです。再送した場合は古いメールではなく、最新メールのリンクを開いてください。")
                                    .font(.footnote).foregroundStyle(.secondary)
                                Button("別のメールアドレスで登録し直す") {
                                    awaitingEmailConfirmation = false; errorMessage = nil; backend.notice = nil; password = ""
                                }
                                .disabled(busy || remaining > 0)
                            }
                        }
                    }
                }
                if busy { ProgressView() }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                else if let notice = backend.notice { Text(notice).foregroundStyle(.secondary).font(.footnote) }
            }
            Section("プライバシー") {
                Text("スキャン作成と端末内3D生成はログイン不要です。クラウドへ送信するのは、公開・限定リンク・非公開クラウド保存を明示的に実行した場合だけです。")
                    .font(.footnote).foregroundStyle(.secondary)
                Link("サポート・お問い合わせ", destination: ScanLabConfig.supportURL)
                Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/splat-native-ios/privacy.html")!)
            }
        }
        .onChange(of: mode) { _, _ in errorMessage = nil }
    }

    private var normalizedEmail: String { email.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var primaryActionTitle: String { mode == .signIn ? "ログイン" : (awaitingEmailConfirmation ? "確認メールを送信済み" : "アカウントを作成") }
    private var primaryActionDisabled: Bool { busy || normalizedEmail.isEmpty || password.count < 6 || (mode == .signUp && awaitingEmailConfirmation) }
    private func resendButtonTitle(remainingSeconds: Int) -> String { remainingSeconds > 0 ? "確認メールを再送（\(remainingSeconds)秒後）" : "確認メールを再送" }

    private func markConfirmationEmailSent() {
        let now = Date(); lastConfirmationSentAt = now; ScanLabEmailConfirmationStore.save(now); awaitingEmailConfirmation = true
    }

    private func submit() async {
        busy = true; errorMessage = nil; defer { busy = false }
        do {
            passwordRecovery.prepareForStandardAuth()
            if mode == .signIn {
                try await backend.signIn(email: email, password: password)
                ScanLabEmailConfirmationStore.clear(); lastConfirmationSentAt = nil; awaitingEmailConfirmation = false
            } else {
                let confirmationPending = try await backend.signUpWithAuthCallback(email: email, password: password)
                if confirmationPending { markConfirmationEmailSent() }
                else { lastConfirmationSentAt = nil; awaitingEmailConfirmation = false }
            }
        } catch {
            errorMessage = ScanLabAuthErrorPolicy.userMessage(for: error, operation: mode == .signIn ? .signIn : .signUp)
        }
    }

    private func resendConfirmation() async {
        guard ScanLabEmailConfirmationPolicy.canResend(lastSentAt: lastConfirmationSentAt) else { return }
        busy = true; errorMessage = nil; defer { busy = false }
        do {
            passwordRecovery.prepareForStandardAuth()
            try await backend.resendSignUpConfirmation(email: email)
            markConfirmationEmailSent()
        } catch {
            errorMessage = "確認メールを再送できませんでした。少し待ってから、もう一度お試しください。"
        }
    }

    private func requestPasswordReset() async {
        busy = true; errorMessage = nil; defer { busy = false }
        do {
            awaitingEmailConfirmation = false; lastConfirmationSentAt = nil; ScanLabEmailConfirmationStore.clear()
            try await passwordRecovery.requestReset(email: email, backend: backend)
        } catch {
            errorMessage = "パスワード再設定メールを送信できませんでした。通信状態を確認して、もう一度お試しください。"
        }
    }
}

private struct ScanLabPasswordRecoveryView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @EnvironmentObject var passwordRecovery: ScanLabPasswordRecoveryCoordinator
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var busy = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("新しいパスワード") {
                SecureField("6文字以上", text: $newPassword).textContentType(.newPassword)
                SecureField("もう一度入力", text: $confirmation).textContentType(.newPassword)
            }
            Section {
                Button("パスワードを変更") { Task { await complete() } }
                    .disabled(busy || !ScanLabPasswordRecoveryPolicy.isValidNewPassword(newPassword) || newPassword != confirmation)
                Button("キャンセルしてログアウト", role: .cancel) { Task { await cancel() } }.disabled(busy)
                if busy { ProgressView() }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                else { Text("再設定リンクで認証したセッションでは、先に新しいパスワードを確定してください。").font(.footnote).foregroundStyle(.secondary) }
            }
        }
    }

    private func complete() async {
        busy = true; errorMessage = nil; defer { busy = false }
        guard newPassword == confirmation else { errorMessage = "確認用パスワードが一致しません。"; return }
        do { try await passwordRecovery.complete(newPassword: newPassword, backend: backend) }
        catch { errorMessage = ScanLabAuthErrorPolicy.userMessage(for: error, operation: .passwordUpdate) }
    }

    private func cancel() async {
        busy = true; errorMessage = nil; await passwordRecovery.cancel(backend: backend); busy = false
    }
}

private struct ScanLabSignedInAccountView: View {
    @EnvironmentObject var backend: ScanLabBackend
    @EnvironmentObject var passwordRecovery: ScanLabPasswordRecoveryCoordinator
    @State private var deleteAccountConfirmation = false
    @State private var accountBusy = false
    @State private var unblockTarget: ScanLabBlockedUser?

    var body: some View {
        List {
            Section("プロフィール") {
                NavigationLink {
                    ScanLabProfileView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle").font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(backend.profile?.displayName ?? "プロフィールを編集")
                            if let handle = backend.profile?.handle { Text("@\(handle)").font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
                Text(backend.currentUserEmail ?? "").font(.footnote).foregroundStyle(.secondary)
                Text("メールアドレスは公開プロフィールには表示されません。").font(.caption).foregroundStyle(.secondary)
            }

            Section("自分のクラウドスキャン") {
                if backend.ownerScans.isEmpty {
                    Text(backend.isLoadingOwner ? "取得中…" : "まだクラウドへ保存していません。").foregroundStyle(.secondary)
                } else {
                    ForEach(backend.ownerScans) { scan in ScanLabOwnerScanRow(scan: scan) }
                }
            }

            ScanLabBlockedUsersSection(blockedUsers: backend.blockedUsers) { blocked in unblockTarget = blocked }

            Section("サポート") {
                Link("サポート・お問い合わせ", destination: ScanLabConfig.supportURL)
                Link("プライバシーポリシー", destination: URL(string: "https://allsunday1122.github.io/splat-native-ios/privacy.html")!)
            }
            Section {
                Button("ログアウト") { Task { passwordRecovery.prepareForStandardAuth(); await backend.signOutWithUserSafeError() } }
                Button("アカウントとクラウドデータを削除", role: .destructive) { deleteAccountConfirmation = true }.disabled(accountBusy)
            } footer: {
                Text("アカウント削除では、このアカウントに紐づく3Dファイル・公開情報・ブロック等の所有データと認証セッションを削除します。端末内に書き出したファイルは削除されません。")
            }
        }
        .task {
            async let profile: Void = backend.loadProfile()
            async let scans: Void = backend.loadOwnerScans()
            async let blocks: Void = backend.loadBlockedUsers()
            _ = await (profile, scans, blocks)
        }
        .alert("アカウントを削除しますか？", isPresented: $deleteAccountConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("完全に削除", role: .destructive) { Task { await deleteAccount() } }
        } message: {
            Text("クラウド上の3D・プロフィール・公開状態・認証情報を削除します。この操作は元に戻せません。")
        }
        .alert("ブロックを解除しますか？", isPresented: unblockAlertPresented) {
            Button("キャンセル", role: .cancel) { unblockTarget = nil }
            Button("解除") { if let target = unblockTarget { Task { await unblock(target) } } }
        } message: { Text("このユーザーとの相互非表示を解除します。") }
    }

    private var unblockAlertPresented: Binding<Bool> {
        Binding(get: { unblockTarget != nil }, set: { if !$0 { unblockTarget = nil } })
    }

    private func deleteAccount() async {
        accountBusy = true; defer { accountBusy = false }
        do { try await backend.deleteAccount(); passwordRecovery.prepareForStandardAuth() }
        catch { backend.notice = "アカウントを削除できませんでした: \(error.localizedDescription)" }
    }

    private func unblock(_ target: ScanLabBlockedUser) async {
        defer { unblockTarget = nil }
        do { try await backend.unblock(target) }
        catch { backend.notice = "ブロックを解除できませんでした: \(error.localizedDescription)" }
    }
}

private struct ScanLabBlockedUsersSection: View {
    let blockedUsers: [ScanLabBlockedUser]
    let onUnblock: (ScanLabBlockedUser) -> Void
    var body: some View {
        Section {
            if blockedUsers.isEmpty {
                Text("ブロック中のユーザーはいません。").foregroundStyle(.secondary)
            } else {
                ForEach(blockedUsers) { blocked in
                    HStack {
                        VStack(alignment: .leading) {
                            Text("ユーザー \(blocked.blockedId.uuidString.lowercased().prefix(8))…").font(.subheadline)
                            Text("公開投稿・共有・新しい操作を相互に抑止中").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("解除") { onUnblock(blocked) }.buttonStyle(.borderless)
                    }
                }
            }
        } header: { Text("ブロック中") }
        footer: { Text("解除すると、そのユーザーの公開投稿が再び表示される場合があります。") }
    }
}

private struct ScanLabOwnerScanRow: View {
    @EnvironmentObject var backend: ScanLabBackend
    let scan: ScanLabOwnerScan
    @State private var busy = false
    @State private var deleteConfirmation = false
    @State private var editPresented = false
    @State private var editTitle = ""
    @State private var editCaption = ""
    @State private var editError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(scan.title).font(.headline)
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(visibilityText).font(.caption.bold()).padding(.horizontal, 8).padding(.vertical, 5).background(.white.opacity(0.08), in: Capsule())
            }
            HStack {
                if let shareURL = backend.shareURL(for: scan) {
                    ShareLink(item: shareURL, subject: Text(scan.title), message: Text(scan.caption)) { Label("リンク共有", systemImage: "link") }
                }
                if scan.status == "published" {
                    Button("編集") { beginEditing() }
                    Button("非公開化") { Task { await unpublish() } }
                } else if scan.status == "hidden", scan.visibility != ScanLabVisibility.private.rawValue {
                    Button("再公開") { Task { await republish() } }
                }
                Spacer()
                Button("削除", role: .destructive) { deleteConfirmation = true }
            }
            .buttonStyle(.borderless).font(.caption).disabled(busy)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $editPresented) {
            NavigationStack {
                Form {
                    Section("共有情報") {
                        TextField("タイトル", text: $editTitle)
                            .onChange(of: editTitle) { _, value in if value.count > 80 { editTitle = String(value.prefix(80)) } }
                        HStack { Spacer(); Text("\(editTitle.count)/80").font(.caption).foregroundStyle(.secondary) }
                        TextField("説明（任意）", text: $editCaption, axis: .vertical)
                            .lineLimit(2...5)
                            .onChange(of: editCaption) { _, value in if value.count > 500 { editCaption = String(value.prefix(500)) } }
                        HStack { Spacer(); Text("\(editCaption.count)/500").font(.caption).foregroundStyle(.secondary) }
                    }
                    if let editError { Text(editError).foregroundStyle(.red).font(.footnote) }
                }
                .navigationTitle("共有情報を編集").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { editPresented = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(busy ? "保存中…" : "保存") { Task { await saveMetadata() } }
                            .disabled(busy || editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .alert("このクラウドスキャンを削除しますか？", isPresented: $deleteConfirmation) {
            Button("キャンセル", role: .cancel) {}
            Button("削除", role: .destructive) { Task { await deleteScan() } }
        } message: { Text("公開リンクも使えなくなり、クラウド上の3Dファイル・manifest・previewも削除されます。") }
    }

    private func beginEditing() {
        editTitle = String(scan.title.prefix(80)); editCaption = String(scan.caption.prefix(500)); editError = nil; editPresented = true
    }
    private var visibilityText: String { switch scan.visibility { case "public": "公開"; case "unlisted": "限定リンク"; default: "非公開" } }
    private var statusText: String {
        if scan.status == "hidden" { return "非公開化済み" }
        if scan.moderationStatus == "pending" { return "公開確認中" }
        return scan.status == "published" ? "公開中" : "下書き"
    }
    private func saveMetadata() async {
        busy = true; editError = nil; defer { busy = false }
        do { try await backend.updatePublishedMetadata(scan, title: editTitle, caption: editCaption); editPresented = false }
        catch { editError = error.localizedDescription }
    }
    private func unpublish() async { busy = true; defer { busy = false }; do { try await backend.unpublishPublishedScan(scan) } catch { backend.notice = error.localizedDescription } }
    private func republish() async { busy = true; defer { busy = false }; do { _ = try await backend.republish(scan) } catch { backend.notice = error.localizedDescription } }
    private func deleteScan() async { busy = true; defer { busy = false }; do { try await backend.delete(scan) } catch { backend.notice = error.localizedDescription } }
}
