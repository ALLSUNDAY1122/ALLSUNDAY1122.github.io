import Foundation

enum ScanLabAuthCallbackPolicy {
    static let scheme = "jp.allsunday1122.splatlab"
    static let host = "auth-callback"
    static let passwordRecoveryHost = "password-recovery"
    static let redirectURL = URL(string: "\(scheme)://\(host)")!
    static let passwordRecoveryRedirectURL = URL(string: "\(scheme)://\(passwordRecoveryHost)")!

    static func accepts(_ url: URL) -> Bool {
        accepts(url, host: host)
    }

    static func acceptsPasswordRecovery(_ url: URL) -> Bool {
        accepts(url, host: passwordRecoveryHost)
    }

    private static func accepts(_ url: URL, host expectedHost: String) -> Bool {
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

enum ScanLabEmailConfirmationPolicy {
    static let minimumResendInterval: TimeInterval = 60

    static func remainingSeconds(lastSentAt: Date?, now: Date = Date()) -> Int {
        guard let lastSentAt else { return 0 }
        let elapsed = max(0, now.timeIntervalSince(lastSentAt))
        let remaining = max(0, minimumResendInterval - elapsed)
        return Int(ceil(remaining))
    }

    static func canResend(lastSentAt: Date?, now: Date = Date()) -> Bool {
        remainingSeconds(lastSentAt: lastSentAt, now: now) == 0
    }
}

enum ScanLabEmailConfirmationStore {
    private static let key = "scanlab.email-confirmation.last-sent-at"

    static func load(from defaults: UserDefaults = .standard) -> Date? {
        let value = defaults.double(forKey: key)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    static func save(_ date: Date, to defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: key)
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}
