import Foundation

enum QuestionBankKind {
    case preview
    case release
}

enum QuestionBankError: LocalizedError, Equatable {
    case missingPreview
    case empty
    case duplicateID(String)
    case invalidQuestion(String)
    case invalidReleaseGate(String)
    case officialMockRequiresDedicatedBank(String)

    var errorDescription: String? {
        switch self {
        case .missingPreview:
            return "questions.preview.json がありません。"
        case .empty:
            return "教材データが空です。"
        case .duplicateID(let id):
            return "問題IDが重複しています: \(id)"
        case .invalidQuestion(let id):
            return "問題データが不正です: \(id)"
        case .invalidReleaseGate(let id):
            return "監査未完了または用途不明の問題が正式教材へ混入しています: \(id)"
        case .officialMockRequiresDedicatedBank(let id):
            return "公式年度模試問題を通常練習バンクへ混入できません: \(id)"
        }
    }
}

struct QuestionRepository {
    static let officialSubjects: Set<String> = [
        "憲法", "行政法", "民法", "商法", "民事訴訟法", "刑法", "刑事訴訟法", "一般教養"
    ]
    static let legalSubjects = officialSubjects.subtracting(["一般教養"])

    private let decoder = JSONDecoder()

    func load(bundle: Bundle) throws -> [StudyQuestion] {
        if let releaseURL = bundle.url(forResource: "questions.release", withExtension: "json") {
            let data = try Data(contentsOf: releaseURL)
            return try decode(data, kind: .release)
        }

        guard let previewURL = bundle.url(forResource: "questions.preview", withExtension: "json") else {
            throw QuestionBankError.missingPreview
        }
        let data = try Data(contentsOf: previewURL)
        return try decode(data, kind: .preview)
    }

    func decode(_ data: Data, kind: QuestionBankKind) throws -> [StudyQuestion] {
        let questions = try decoder.decode([StudyQuestion].self, from: data)
        guard !questions.isEmpty else { throw QuestionBankError.empty }

        var seen = Set<String>()
        for question in questions {
            guard seen.insert(question.id).inserted else {
                throw QuestionBankError.duplicateID(question.id)
            }
            try validateCommon(question)

            switch kind {
            case .preview:
                guard question.releaseEligible == false,
                      question.originType == "original_preview",
                      question.contentUse == nil else {
                    throw QuestionBankError.invalidQuestion(question.id)
                }
            case .release:
                try validateRelease(question)
            }
        }
        return questions
    }

    private func validateCommon(_ question: StudyQuestion) throws {
        guard !question.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !question.topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !question.stem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              question.choices.count >= 2,
              !question.correctIndices.isEmpty,
              Set(question.correctIndices).count == question.correctIndices.count,
              question.correctIndices.allSatisfy({ $0 >= 0 && $0 < question.choices.count }),
              !question.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !question.memory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !question.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              question.sourceURL.hasPrefix("https://"),
              isISODate(question.evidenceCheckedDate) else {
            throw QuestionBankError.invalidQuestion(question.id)
        }
    }

    private func validateRelease(_ question: StudyQuestion) throws {
        guard question.releaseEligible,
              question.originType != "original_preview",
              Self.officialSubjects.contains(question.subject),
              let contentUse = question.contentUse else {
            throw QuestionBankError.invalidReleaseGate(question.id)
        }

        switch contentUse {
        case .practice:
            // Original practice content is timeless learning material. Assigning an
            // official exam year would make it look like a reproduced past question.
            guard question.examYear == nil else {
                throw QuestionBankError.invalidReleaseGate(question.id)
            }
        case .officialMock:
            // Official-year questions require a separate bank that binds each item
            // to official response slots/partial-credit scoring and rights clearance.
            // The ordinary practice repository intentionally cannot load them.
            throw QuestionBankError.officialMockRequiresDedicatedBank(question.id)
        }

        if Self.legalSubjects.contains(question.subject) {
            guard let lawBasisDate = question.lawBasisDate,
                  isISODate(lawBasisDate) else {
                throw QuestionBankError.invalidReleaseGate(question.id)
            }
        }
    }

    private func isISODate(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter.date(from: value) != nil
    }
}
