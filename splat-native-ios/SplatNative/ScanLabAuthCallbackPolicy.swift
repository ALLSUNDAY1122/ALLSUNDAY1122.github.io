import Foundation

enum ScanLabAuthCallbackPolicy {
    static let scheme = "jp.allsunday1122.splatlab"
    static let host = "auth-callback"
    static let passwordRecoveryHost = "password-recovery"
    static let redirectURL = URL(string: "\(scheme)://\(host)")!
    static let passwordRecoveryRedirectURL = URL(string: "\(scheme)://\(passwordRecoveryHost)")!

    static func accepts(_ url: URL) -> Bool {
        accepts(url, expectedHost: host)
    }

    static func acceptsPasswordRecovery(_ url: URL) -> Bool {
        accepts(url, expectedHost: passwordRecoveryHost)
    }

    private static func accepts(_ url: URL, expectedHost: String) -> Bool {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              url.host?.caseInsensitiveCompare(expectedHost) == .orderedSame,
              url.user == nil,
              url.password == nil,
              url.port == nil
        else {
            return false
        }

        return url.path.isEmpty || url.path == "/"
    }
}
