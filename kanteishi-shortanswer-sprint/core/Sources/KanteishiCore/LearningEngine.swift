import Foundation

public enum LearningEngine {
    public static let standardSprintCount = 8
    public static let targetOfficialEditions: [ExamEdition] = [.reiwa8, .reiwa7, .reiwa6]
    public static let targetOfficialQuestionCount = targetOfficialEditions.reduce(0) { $0 + $1.officialQuestionCountTotal }

    public static func standardSprint(from questions: [Question]) -> [Question] {
        Array(questions.shuffled().prefix(standardSprintCount))
    }

    public static func questions(
        from questions: [Question],
        edition: ExamEdition? = nil,
        subject: ExamSubject? = nil,
        domain: String? = nil
    ) -> [Question] {
        questions.filter { question in
            (edition == nil || question.edition == edition) &&
            (subject == nil || question.subject == subject) &&
            (domain == nil || question.domain == domain)
        }
    }

    public static func weakQuestionIDs(from attempts: [AttemptRecord]) -> Set<String> {
        let grouped = Dictionary(grouping: attempts, by: \.questionID)
        return Set(grouped.compactMap { questionID, records in
            let ordered = records.sorted { $0.answeredAt < $1.answeredAt }
            let tail = ordered.suffix(3)
            if tail.count == 3 && tail.allSatisfy(\.isCorrect) {
                return nil
            }
            return ordered.contains(where: { !$0.isCorrect }) ? questionID : nil
        })
    }

    public static func uncertainQuestionIDs(from attempts: [AttemptRecord]) -> Set<String> {
        Set(attempts.filter(\.isUncertain).map(\.questionID))
    }

    public static func auditProductionQuestions(_ questions: [Question]) -> [String] {
        var issues: [String] = []
        let ids = questions.map(\.id)
        let duplicates = Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys.sorted()
        if !duplicates.isEmpty {
            issues.append("duplicateIDs:\(duplicates.joined(separator: ","))")
        }
        let unready = questions.filter { !$0.isProductionReady }.map(\.id).sorted()
        if !unready.isEmpty {
            issues.append("notProductionReady:\(unready.joined(separator: ","))")
        }
        return issues
    }
}
