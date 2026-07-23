import 'package:flutter_test/flutter_test.dart';
import 'package:shiwake_swipe/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('4つの問題パックから88カードを読み込む', () async {
    final questions = await QuestionRepository.load();

    expect(questions, hasLength(88));
    expect(questions.map((question) => question.id).toSet(), hasLength(88));
    expect(questions.where((question) => question.correctSide == AnswerSide.debit), hasLength(44));
    expect(questions.where((question) => question.correctSide == AnswerSide.credit), hasLength(44));
  });

  test('回答履歴と最高コンボを更新する', () {
    final first = const LearningStats().record(questionId: 'q001', isCorrect: true, combo: 1);
    final second = first.record(questionId: 'q001', isCorrect: false, combo: 0);

    expect(second.total, 2);
    expect(second.correct, 1);
    expect(second.bestCombo, 1);
    expect(second.questionStats['q001']?.attempts, 2);
    expect(second.questionStats['q001']?.correct, 1);
  });
}
