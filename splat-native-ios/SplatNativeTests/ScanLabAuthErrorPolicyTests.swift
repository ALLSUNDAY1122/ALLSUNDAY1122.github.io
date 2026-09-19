import XCTest

final class ScanLabAuthErrorPolicyTests: XCTestCase {
    func testInvalidCredentialsUseStableSignInMessage() {
        XCTAssertEqual(
            ScanLabAuthErrorPolicy.userMessage(
                rawDescription: "AuthApiError: Invalid login credentials",
                operation: .signIn
            ),
            "メールアドレスまたはパスワードが正しくありません。"
        )
    }

    func testUnconfirmedEmailUsesActionableMessage() {
        XCTAssertEqual(
            ScanLabAuthErrorPolicy.userMessage(
                rawDescription: "email_not_confirmed",
                operation: .signIn
            ),
            "メール内の確認リンクを開いてからログインしてください。"
        )
    }

    func testSignUpDoesNotRevealExistingAccount() {
        let message = ScanLabAuthErrorPolicy.userMessage(
            rawDescription: "User already registered: secret@example.com",
            operation: .signUp
        )
        XCTAssertEqual(
            message,
            "アカウントを作成できませんでした。入力内容を確認して、もう一度お試しください。"
        )
        XCTAssertFalse(message.contains("secret@example.com"))
        XCTAssertFalse(message.contains("registered"))
    }

    func testUnknownServerTextNeverLeaksToUser() {
        let raw = "postgres internal detail ref=private-row-123"
        let message = ScanLabAuthErrorPolicy.userMessage(rawDescription: raw, operation: .signIn)
        XCTAssertEqual(message, "ログインできませんでした。入力内容を確認して、もう一度お試しください。")
        XCTAssertFalse(message.contains(raw))
    }

    func testRateLimitIsRetryableWithoutRawServerText() {
        XCTAssertEqual(
            ScanLabAuthErrorPolicy.userMessage(
                rawDescription: "429 too many requests; bucket auth-email exhausted",
                operation: .signUp
            ),
            "操作が集中しています。少し待ってから、もう一度お試しください。"
        )
    }

    func testNetworkFailureIsStableAcrossOperations() {
        for operation in [ScanLabAuthOperation.signIn, .signUp, .signOut, .passwordUpdate] {
            XCTAssertEqual(
                ScanLabAuthErrorPolicy.userMessage(
                    rawDescription: "The Internet connection appears to be offline.",
                    operation: operation
                ),
                "通信状態を確認して、もう一度お試しください。"
            )
        }
    }

    func testWeakPasswordGetsSpecificGuidanceWithoutServerDetails() {
        XCTAssertEqual(
            ScanLabAuthErrorPolicy.userMessage(
                rawDescription: "weak_password: password should contain uppercase",
                operation: .signUp
            ),
            "より安全なパスワードを設定してください。"
        )
    }

    func testSignOutUnknownFailureUsesSafeFallback() {
        XCTAssertEqual(
            ScanLabAuthErrorPolicy.userMessage(
                rawDescription: "unexpected auth backend secret detail",
                operation: .signOut
            ),
            "ログアウトできませんでした。通信状態を確認して、もう一度お試しください。"
        )
    }
}
