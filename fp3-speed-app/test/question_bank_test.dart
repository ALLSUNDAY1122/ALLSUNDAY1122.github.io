import 'package:flutter_test/flutter_test.dart';
import 'package:fp3_speed_quiz/question_bank.dart';

void main() {
  test('無料120問と全600問の構成が正しい', () {
    expect(questionBank.length, fullQuestionCount);
    expect(fpDomains.length, 6);
    expect(accessibleQuestions(false).length, freeQuestionCount);
    expect(accessibleQuestions(true).length, fullQuestionCount);

    for (final String domain in fpDomains) {
      final List<Question> domainQuestions = questionBank
          .where((Question q) => q.domain == domain)
          .toList();
      final List<Question> freeDomainQuestions = domainQuestions
          .where((Question q) => q.access == QuestionAccess.free)
          .toList();

      expect(domainQuestions.length, fullQuestionsPerDomain);
      expect(freeDomainQuestions.length, freeQuestionsPerDomain);
    }
  });

  test('課金前はプレミアム問題を含まない', () {
    expect(
      accessibleQuestions(false)
          .every((Question q) => q.access == QuestionAccess.free),
      isTrue,
    );
    expect(
      questionBank
          .where((Question q) => q.access == QuestionAccess.premium)
          .length,
      480,
    );
  });

  test('問題IDと問題文が重複していない', () {
    expect(
      questionBank.map((Question q) => q.id).toSet().length,
      questionBank.length,
    );
    expect(
      questionBank.map((Question q) => q.statement).toSet().length,
      questionBank.length,
    );
  });

  test('15秒回答向けに問題文が短い', () {
    for (final Question q in questionBank) {
      expect(
        q.statement.length,
        lessThanOrEqualTo(42),
        reason: '${q.id}: ${q.statement}',
      );
    }
  });

  test('問題データの必須項目が空ではない', () {
    for (final Question q in questionBank) {
      expect(q.domain.trim(), isNotEmpty);
      expect(q.topic.trim(), isNotEmpty);
      expect(q.statement.trim(), isNotEmpty);
      expect(q.explanation.trim(), isNotEmpty);
      expect(fpDomains, contains(q.domain));
    }
  });

  test('各分野に○と×の両方が含まれる', () {
    for (final String domain in fpDomains) {
      final List<Question> questions = questionBank
          .where((Question q) => q.domain == domain)
          .toList();
      expect(questions.any((Question q) => q.answer), isTrue);
      expect(questions.any((Question q) => !q.answer), isTrue);
    }
  });
}
