import Foundation

enum ScanLabOwnerVisibilityPresentation {
    static func visibilityText(_ visibility: String) -> String {
        switch visibility {
        case "public": return "公開"
        case "unlisted": return "限定リンク"
        default: return "非公開"
        }
    }

    static func statusText(visibility: String, status: String, moderationStatus: String) -> String {
        if status == "hidden" {
            switch visibility {
            case "public": return "公開停止済み"
            case "unlisted": return "限定リンク無効化済み"
            default: return "クラウド保存停止済み"
            }
        }
        if status != "published" {
            switch visibility {
            case "public": return "公開準備中"
            case "unlisted": return "限定リンク準備中"
            default: return "クラウド保存処理中"
            }
        }
        if visibility != "private" && moderationStatus == "pending" {
            return visibility == "public" ? "公開確認中" : "共有確認中"
        }
        if visibility != "private" && moderationStatus == "rejected" {
            return visibility == "public" ? "公開停止（確認結果）" : "共有停止（確認結果）"
        }
        switch visibility {
        case "public": return "Map・Discoverで公開中"
        case "unlisted": return "限定リンク有効"
        default: return "非公開クラウド保存済み"
        }
    }

    static func canChangeVisibility(status: String, moderationStatus: String) -> Bool {
        status == "published" && moderationStatus == "approved"
    }

    static func unpublishActionTitle(visibility: String, status: String) -> String? {
        guard status == "published" else { return nil }
        switch visibility {
        case "public": return "公開を停止"
        case "unlisted": return "限定リンクを無効化"
        default: return nil
        }
    }

    static func deleteMessage(_ visibility: String) -> String {
        switch visibility {
        case "public", "unlisted":
            return "共有リンクも使えなくなり、クラウド上の3Dファイルも削除されます。"
        default:
            return "非公開で保存しているクラウド上の3Dファイルを削除します。この操作は元に戻せません。"
        }
    }
}
