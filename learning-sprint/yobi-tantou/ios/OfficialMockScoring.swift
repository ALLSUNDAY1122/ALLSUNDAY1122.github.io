import Foundation

/// Official-year mock scoring is deliberately separate from the ordinary
/// StudyQuestion correct/incorrect flow. Official short-answer questions can
/// contain multiple response slots, order-independent selections and partial credit.
struct OfficialResponseGroup: Codable, Equatable, Identifiable {
    let id: String
    let slotIDs: [String]
    let correctOptions: [Int]
    let orderSensitive: Bool

    var isStructurallyValid: Bool {
        !id.isEmpty
            && !slotIDs.isEmpty
            && slotIDs.count == correctOptions.count
            && Set(slotIDs).count == slotIDs.count
            && correctOptions.allSatisfy { $0 >= 0 }
    }

    func correctCount(responses: [String: Int]) -> Int {
        guard isStructurallyValid else { return 0 }
        if orderSensitive {
            return zip(slotIDs, correctOptions).reduce(into: 0) { count, pair in
                if responses[pair.0] == pair.1 { count += 1 }
            }
        }

        // Official tables may mark multiple answer boxes as 順不同. Count a
        // response as correct when its option can be matched to one remaining
        // official option, regardless of which response box was used.
        var remaining: [Int: Int] = [:]
        for option in correctOptions { remaining[option, default: 0] += 1 }
        var count = 0
        for slotID in slotIDs {
            guard let option = responses[slotID], let available = remaining[option], available > 0 else { continue }
            count += 1
            if available == 1 { remaining.removeValue(forKey: option) }
            else { remaining[option] = available - 1 }
        }
        return count
    }
}

struct OfficialScoreBand: Codable, Equatable {
    /// Minimum number of correct response boxes required for this point award.
    let minimumCorrect: Int
    let points: Int
}

struct OfficialMockQuestionScoring: Codable, Equatable, Identifiable {
    let id: String
    let examYear: Int
    let subject: String
    let questionNumber: Int
    let maxPoints: Int
    let responseGroups: [OfficialResponseGroup]
    /// Bands are evaluated from the highest minimumCorrect downward.
    /// A missing band means zero points below the first threshold.
    let scoreBands: [OfficialScoreBand]
    let sourceURL: String
    let verifiedAt: String

    var responseSlotCount: Int { responseGroups.reduce(0) { $0 + $1.slotIDs.count } }

    func score(responses: [String: Int]) -> Int {
        let correctCount = responseGroups.reduce(0) { $0 + $1.correctCount(responses: responses) }
        let awarded = scoreBands
            .sorted { $0.minimumCorrect > $1.minimumCorrect }
            .first { correctCount >= $0.minimumCorrect }?
            .points ?? 0
        return min(max(awarded, 0), maxPoints)
    }

    var isStructurallyValid: Bool {
        let allSlotIDs = responseGroups.flatMap(\.slotIDs)
        guard examYear >= 2024,
              questionNumber > 0,
              maxPoints > 0,
              !subject.isEmpty,
              !responseGroups.isEmpty,
              responseGroups.allSatisfy(\.isStructurallyValid),
              Set(allSlotIDs).count == allSlotIDs.count,
              !scoreBands.isEmpty,
              scoreBands.allSatisfy({ $0.minimumCorrect > 0 && $0.minimumCorrect <= responseSlotCount && $0.points > 0 && $0.points <= maxPoints }),
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
