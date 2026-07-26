class QuizSessionScore {
  int score = 0;
  int combo = 0;
  int bestCombo = 0;

  void register({
    required bool isCorrect,
    required double remainingFraction,
  }) {
    if (!isCorrect) {
      combo = 0;
      return;
    }

    combo += 1;
    if (combo > bestCombo) bestCombo = combo;

    final double safeRemaining = remainingFraction.clamp(0.0, 1.0).toDouble();
    final int speedBonus = (safeRemaining * 50).round();
    final int cappedCombo = combo > 20 ? 20 : combo;
    final int comboBonus = cappedCombo * 5;
    score += 100 + speedBonus + comboBonus;
  }
}
