import Combine
import Foundation
@preconcurrency import Supabase

@MainActor
final class ScanLabPasswordRecoveryCoordinator: ObservableObject {
    @Published private(set) var phase: ScanLabPasswordRecoveryPhase

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        phase = ScanLabPasswordRecoveryStore.load(from: defaults)
    }

    var requiresPasswordUpdate: Bool {
        phase == .passwordUpdateRequired
    }

    func prepareForStandardAuth() {
        transition(.standardAuthStarted)
    }

    func requestReset(email: String, backend: ScanLabBackend) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty else { return }

        do {
            try await backend.client.auth.resetPasswordForEmail(
                normalizedEmail,
                redirectTo: ScanLabAuthCallbackPolicy.passwordRecoveryRedirectURL
            )
            transition(.resetRequested)
            backend.notice = "該当するアカウントがある場合、パスワード再設定メールを送信しました。"
        } catch {
            transition(.callbackFailed)
            throw error
        }
    }

    func handleAuthCallbackIfNeeded(_ url: URL, backend: ScanLabBackend) async -> Bool {
        guard ScanLabAuthCallbackPolicy.acceptsPasswordRecovery(url) else { return false }

        do {
            _ = try await backend.client.auth.session(from: url)
            transition(.callbackSucceeded)
            backend.notice = "認証が完了しました。新しいパスワードを設定してください。"
        } catch {
            transition(.callbackFailed)
            backend.notice = "パスワード再設定リンクを完了できませんでした。新しいリンクを発行してください。"
        }
        return true
    }

    func complete(newPassword: String, backend: ScanLabBackend) async throws {
        guard phase == .passwordUpdateRequired,
              ScanLabPasswordRecoveryPolicy.isValidNewPassword(newPassword)
        else {
            throw ScanLabPasswordRecoveryError.invalidNewPassword
        }

        try await backend.client.auth.update(user: UserAttributes(password: newPassword))
        transition(.passwordUpdated)
        backend.notice = "パスワードを変更しました。"
    }

    func cancel(backend: ScanLabBackend) async {
        transition(.cancelled)
        await backend.signOutWithUserSafeError()
    }

    private func transition(_ signal: ScanLabPasswordRecoverySignal) {
        phase = ScanLabPasswordRecoveryPolicy.reduce(current: phase, signal: signal)
        ScanLabPasswordRecoveryStore.save(phase, to: defaults)
    }
}

enum ScanLabPasswordRecoveryError: LocalizedError {
    case invalidNewPassword

    var errorDescription: String? {
        switch self {
        case .invalidNewPassword:
            return "新しいパスワードは6文字以上で入力してください。"
        }
    }
}
