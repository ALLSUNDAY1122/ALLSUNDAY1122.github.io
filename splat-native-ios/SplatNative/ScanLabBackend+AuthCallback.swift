import Foundation
@preconcurrency import Supabase

extension ScanLabBackend {
    @discardableResult
    func signUpWithAuthCallback(email: String, password: String) async throws -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.auth.signUp(
            email: normalizedEmail,
            password: password,
            redirectTo: ScanLabAuthCallbackPolicy.redirectURL
        )
        let confirmationPending = response.session == nil
        if confirmationPending {
            notice = "確認メールを送信しました。このiPhoneで最新メール内のリンクを開いて登録を完了してください。"
        } else {
            ScanLabEmailConfirmationStore.clear()
            notice = "アカウントを作成しました。"
        }
        return confirmationPending
    }

    func resendSignUpConfirmation(email: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try await client.auth.resend(
            email: normalizedEmail,
            type: .signup,
            emailRedirectTo: ScanLabAuthCallbackPolicy.redirectURL
        )
        notice = "確認メールの再送要求を受け付けました。登録待ちのアドレスであれば届きます。再送した場合は最新メールのリンクを使ってください。"
    }

    func handleAuthCallback(_ url: URL) async {
        guard ScanLabAuthCallbackPolicy.accepts(url) else { return }

        do {
            _ = try await client.auth.session(from: url)
            ScanLabEmailConfirmationStore.clear()
            notice = "メールアドレスの確認が完了しました。"
        } catch {
            notice = "認証リンクを完了できませんでした。リンクの期限を確認して、もう一度お試しください。"
        }
    }
}
