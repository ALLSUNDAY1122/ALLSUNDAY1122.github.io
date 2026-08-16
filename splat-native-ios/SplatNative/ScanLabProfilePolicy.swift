import Foundation

enum ScanLabProfileUpdateError: LocalizedError, Equatable {
    case handleUnavailable

    var errorDescription: String? {
        switch self {
        case .handleUnavailable:
            return "このユーザーIDは使用されています。別のIDを入力してください。"
        }
    }
}

enum ScanLabProfilePolicy {
    static func mapsToHandleUnavailable(postgrestCode: String?) -> Bool {
        postgrestCode == "23505"
    }
}
