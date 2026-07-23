import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class StatsStore {
  static const _statsKey = 'shiwakeSwipeStatsV1';
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<LearningStats> load() async {
    final raw = await _preferences.getString(_statsKey);
    if (raw == null || raw.isEmpty) return const LearningStats();
    try {
      return LearningStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      return const LearningStats();
    }
  }

  Future<void> save(LearningStats stats) async {
    await _preferences.setString(_statsKey, jsonEncode(stats.toJson()));
  }

  Future<void> clear() async {
    await _preferences.remove(_statsKey);
  }
}
