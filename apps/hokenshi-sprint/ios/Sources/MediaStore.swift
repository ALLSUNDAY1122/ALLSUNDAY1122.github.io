import UIKit

/// 図表画像。figures-1/2.json（id → PNG の Base64）を遅延読み込みしてキャッシュする。
enum FigureStore {
    private static var base64ByID: [String: String]?
    private static var cache: [String: UIImage] = [:]

    static func hasFigure(_ questionID: String) -> Bool {
        loadIfNeeded()
        return base64ByID?[questionID] != nil
    }

    static func image(for questionID: String) -> UIImage? {
        if let cached = cache[questionID] { return cached }
        loadIfNeeded()
        guard let encoded = base64ByID?[questionID],
              let data = Data(base64Encoded: encoded),
              let image = UIImage(data: data) else { return nil }
        cache[questionID] = image
        return image
    }

    private static func loadIfNeeded() {
        guard base64ByID == nil else { return }
        var merged: [String: String] = [:]
        for name in ["figures-1", "figures-2"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
                merged.merge(decoded) { _, new in new }
            }
        }
        base64ByID = merged
    }
}
