import 'dart:convert';
import 'package:flutter/services.dart';

enum AnswerSide { debit, credit }
enum GradeFilter { grade3, grade2, all }
enum GameMode { score, time, weak, daily }

extension GradeFilterLabel on GradeFilter {
  String get label => switch (this) {
        GradeFilter.grade3 => '3級',
        GradeFilter.grade2 => '2級',
        GradeFilter.all => '両方',
      };

  bool accepts(int grade) => switch (this) {
        GradeFilter.grade3 => grade == 3,
        GradeFilter.grade2 => grade == 2,
        GradeFilter.all => true,
      };
}

extension GameModeLabel on GameMode {
  String get label => switch (this) {
        GameMode.score => 'スコアアタック',
        GameMode.time => 'タイムアタック',
        GameMode.weak => '苦手出題',
        GameMode.daily => 'デイリー10問',
      };
}

class Question {
  const Question({
    required this.id,
    required this.grade,
    required this.category,
    required this.transaction,
    required this.account,
    required this.correctSide,
    required this.explanation,
    required this.journal,
  });

  final String id;
  final int grade;
  final String category;
  final String transaction;
  final String account;
  final AnswerSide correctSide;
  final String explanation;
  final String journal;
}

class QuestionRepository {
  static Future<List<Question>> load() async {
    const assetPaths = [
      'assets/questions_1.json',
      'assets/questions_2.json',
      'assets/questions_3.json',
      'assets/questions_4.json',
    ];
    final rows = <dynamic>[];
    for (final path in assetPaths) {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      rows.addAll(decoded['transactions'] as List<dynamic>? ?? const []);
    }
    final questions = <Question>[];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index] as Map<String, dynamic>;
      final base = index * 2;
      questions
        ..add(Question(
          id: 'q${(base + 1).toString().padLeft(3, '0')}',
          grade: row['g'] as int,
          category: row['c'] as String,
          transaction: row['t'] as String,
          account: row['d'] as String,
          correctSide: AnswerSide.debit,
          explanation: row['de'] as String,
          journal: row['j'] as String,
        ))
        ..add(Question(
          id: 'q${(base + 2).toString().padLeft(3, '0')}',
          grade: row['g'] as int,
          category: row['c'] as String,
          transaction: row['t'] as String,
          account: row['k'] as String,
          correctSide: AnswerSide.credit,
          explanation: row['ce'] as String,
          journal: row['j'] as String,
        ));
    }

    return questions;
  }
}

class QuestionStat {
  const QuestionStat({required this.attempts, required this.correct});
  final int attempts;
  final int correct;

  double get accuracy => attempts == 0 ? 0 : correct / attempts;
  double get weakness => attempts == 0 ? 0 : (1 - accuracy) * 100 + attempts.clamp(0, 10).toDouble();

  Map<String, dynamic> toJson() => {'attempts': attempts, 'correct': correct};
  factory QuestionStat.fromJson(Map<String, dynamic> json) => QuestionStat(
        attempts: json['attempts'] as int? ?? 0,
        correct: json['correct'] as int? ?? 0,
      );
}

class LearningStats {
  const LearningStats({
    this.total = 0,
    this.correct = 0,
    this.bestCombo = 0,
    this.questionStats = const {},
    this.bestScores = const {},
  });

  final int total;
  final int correct;
  final int bestCombo;
  final Map<String, QuestionStat> questionStats;
  final Map<String, int> bestScores;

  double get accuracy => total == 0 ? 0 : correct / total;

  LearningStats record({required String questionId, required bool isCorrect, required int combo}) {
    final previous = questionStats[questionId] ?? const QuestionStat(attempts: 0, correct: 0);
    final nextQuestions = Map<String, QuestionStat>.from(questionStats)
      ..[questionId] = QuestionStat(
        attempts: previous.attempts + 1,
        correct: previous.correct + (isCorrect ? 1 : 0),
      );
    return LearningStats(
      total: total + 1,
      correct: correct + (isCorrect ? 1 : 0),
      bestCombo: combo > bestCombo ? combo : bestCombo,
      questionStats: nextQuestions,
      bestScores: bestScores,
    );
  }

  LearningStats withBestScore(String key, int score) {
    if ((bestScores[key] ?? 0) >= score) return this;
    return LearningStats(
      total: total,
      correct: correct,
      bestCombo: bestCombo,
      questionStats: questionStats,
      bestScores: {...bestScores, key: score},
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'correct': correct,
        'bestCombo': bestCombo,
        'questionStats': questionStats.map((key, value) => MapEntry(key, value.toJson())),
        'bestScores': bestScores,
      };

  factory LearningStats.fromJson(Map<String, dynamic> json) {
    final questionMap = (json['questionStats'] as Map<String, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key, QuestionStat.fromJson(value as Map<String, dynamic>)),
    );
    final scoreMap = (json['bestScores'] as Map<String, dynamic>? ?? const {}).map(
      (key, value) => MapEntry(key, value as int),
    );
    return LearningStats(
      total: json['total'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      bestCombo: json['bestCombo'] as int? ?? 0,
      questionStats: questionMap,
      bestScores: scoreMap,
    );
  }
}
