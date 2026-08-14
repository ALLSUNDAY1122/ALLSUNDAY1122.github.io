import Foundation

enum LearningAccessPolicy {
    static let freeQuestionLimit = 24
    static let freePerEditionSubject = 4

    static func freeQuestionIDs(in questions: [AppQuestion]) -> Set<String> {
        let groups = Dictionary(grouping: questions) { question in
            "\(question.edition)|\(question.subject)"
        }
        var selected = Set<String>()

        for key in groups.keys.sorted() {
            guard let group = groups[key] else { continue }
            let byDomain = Dictionary(grouping: group) { $0.domain }
            let domains = byDomain.keys.sorted {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
            var offsets = Dictionary(uniqueKeysWithValues: domains.map { ($0, 0) })
            var groupCount = 0

            while groupCount < freePerEditionSubject {
                var madeProgress = false
                for domain in domains where groupCount < freePerEditionSubject {
                    let bucket = (byDomain[domain] ?? []).sorted {
                        if $0.questionNo == $1.questionNo { return $0.id < $1.id }
                        return $0.questionNo < $1.questionNo
                    }
                    let offset = offsets[domain, default: 0]
                    guard offset < bucket.count else { continue }
                    selected.insert(bucket[offset].id)
                    offsets[domain] = offset + 1
                    groupCount += 1
                    madeProgress = true
                }
                if !madeProgress { break }
            }
        }
        return selected
    }

    static func accessibleQuestionIDs(
        _ ids: [String],
        allQuestions: [AppQuestion],
        isPremium: Bool
    ) -> [String] {
        guard !isPremium else { return ids }
        let freeIDs = freeQuestionIDs(in: allQuestions)
        return ids.filter { freeIDs.contains($0) }
    }

    static func requiresPremium(
        questionIDs: [String],
        allQuestions: [AppQuestion]
    ) -> Bool {
        let freeIDs = freeQuestionIDs(in: allQuestions)
        return questionIDs.contains { !freeIDs.contains($0) }
    }
}

@MainActor
extension LearningStore {
    func accessibleQuestionIDs(_ ids: [String], isPremium: Bool) -> [String] {
        LearningAccessPolicy.accessibleQuestionIDs(
            ids,
            allQuestions: repository.questions,
            isPremium: isPremium
        )
    }

    func accessibleQuestions(_ questions: [AppQuestion], isPremium: Bool) -> [AppQuestion] {
        let allowed = Set(accessibleQuestionIDs(questions.map(\.id), isPremium: isPremium))
        return questions.filter { allowed.contains($0.id) }
    }

    func accessibleQuestionCount(_ questions: [AppQuestion], isPremium: Bool) -> Int {
        accessibleQuestions(questions, isPremium: isPremium).count
    }

    func accessibleWeakQuestions(isPremium: Bool) -> [AppQuestion] {
        accessibleQuestions(weakQuestions, isPremium: isPremium)
    }

    func requiresPremium(questionIDs: [String]) -> Bool {
        LearningAccessPolicy.requiresPremium(
            questionIDs: questionIDs,
            allQuestions: repository.questions
        )
    }

    @discardableResult
    func startToday(isPremium: Bool) -> Bool {
        guard !isPremium else {
            startToday()
            return true
        }
        let free = accessibleQuestions(repository.questions, isPremium: false).shuffled()
        let selected = Array(free.prefix(min(todaySessionTarget, free.count)))
        guard !selected.isEmpty else { return false }
        startSession(
            key: "today",
            questions: selected,
            title: "今日のスプリント",
            mode: .practice
        )
        return true
    }

    @discardableResult
    func startWeak(isPremium: Bool) -> Bool {
        guard !isPremium else {
            startWeak()
            return true
        }
        let questions = accessibleWeakQuestions(isPremium: false).shuffled()
        guard !questions.isEmpty else { return false }
        startSession(
            key: "weak",
            questions: questions,
            title: "苦手をつぶす",
            mode: .practice
        )
        return true
    }

    @discardableResult
    func startDomain(_ domain: String, isPremium: Bool) -> Bool {
        guard !isPremium else {
            startDomain(domain)
            return true
        }
        let questions = accessibleQuestions(repository.questions(domain: domain), isPremium: false)
        let selected = Array(questions.shuffled().prefix(settings.dailyGoal))
        guard !selected.isEmpty else { return false }
        startSession(
            key: "domain:\(domain)",
            questions: selected,
            title: domain,
            mode: .practice
        )
        return true
    }

    @discardableResult
    func startEditionSubject(edition: Int, subject: String, isPremium: Bool) -> Bool {
        guard !isPremium else {
            startEditionSubject(edition: edition, subject: subject)
            return true
        }
        let questions = repository.questions(edition: edition).filter { $0.subject == subject }
        let allowed = accessibleQuestions(questions, isPremium: false)
        guard !allowed.isEmpty else { return false }
        startSession(
            key: "exam:\(edition):subject:\(subject)",
            questions: allowed,
            title: "令和\(edition - 2018)年・\(subject)",
            mode: .practice
        )
        return true
    }

    @discardableResult
    func startMock(edition: Int, isPremium: Bool) -> Bool {
        guard isPremium else { return false }
        startMock(edition: edition)
        return true
    }

    @discardableResult
    func resumeSession(isPremium: Bool) -> Bool {
        guard let inProgress = state.inProgress else { return false }
        guard isPremium || !requiresPremium(questionIDs: inProgress.questionIDs) else { return false }
        resumeSession()
        return true
    }

    @discardableResult
    func retryQuestions(_ ids: [String], title: String, isPremium: Bool) -> Bool {
        let allowed = accessibleQuestionIDs(ids, isPremium: isPremium)
        guard !allowed.isEmpty else { return false }
        retryQuestions(allowed, title: title)
        return true
    }
}
