import Foundation
@preconcurrency import Supabase

enum ScanLabAuthOperation {
    case signIn
    case signUp
    case signOut
    case passwordUpdate
}

enum ScanLabAuthErrorPolicy {
    static func userMessage(for error: Error, operation: ScanLabAuthOperation) -> String {
        userMessage(rawDescription: error.localizedDescription, operation: operation)
    }

    static func userMessage(rawDescription: String, operation: ScanLabAuthOperation) -> String {
        let text = rawDescription.lowercased()

        if containsAny(text, ["network", "internet", "offline", "timed out", "timeout", "not connected", "connection lost", "could not connect"]) {
            return "通信状態を確認して、もう一度お試しください。"
        }

        if containsAny(text, ["rate limit", "too many requests", "over_email_send_rate_limit", "429"]) {
            return "操作が集中しています。少し待ってから、もう一度お試しください。"
        }

        switch operation {
        case .signIn:
            if containsAny(text, ["email not confirmed", "email_not_confirmed"]) {
                return "メール内の確認リンクを開いてからログインしてください。"
            }
            if containsAny(text, ["invalid login credentials", "invalid_credentials", "invalid credentials", "wrong password"]) {
                return "メールアドレスまたはパスワードが正しくありません。"
            }
            return "ログインできませんでした。入力内容を確認して、もう一度お試しください。"

        case .signUp:
            if containsAny(text, ["weak password", "weak_password", "password should", "password must"]) {
                return "より安全なパスワードを設定してください。"
            }
            // Do not reveal whether an address is already registered.
            return "アカウントを作成できませんでした。入力内容を確認して、もう一度お試しください。"

        case .signOut:
            return "ログアウトできませんでした。通信状態を確認して、もう一度お試しください。"

        case .passwordUpdate:
            if containsAny(text, ["weak password", "weak_password", "password should", "password must"]) {
                return "より安全なパスワードを設定してください。"
            }
            return "パスワードを変更できませんでした。通信状態を確認して、もう一度お試しください。"
        }
    }

    private static func containsAny(_ text: String, _ candidates: [String]) -> Bool {
        candidates.contains { text.contains($0) }
    }
}

extension ScanLabBackend {
    func signOutWithUserSafeError() async {
        do {
            try await client.auth.signOut()
            notice = nil
        } catch {
            notice = ScanLabAuthErrorPolicy.userMessage(for: error, operation: .signOut)
        }
    }
}
