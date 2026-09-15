import Foundation

/// 保存ガード。
/// 「認識値をユーザー確認なしで確定保存しない」をコードで担保する層。
/// UIはこの型を通してしか保存データを作れない。
public enum SaveGuard {

    public struct Confirmation {
        public var value: Int?
        public var confirmed: Bool
        public var edited: Bool?

        public init(value: Int?, confirmed: Bool, edited: Bool? = nil) {
            self.value = value
            self.confirmed = confirmed
            self.edited = edited
        }
    }

    public enum Source: String, Codable {
        case userConfirmed = "user_confirmed"
        case userEdited = "user_edited"
        case empty
    }

    public struct SavedItem: Codable {
        public var key: ItemKey
        public var label: String
        public var value: Int?
        public var source: Source
        public var suggested: Int?
    }

    public struct Payload: Codable {
        public var items: [SavedItem]
        public var route: String
        public var confirmedAt: Date
        /// 明細の画像・原文テキストは保存しない。解析メタ情報のみ。
        public var tokenCount: Int
        public var passedChecks: [String]
    }

    public struct Blocked {
        public var key: ItemKey
        public var label: String
        public var reason: String
    }

    public struct Draft {
        public var ok: Bool
        public var blocked: [Blocked]
        public var payload: Payload?
    }

    public static func buildDraft(result: PayslipResult,
                                  confirmations: [ItemKey: Confirmation]) -> Draft {
        var blocked: [Blocked] = []
        var entries: [SavedItem] = []

        for key in ItemKey.allCases {
            let item = result.items[key]
            let suggested = item?.value
            let input = confirmations[key]
            let value = input?.value
            let confirmed = input?.confirmed ?? false

            guard let value else {
                if suggested != nil && !confirmed {
                    blocked.append(Blocked(key: key, label: key.label,
                                           reason: "解析候補が未確認です。確認するか、未設定に戻してください"))
                } else {
                    entries.append(SavedItem(key: key, label: key.label, value: nil, source: .empty, suggested: suggested))
                }
                continue
            }
            guard confirmed else {
                blocked.append(Blocked(key: key, label: key.label,
                                       reason: item?.status == .confident
                                           ? "確定候補でも、ユーザー確認なしには保存できません"
                                           : "要確認の項目です。内容を確認してください"))
                continue
            }
            let edited = input?.edited ?? (value != suggested)
            entries.append(SavedItem(key: key, label: key.label, value: value,
                                     source: edited ? .userEdited : .userConfirmed, suggested: suggested))
        }

        guard blocked.isEmpty else { return Draft(ok: false, blocked: blocked, payload: nil) }
        let payload = Payload(items: entries, route: result.route, confirmedAt: Date(),
                              tokenCount: result.tokenCount,
                              passedChecks: result.checks.filter(\.ok).map(\.id))
        return Draft(ok: true, blocked: [], payload: payload)
    }
}
