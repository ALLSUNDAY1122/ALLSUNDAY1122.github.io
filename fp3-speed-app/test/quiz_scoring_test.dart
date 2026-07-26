import 'package:flutter_test/flutter_test.dart';
import 'package:fp3_speed_quiz/quiz_scoring.dart';

void main() {
  test('正解でコンボとスコアが増える', () {
    final QuizSessionScore score = QuizSessionScore();
    score.register(isCorrect: true, remainingFraction: 1);
    expect(score.combo, 1);
    expect(score.bestCombo, 1);
    expect(score.score, 155);

    score.register(isCorrect: true, remainingFraction: 0.5);
    expect(score.combo, 2);
    expect(score.bestCombo, 2);
    expect(score.score, 290);
  });

  test('不正解で現在コンボだけが0になる', () {
    final QuizSessionScore score = QuizSessionScore();
    score.register(isCorrect: true, remainingFraction: 0.8);
    final int before = score.score;
    score.register(isCorrect: false, remainingFraction: 0.2);
    expect(score.combo, 0);
    expect(score.bestCombo, 1);
    expect(score.score, before);
  });

  test('コンボ加点は20連続で上限になる', () {
    final QuizSessionScore score = QuizSessionScore();
    for (int i = 0; i < 25; i += 1) {
      score.register(isCorrect: true, remainingFraction: 0);
    }
    final int before = score.score;
    score.register(isCorrect: true, remainingFraction: 0);
    expect(score.score - before, 200);
    expect(score.combo, 26);
    expect(score.bestCombo, 26);
  });

  test('残り時間の割合は0から1へ制限される', () {
    final QuizSessionScore score = QuizSessionScore();
    score.register(isCorrect: true, remainingFraction: 2);
    expect(score.score, 155);
    score.register(isCorrect: true, remainingFraction: -1);
    expect(score.score, 265);
  });
}
