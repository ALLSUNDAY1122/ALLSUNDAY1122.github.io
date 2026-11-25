import Foundation

struct StudyQuestion: Codable, Identifiable, Hashable {
    let id: String
    let year: Int
    let questionNumber: Int
    let question: String
    let choices: [String]
    let correctIndex: Int
    let sourceLabel: String
    let sourceUrl: String
    let modified: Bool
    let modificationNote: String?
    let representationChanged: Bool
    let domain: String?
    let publishable: Bool
    let releaseEligible: Bool
    var category: String { domain ?? "未分類" }
    var primaryEvidence: String { sourceLabel }
    var originType: String { "ipa_published_verbatim" }
    var officialYear: Int? { year }
    var officialNumber: Int? { questionNumber }
    var sourceFigureName: String? { nil }
    var sourceFigureAlt: String? { nil }
    var explanation: String { "解説は未収録です。" }
}
private struct QuestionBank: Decodable {
    let questions: [StudyQuestion]
}

enum QuestionStore {
    private static let all: [StudyQuestion] = {
        guard let url = Bundle.main.url(forResource: "official-500", withExtension: "json") else {
            assertionFailure("official-500.json is missing from app resources")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(QuestionBank.self, from: data).questions
            precondition(decoded.count == 500, "Expected 500 questions")
            precondition(Set(decoded.map(\.id)).count == decoded.count, "Duplicate question IDs")
            precondition(decoded.allSatisfy { $0.choices.count == 4 && (0..<4).contains($0.correctIndex) }, "Invalid question shape")
            return decoded
        } catch {
            assertionFailure("Question decode failed: \(error)")
            return []
        }
    }()

    static let freeYear = 2026

    static func accessible(premium: Bool) -> [StudyQuestion] {
        all.filter { premium || $0.year == freeYear }
    }

    static func questions(domain: String, premium: Bool) -> [StudyQuestion] {
        accessible(premium: premium).filter { $0.domain == domain }
    }

    static var availableOfficialYears: [Int] {
        Array(Set(all.filter { $0.originType == "ipa_published_verbatim" }.compactMap(\.officialYear))).sorted(by: >)
    }

    static func officialExam(year: Int, premium: Bool) -> [StudyQuestion] {
        accessible(premium: premium).filter { $0.originType == "ipa_published_verbatim" && $0.officialYear == year }
            .sorted { ($0.officialNumber ?? 0) < ($1.officialNumber ?? 0) }
    }

    static func daily(limit: Int = 8, premium: Bool) -> [StudyQuestion] {
        let domains = ["strategy", "management", "technology"]
        var buckets = Dictionary(uniqueKeysWithValues: domains.map { ($0, questions(domain: $0, premium: premium)) })
        var output: [StudyQuestion] = []
        while output.count < limit {
            var added = false
            for domain in domains where output.count < limit {
                if var bucket = buckets[domain], !bucket.isEmpty {
                    output.append(bucket.removeFirst())
                    buckets[domain] = bucket
                    added = true
                }
            }
            if !added { break }
        }
        if output.count < limit {
            let used = Set(output.map(\.id))
            output.append(contentsOf: accessible(premium: premium).filter { !used.contains($0.id) }.prefix(limit - output.count))
        }
        return output
    }
}
