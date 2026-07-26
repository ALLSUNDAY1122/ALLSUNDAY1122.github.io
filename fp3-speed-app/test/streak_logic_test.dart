import 'package:flutter_test/flutter_test.dart';
import 'package:fp3_speed_quiz/streak_logic.dart';

void main() {
  test('初回学習は連続1日になる', () {
    final StreakUpdate result = calculateStreakUpdate(
      now: DateTime(2026, 7, 26, 22, 30),
      lastStudyDate: null,
      currentStreak: 0,
      currentLongestStreak: 0,
    );
    expect(result.lastStudyDate, '2026-07-26');
    expect(result.streak, 1);
    expect(result.longestStreak, 1);
  });

  test('同じ日の再学習では連続日数を増やさない', () {
    final StreakUpdate result = calculateStreakUpdate(
      now: DateTime(2026, 7, 26, 23, 59),
      lastStudyDate: '2026-07-26',
      currentStreak: 4,
      currentLongestStreak: 8,
    );
    expect(result.streak, 4);
    expect(result.longestStreak, 8);
  });

  test('前日から続けると連続日数を1増やす', () {
    final StreakUpdate result = calculateStreakUpdate(
      now: DateTime(2026, 7, 26),
      lastStudyDate: '2026-07-25',
      currentStreak: 4,
      currentLongestStreak: 4,
    );
    expect(result.streak, 5);
    expect(result.longestStreak, 5);
  });

  test('1日以上空くと連続日数を1へ戻す', () {
    final StreakUpdate result = calculateStreakUpdate(
      now: DateTime(2026, 7, 26),
      lastStudyDate: '2026-07-24',
      currentStreak: 9,
      currentLongestStreak: 12,
    );
    expect(result.streak, 1);
    expect(result.longestStreak, 12);
  });

  test('月またぎでも前日を正しく判定する', () {
    final StreakUpdate result = calculateStreakUpdate(
      now: DateTime(2026, 8, 1),
      lastStudyDate: '2026-07-31',
      currentStreak: 2,
      currentLongestStreak: 2,
    );
    expect(result.streak, 3);
    expect(result.lastStudyDate, '2026-08-01');
  });
}
