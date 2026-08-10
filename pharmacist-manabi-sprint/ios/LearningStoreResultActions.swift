import Foundation

@MainActor
extension LearningStore {
    func reviewWrongCurrent() {
        guard let current = state.inProgress else { return }
        let wrongIDs = current.answers.filter { !$0.correct }.map(\.questionID)
        guard !wrongIDs.isEmpty else { return }
        var orders: [String: [Int]] = [:]
        for id in wrongIDs {
            guard let q = questionMap[id] else { continue }
            orders[id] = current.choiceOrders[id] ?? Array(q.availableChoices.indices)
        }
        state.inProgress = ActiveSession(
            title: "間違えた問題を復習",
            field: "苦手復習",
            ids: wrongIDs,
            index: 0,
            answers: [],
            choiceOrders: orders,
            mockKey: nil
        )
        feedback = nil
        selectedAnswers = []
        route = .quiz
        updateShuffleQuestions(state.shuffleQuestions)
    }

    func repeatCurrentSession() {
        guard let current = state.inProgress, !current.ids.isEmpty else { return }
        state.inProgress = ActiveSession(
            title: current.title,
            field: current.field,
            ids: current.ids,
            index: 0,
            answers: [],
            choiceOrders: current.choiceOrders,
            mockKey: current.mockKey
        )
        feedback = nil
        selectedAnswers = []
        route = .quiz
        updateShuffleQuestions(state.shuffleQuestions)
    }
}
