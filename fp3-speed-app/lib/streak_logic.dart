class StreakUpdate {
  const StreakUpdate({
    required this.lastStudyDate,
    required this.streak,
    required this.longestStreak,
  });

  final String lastStudyDate;
  final int streak;
  final int longestStreak;
}

StreakUpdate calculateStreakUpdate({
  required DateTime now,
  required String? lastStudyDate,
  required int currentStreak,
  required int currentLongestStreak,
}) {
  final DateTime localDay = DateTime(now.year, now.month, now.day);
  final String today = dateKey(localDay);
  if (lastStudyDate == today) {
    return StreakUpdate(
      lastStudyDate: today,
      streak: currentStreak,
      longestStreak: currentLongestStreak,
    );
  }

  final String yesterday = dateKey(
    localDay.subtract(const Duration(days: 1)),
  );
  final int nextStreak = lastStudyDate == yesterday ? currentStreak + 1 : 1;
  return StreakUpdate(
    lastStudyDate: today,
    streak: nextStreak,
    longestStreak: nextStreak > currentLongestStreak
        ? nextStreak
        : currentLongestStreak,
  );
}

String dateKey(DateTime date) {
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
