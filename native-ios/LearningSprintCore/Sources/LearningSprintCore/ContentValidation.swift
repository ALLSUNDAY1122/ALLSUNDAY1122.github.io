import Foundation

public struct ContentValidationIssue: Codable, Equatable, Sendable {
    public enum Severity: String, Codable, Sendable { case error, warning }
    public let severity: Severity
    public let questionID: String?
    public let message: String

    public init(severity: Severity, questionID: String? = nil, message: String) {
        self.severity = severity
        self.questionID = questionID
        self.message = message
    }
}

public enum ContentValidator {
    public static func validate(
        questions: [LearningQuestion],
        expectedContentVersion: String,
        expectedLawBaselineDate: String? = nil
    ) -> [ContentValidationIssue] {
        var issues: [ContentValidationIssue] = []
        var ids = Set<String>()
        var normalizedPrompts = [String: String]()

        if questions.isEmpty {
            issues.append(.init(severity: .error, message: "問題が0件です"))
        }

        for question in questions {
            if question.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(severity: .error, message: "idが空です"))
            } else if !ids.insert(question.id).inserted {
                issues.append(.init(severity: .error, questionID: question.id, message: "idが重複しています"))
            }
            if question.subject.isEmpty || question.topic.isEmpty || question.prompt.isEmpty {
                issues.append(.init(severity: .error, questionID: question.id, message: "科目・論点・問題文の必須値が不足しています"))
            }
            if question.memoryPoint.isEmpty || question.explanation.isEmpty {
                issues.append(.init(severity: .error, questionID: question.id, message: "要点または解説が不足しています"))
            }
            if question.contentVersion != expectedContentVersion {
                issues.append(.init(severity: .error, questionID: question.id, message: "contentVersionが正本と不一致です"))
            }
            if let expectedLawBaselineDate, question.lawBaselineDate != expectedLawBaselineDate {
                issues.append(.init(severity: .warning, questionID: question.id, message: "lawBaselineDateがアクティブ基準日と異なります"))
            }
            if !isISODate(question.sourceCheckedAt) {
                issues.append(.init(severity: .error, questionID: question.id, message: "sourceCheckedAtがYYYY-MM-DDではありません"))
            }
            if !isISODate(question.lawBaselineDate) {
                issues.append(.init(severity: .error, questionID: question.id, message: "lawBaselineDateがYYYY-MM-DDではありません"))
            }
            if question.sourceTitle == nil && question.sourceURL == nil && question.sourceRefs.isEmpty {
                issues.append(.init(severity: .warning, questionID: question.id, message: "問題単位の出典参照がありません"))
            }

            let signature = normalize(question.prompt)
            if let first = normalizedPrompts[signature] {
                issues.append(.init(severity: .error, questionID: question.id, message: "問題文が\(first)と重複しています"))
            } else if !signature.isEmpty {
                normalizedPrompts[signature] = question.id
            }

            switch question.answerType {
            case .singleChoice:
                if question.choices.count < 2 || question.correctIndices.count != 1 {
                    issues.append(.init(severity: .error, questionID: question.id, message: "singleChoiceの選択肢または正答が不正です"))
                }
            case .multiChoice:
                if question.choices.count < 2 || question.correctIndices.count < 2 {
                    issues.append(.init(severity: .error, questionID: question.id, message: "multiChoiceの選択肢または正答が不正です"))
                }
            case .numeric:
                if question.correctNumber == nil || (question.unit ?? "").isEmpty {
                    issues.append(.init(severity: .error, questionID: question.id, message: "numericの正答または単位が不足しています"))
                }
            case .blankSelect:
                if question.blanks.isEmpty {
                    issues.append(.init(severity: .error, questionID: question.id, message: "blankSelectの空欄定義がありません"))
                }
            case .declaration:
                if question.declarationFields.isEmpty {
                    issues.append(.init(severity: .error, questionID: question.id, message: "declarationの入力欄定義がありません"))
                }
            }
        }
        return issues
    }

    private static func isISODate(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .punctuationCharacters)
    }
}
