import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'question_bank.dart';
import 'streak_logic.dart';

class AnswerRecord {
  AnswerRecord({
    required this.attempts,
    required this.correct,
    required this.lastCorrect,
  });

  int attempts;
  int correct;
  bool lastCorrect;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'attempts': attempts,
        'correct': correct,
        'lastCorrect': lastCorrect,
      };

  factory AnswerRecord.fromJson(Map<String, dynamic> json) {
    return AnswerRecord(
      attempts: json['attempts'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      lastCorrect: json['lastCorrect'] as bool? ?? false,
    );
  }
}

class DayRecord {
  DayRecord({required this.answered, required this.correct});

  int answered;
  int correct;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'answered': answered,
        'correct': correct,
      };

  factory DayRecord.fromJson(Map<String, dynamic> json) {
    return DayRecord(
      answered: json['answered'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
    );
  }
}

class ProgressStore {
  ProgressStore._(this._prefs);

  static const String _recordsKey = 'fp3_records_v1';
  static const String _daysKey = 'fp3_days_v1';
  static const String _lastStudyKey = 'fp3_last_study_v1';
  static const String _streakKey = 'fp3_streak_v1';
  static const String _longestStreakKey = 'fp3_longest_streak_v1';

  final SharedPreferencesAsync _prefs;
  final Map<String, AnswerRecord> records = <String, AnswerRecord>{};
  final Map<String, DayRecord> days = <String, DayRecord>{};

  String? lastStudyDate;
  int streak = 0;
  int longestStreak = 0;

  static Future<ProgressStore> load() async {
    final SharedPreferencesAsync prefs = SharedPreferencesAsync();
    final ProgressStore store = ProgressStore._(prefs);
    await store._restore();
    return store;
  }

  Future<void> _restore() async {
    final String? rawRecords = await _prefs.getString(_recordsKey);
    if (rawRecords != null) {
      final Map<String, dynamic> decoded =
          jsonDecode(rawRecords) as Map<String, dynamic>;
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        records[entry.key] = AnswerRecord.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    final String? rawDays = await _prefs.getString(_daysKey);
    if (rawDays != null) {
      final Map<String, dynamic> decoded =
          jsonDecode(rawDays) as Map<String, dynamic>;
      for (final MapEntry<String, dynamic> entry in decoded.entries) {
        days[entry.key] = DayRecord.fromJson(
          entry.value as Map<String, dynamic>,
        );
      }
    }

    lastStudyDate = await _prefs.getString(_lastStudyKey);
    streak = await _prefs.getInt(_streakKey) ?? 0;
    longestStreak = await _prefs.getInt(_longestStreakKey) ?? 0;
  }

  int get totalAnswers =>
      records.values.fold<int>(0, (int sum, AnswerRecord r) => sum + r.attempts);

  int get totalCorrect =>
      records.values.fold<int>(0, (int sum, AnswerRecord r) => sum + r.correct);

  double get accuracy => totalAnswers == 0 ? 0 : totalCorrect / totalAnswers;

  int get todayAnswered => days[dateKey(DateTime.now())]?.answered ?? 0;

  int unseenCount(Iterable<Question> source) =>
      source.where((Question q) => !records.containsKey(q.id)).length;

  int reviewCount(Iterable<Question> source) => source.where((Question q) {
        final AnswerRecord? record = records[q.id];
        return record != null && !record.lastCorrect;
      }).length;

  List<Question> unseenQuestions(Iterable<Question> source) {
    return source
        .where((Question q) => !records.containsKey(q.id))
        .toList();
  }

  List<Question> reviewQuestions(Iterable<Question> source) {
    return source.where((Question q) {
      final AnswerRecord? record = records[q.id];
      return record != null && !record.lastCorrect;
    }).toList();
  }

  double domainAccuracy(String domain, Iterable<Question> source) {
    final List<Question> domainQuestions =
        source.where((Question q) => q.domain == domain).toList();
    int attempts = 0;
    int correct = 0;
    for (final Question q in domainQuestions) {
      final AnswerRecord? record = records[q.id];
      if (record != null) {
        attempts += record.attempts;
        correct += record.correct;
      }
    }
    return attempts == 0 ? 0 : correct / attempts;
  }

  int domainAnswered(String domain, Iterable<Question> source) {
    return source
        .where((Question q) => q.domain == domain && records.containsKey(q.id))
        .length;
  }

  Future<void> recordAnswer(Question question, bool isCorrect) async {
    final AnswerRecord record = records.putIfAbsent(
      question.id,
      () => AnswerRecord(attempts: 0, correct: 0, lastCorrect: false),
    );
    record.attempts += 1;
    if (isCorrect) {
      record.correct += 1;
    }
    record.lastCorrect = isCorrect;

    final DateTime now = DateTime.now();
    final String today = dateKey(now);
    final DayRecord day = days.putIfAbsent(
      today,
      () => DayRecord(answered: 0, correct: 0),
    );
    day.answered += 1;
    if (isCorrect) {
      day.correct += 1;
    }

    _updateStreak(now);
    await _save();
  }

  void _updateStreak(DateTime now) {
    final StreakUpdate update = calculateStreakUpdate(
      now: now,
      lastStudyDate: lastStudyDate,
      currentStreak: streak,
      currentLongestStreak: longestStreak,
    );
    lastStudyDate = update.lastStudyDate;
    streak = update.streak;
    longestStreak = update.longestStreak;
  }

  Future<void> resetAll() async {
    records.clear();
    days.clear();
    lastStudyDate = null;
    streak = 0;
    longestStreak = 0;
    await _prefs.remove(_recordsKey);
    await _prefs.remove(_daysKey);
    await _prefs.remove(_lastStudyKey);
    await _prefs.remove(_streakKey);
    await _prefs.remove(_longestStreakKey);
  }

  Future<void> _save() async {
    await _prefs.setString(
      _recordsKey,
      jsonEncode(records.map(
        (String key, AnswerRecord value) =>
            MapEntry<String, dynamic>(key, value.toJson()),
      )),
    );
    await _prefs.setString(
      _daysKey,
      jsonEncode(days.map(
        (String key, DayRecord value) =>
            MapEntry<String, dynamic>(key, value.toJson()),
      )),
    );
    if (lastStudyDate != null) {
      await _prefs.setString(_lastStudyKey, lastStudyDate!);
    }
    await _prefs.setInt(_streakKey, streak);
    await _prefs.setInt(_longestStreakKey, longestStreak);
  }

}

