import Foundation

struct RigakuQuestionMedia: Codable, Hashable {
    let questionID: String
    let assetName: String
    let accessibilityLabel: String
    let rightsBasis: String
    let sourceURL: String?
    let checkedAt: String
}

enum RigakuQuestionMediaRepository {
    static func loadBundled(bundle: Bundle = .main) throws -> [String: RigakuQuestionMedia] {
        guard let url = bundle.url(forResource: "media-manifest", withExtension: "json") else {
            return [:]
        }
        let data = try Data(contentsOf: url)
        let items = try JSONDecoder().decode([RigakuQuestionMedia].self, from: data)
        return Dictionary(uniqueKeysWithValues: items.map { ($0.questionID, $0) })
    }
}
