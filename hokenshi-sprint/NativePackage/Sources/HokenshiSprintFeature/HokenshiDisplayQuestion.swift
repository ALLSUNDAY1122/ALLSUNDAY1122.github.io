import Foundation
import LearningSprintCore

public extension HokenshiQuestionRecord {
    var displayQuestion: LearningQuestion {
        LearningQuestion(
            id: id,
            subject: subject,
            topic: topic,
            answerType: answerType,
            prompt: prompt,
            choices: choices,
            correctIndices: correctIndices,
            correctNumber: correctNumber,
            acceptedRange: acceptedRange,
            unit: unit,
            roundingRule: roundingRule,
            sourceText: scenarioText,
            memoryPoint: memoryPoint,
            explanation: explanation,
            sourceTitle: sourceTitle,
            sourceURL: sourceURL,
            sourceRefs: sourceRefs,
            sourceCheckedAt: sourceCheckedAt,
            lawBaselineDate: lawBaselineDate,
            contentVersion: contentVersion,
            premium: premium,
            examRound: "独自模試 第\(round)回",
            questionNumber: String(questionNumber),
            rightsBasis: rightsBasis
        )
    }
}
