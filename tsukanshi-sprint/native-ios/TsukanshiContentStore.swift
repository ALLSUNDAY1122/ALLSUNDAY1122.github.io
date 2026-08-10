import Foundation
import LearningSprintCore

struct TsukanshiNativeContentBank: Codable {
    let schemaVersion: Int
    let contentVersion: String
    let lawBaselineDate: String
    let exportedAt: String
    let studyQuestionCount: Int
    let declarationCount: Int
    let freeNumericCount: Int
    let questions: [LearningQuestion]
}

final class TsukanshiContentStore {
    let bank: TsukanshiNativeContentBank
    let questions: [LearningQuestion]

    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "tsukanshi-questions", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSLocalizedDescriptionKey: "tsukanshi-questions.json が見つかりません"])
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        bank = try decoder.decode(TsukanshiNativeContentBank.self, from: data)
        questions = bank.questions

        guard bank.studyQuestionCount == 480,
              bank.declarationCount == 12,
              questions.count == 492 else {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: "監査済み問題件数が正本と一致しません"])
        }
        let issues = ContentValidator.validate(
            questions: questions,
            expectedContentVersion: bank.contentVersion,
            expectedLawBaselineDate: bank.lawBaselineDate
        )
        let errors = issues.filter { $0.severity == .error }
        guard errors.isEmpty else {
            let summary = errors.prefix(3).map { "\($0.questionID ?? "GLOBAL"): \($0.message)" }.joined(separator: " / ")
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSLocalizedDescriptionKey: summary])
        }
    }

    var studyQuestions: [LearningQuestion] {
        questions.filter { $0.answerType != .declaration }
    }

    var declarationQuestions: [LearningQuestion] {
        questions.filter { $0.answerType == .declaration }
    }

    func questions(subject: String, premium: Bool) -> [LearningQuestion] {
        questions.filter { $0.subject == subject && (premium || !$0.premium) }
    }

    func mockQuestions(round: String, subject: String, premium: Bool) -> [LearningQuestion] {
        let count = TsukanshiNativeConfig.mockQuestionCountBySubject[subject] ?? 8
        let candidates = questions.filter { $0.subject == subject && (premium || !$0.premium) }
        guard candidates.count >= count else { return candidates }
        let seedString = "tsukanshi|\(round)|\(subject)|\(bank.contentVersion)"
        var generator = NativeLCG(state: fnv1a(seedString))
        var shuffled = candidates
        if shuffled.count > 1 {
            for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
                let swapIndex = Int(generator.next() % UInt64(index + 1))
                if swapIndex != index { shuffled.swapAt(index, swapIndex) }
            }
        }
        return Array(shuffled.prefix(count))
    }

    private func fnv1a(_ value: String) -> UInt64 {
        value.utf8.reduce(UInt64(1469598103934665603)) { partial, byte in
            (partial ^ UInt64(byte)) &* 1099511628211
        }
    }
}

private struct NativeLCG {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
