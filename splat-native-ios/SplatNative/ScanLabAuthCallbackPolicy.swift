import Foundation

enum ScanLabAuthCallbackPolicy {
    static let scheme = "jp.allsunday1122.splatlab"
    static let host = "auth-callback"
    static let redirectURL = URL(string: "\(scheme)://\(host)")!

    static func accepts(_ url: URL) -> Bool {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              url.host?.caseInsensitiveCompare(host) == .orderedSame,
              url.user == nil,
              url.password == nil,
              url.port == nil
        else {
            return false
        }

        return url.path.isEmpty || url.path == "/"
    }
}
