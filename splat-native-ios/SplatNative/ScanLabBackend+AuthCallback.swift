import Foundation
@preconcurrency import Supabase

extension ScanLabBackend {
    func signUpWithAuthCallback(email: String, password: String) async throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await client.auth.signUp(
            email: normalizedEmail,
            password: password,
            redirectTo: ScanLabAuthCallbackPolicy.redirectURL
        )
        notice = response.session == nil
            ? "確認メールを送信しました。このiPhoneでメール内のリンクを開いて登録を完了してください。"
            : "アカウントを作成しました。"
    }

    func handleAuthCallback(_ url: URL) async {
        guard ScanLabAuthCallbackPolicy.accepts(url) else { return }

        do {
            _ = try await client.auth.session(from: url)
            notice = "メールアドレスの確認が完了しました。"
        } catch {
            notice = "認証リンクを完了できませんでした。リンクの期限を確認して、もう一度お試しください。"
        }
    }
}
