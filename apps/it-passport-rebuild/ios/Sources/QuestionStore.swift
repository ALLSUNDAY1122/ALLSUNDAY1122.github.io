import Foundation

struct StudyQuestion: Codable, Identifiable, Hashable {
    let id: String
    let examBatch: String
    let domain: String
    let category: String
    let topic: String
    let question: String
    let choices: [String]
    let correctIndex: Int
    let explanation: String
    let primaryEvidence: String
    let sourceUrl: String
    let syllabusVersion: String
    let legalDate: String
    let originType: String
    let copyrightBasis: String
}

enum QuestionStore {
    static let all: [StudyQuestion] = {
        guard let url = Bundle.main.url(forResource: "starter-v1", withExtension: "json") else {
            assertionFailure("starter-v1.json is missing from app resources")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([StudyQuestion].self, from: data)
            precondition(Set(decoded.map(\.id)).count == decoded.count, "Duplicate question IDs")
            precondition(decoded.allSatisfy { $0.choices.count == 4 && (0..<4).contains($0.correctIndex) }, "Invalid question shape")
            return decoded
        } catch {
            assertionFailure("Question decode failed: \(error)")
            return []
        }
    }()

    static func questions(domain: String) -> [StudyQuestion] {
        all.filter { $0.domain == domain }
    }

    static func daily(limit: Int = 8) -> [StudyQuestion] {
        let domains = ["strategy", "management", "technology"]
        var buckets = Dictionary(uniqueKeysWithValues: domains.map { ($0, questions(domain: $0)) })
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
        return output
    }
}
