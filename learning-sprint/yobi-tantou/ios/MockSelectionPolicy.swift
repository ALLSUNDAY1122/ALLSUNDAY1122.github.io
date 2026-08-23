import Foundation

enum MockSelectionPolicy {
    static let generalEducationSubject = "一般教養"
    static let generalEducationAnswerLimit = 20

    static func select(
        from yearQuestions: [StudyQuestion],
        shuffleGeneralEducation: Bool = true
    ) -> [StudyQuestion] {
        let legal = yearQuestions.filter { $0.subject != generalEducationSubject }
        var general = yearQuestions.filter { $0.subject == generalEducationSubject }
        if shuffleGeneralEducation {
            general.shuffle()
        }
        let selectedGeneral = Array(general.prefix(generalEducationAnswerLimit))
        return legal + selectedGeneral
    }

    static func summary(for yearQuestions: [StudyQuestion]) -> MockSelectionSummary {
        let legalCount = yearQuestions.filter { $0.subject != generalEducationSubject }.count
        let generalAvailable = yearQuestions.filter { $0.subject == generalEducationSubject }.count
        return MockSelectionSummary(
            legalCount: legalCount,
            generalEducationAvailable: generalAvailable,
            generalEducationSelected: min(generalEducationAnswerLimit, generalAvailable)
        )
    }
}

struct MockSelectionSummary: Equatable {
    let legalCount: Int
    let generalEducationAvailable: Int
    let generalEducationSelected: Int

    var totalScoredQuestions: Int { legalCount + generalEducationSelected }
}
