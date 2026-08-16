import Foundation

enum ScanLabProfilePolicy {
    static let displayNameLimit = 40
    static let handleRange = 3...24
    static let bioLimit = 160
    static let avatarURLLimit = 2_048

    static func normalizedHandle(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedDisplayName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedBio(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedAvatarURL(_ value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= avatarURLLimit,
              let url = URL(string: trimmed), url.scheme?.lowercased() == "https",
              url.host != nil else { return nil }
        return url
    }

    static func validate(handle: String, displayName: String, bio: String, avatarURL: String) -> Bool {
        let h = normalizedHandle(handle)
        let n = normalizedDisplayName(displayName)
        let b = normalizedBio(bio)
        guard handleRange.contains(h.count), (1...displayNameLimit).contains(n.count), (b?.count ?? 0) <= bioLimit else { return false }
        guard h.unicodeScalars.allSatisfy({ scalar in
            ("a"..."z").contains(Character(String(scalar))) || ("0"..."9").contains(Character(String(scalar))) || scalar == "_"
        }) else { return false }
        if !avatarURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, normalizedAvatarURL(avatarURL) == nil { return false }
        return true
    }
}
