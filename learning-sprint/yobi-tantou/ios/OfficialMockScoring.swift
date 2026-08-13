import Foundation

/// Official-year mock scoring is deliberately separate from the ordinary
/// StudyQuestion correct/incorrect flow. Official short-answer questions can
/// contain multiple response slots and partial-credit rules.
struct OfficialResponseSlot: Codable, Equatable, Identifiable {
    let id: String
    let correctOption: Int
}

struct OfficialScoreBand: Codable, Equatable {
    /// Minimum number of correct response slots required for this point award.
    let minimumCorrect: Int
    let points: Int
}

struct OfficialMockQuestionScoring: Codable, Equatable, Identifiable {
    let id: String
    let examYear: Int
    let subject: String
    let questionNumber: Int
    let maxPoints: Int
    let responseSlots: [OfficialResponseSlot]
    /// Bands are evaluated from the highest minimumCorrect downward.
    /// A missing band means zero points below the first threshold.
    let scoreBands: [OfficialScoreBand]
    let sourceURL: String
    let verifiedAt: String

    func score(responses: [String: Int]) -> Int {
        let correctCount = responseSlots.reduce(into: 0) { count, slot in
            if responses[slot.id] == slot.correctOption { count += 1 }
        }
        let awarded = scoreBands
            .sorted { $0.minimumCorrect > $1.minimumCorrect }
            .first { correctCount >= $0.minimumCorrect }?
            .points ?? 0
        return min(max(awarded, 0), maxPoints)
    }

    var isStructurallyValid: Bool {
        guard examYear >= 2024,
              questionNumber > 0,
              maxPoints > 0,
              !subject.isEmpty,
              !responseSlots.isEmpty,
              Set(responseSlots.map(\.id)).count == responseSlots.count,
              responseSlots.allSatisfy({ $0.correctOption >= 0 }),
              !scoreBands.isEmpty,
              scoreBands.allSatisfy({ $0.minimumCorrect > 0 && $0.minimumCorrect <= responseSlots.count && $0.points > 0 && $0.points <= maxPoints }),
              scoreBands.map(\.minimumCorrect).count == Set(scoreBands.map(\.minimumCorrect)).count,
              scoreBands.map(\.points).max() == maxPoints,
              URL(string: sourceURL)?.scheme == "https"
        else { return false }
        return true
    }
}

struct OfficialMockScoreResult: Equatable {
    let earnedPoints: Int
    let maxPoints: Int
    let answeredQuestions: Int
}

enum OfficialMockScorer {
    static func score(
        questions: [OfficialMockQuestionScoring],
        responses: [String: [String: Int]]
    ) -> OfficialMockScoreResult {
        var earned = 0
        var maximum = 0
        var answered = 0
        for question in questions {
            guard question.isStructurallyValid else { continue }
            maximum += question.maxPoints
            let answer = responses[question.id] ?? [:]
            if !answer.isEmpty { answered += 1 }
            earned += question.score(responses: answer)
        }
        return OfficialMockScoreResult(earnedPoints: earned, maxPoints: maximum, answeredQuestions: answered)
    }
}
