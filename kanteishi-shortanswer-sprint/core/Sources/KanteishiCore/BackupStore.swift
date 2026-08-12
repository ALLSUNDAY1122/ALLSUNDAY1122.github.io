import Foundation

public enum BackupStore {
    public static func export(_ snapshot: ProgressSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    public static func importSnapshot(from data: Data) throws -> ProgressSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ProgressSnapshot.self, from: data)
    }
}

public enum StoreKitProductCatalog {
    // App Store Connect で正式値が確認されるまで空配列を維持する。
    // 推測した Product ID をコードへ入れない。
    public static let productIDs: [String] = []
    public static var isConfigured: Bool { !productIDs.isEmpty }
}
