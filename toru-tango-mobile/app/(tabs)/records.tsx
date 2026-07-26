import { useMemo } from 'react';
import { Alert, StyleSheet, Text, View } from 'react-native';
import {
  AppButton,
  commonStyles,
  EmptyState,
  MutedText,
  Page,
  Section,
  colors
} from '@/src/components/ui';
import { useAppStore } from '@/src/context/AppStore';
import { pickBackup, shareBackup } from '@/src/services/backup';
import { calculateStreak, isWeakCard } from '@/src/utils/data';

export default function RecordsScreen() {
  const { cards, history, createBackup, restoreBackup } = useAppStore();

  const summary = useMemo(() => {
    const total = history.length;
    const correct = history.filter((entry) => entry.correct).length;
    const daily = new Map<string, { total: number; correct: number }>();

    history.forEach((entry) => {
      const current = daily.get(entry.dateKey) ?? { total: 0, correct: 0 };
      current.total += 1;
      if (entry.correct) current.correct += 1;
      daily.set(entry.dateKey, current);
    });

    return {
      total,
      accuracy: total ? Math.round((correct / total) * 100) : 0,
      streak: calculateStreak(history.map((entry) => entry.dateKey)),
      weak: cards.filter(isWeakCard).length,
      daily: [...daily.entries()]
        .sort(([left], [right]) => right.localeCompare(left))
        .slice(0, 14)
    };
  }, [cards, history]);

  const exportData = async () => {
    try {
      await shareBackup(createBackup());
    } catch {
      Alert.alert('保存できません', '共有機能を利用できませんでした。');
    }
  };

  const importData = async () => {
    try {
      const backup = await pickBackup();
      if (!backup) return;
      Alert.alert(
        'バックアップを復元',
        `カード${backup.cards.length}枚、履歴${backup.history.length}件で現在のデータを置き換えます。`,
        [
          { text: 'キャンセル', style: 'cancel' },
          {
            text: '置き換える',
            style: 'destructive',
            onPress: () => restoreBackup(backup)
          }
        ]
      );
    } catch {
      Alert.alert(
        '復元できません',
        '撮る単語帳の正常なJSONバックアップを選択してください。'
      );
    }
  };

  return (
    <Page>
      <Text style={commonStyles.title}>記録</Text>
      <Text style={commonStyles.subtitle}>学習状況は端末内に保存されます。</Text>

      <Section title="学習記録">
        <View style={styles.statGrid}>
          <Stat label="総回答数" value={`${summary.total}`} />
          <Stat label="正答率" value={`${summary.accuracy}%`} />
          <Stat label="連続学習" value={`${summary.streak}日`} />
          <Stat label="苦手カード" value={`${summary.weak}`} />
        </View>

        {!summary.daily.length ? (
          <EmptyState>まだ学習記録がありません。</EmptyState>
        ) : (
          summary.daily.map(([date, value]) => (
            <View key={date} style={styles.historyRow}>
              <Text style={styles.historyDate}>{date}</Text>
              <Text style={styles.historyValue}>
                {value.total}問・正答率{' '}
                {Math.round((value.correct / value.total) * 100)}%
              </Text>
            </View>
          ))
        )}
      </Section>

      <Section title="バックアップ">
        <MutedText>
          JSONファイルとして保存できます。復元時は現在のカードと履歴を置き換えます。
        </MutedText>
        <View style={commonStyles.row}>
          <AppButton label="バックアップを保存" onPress={() => void exportData()} />
          <AppButton
            label="バックアップを復元"
            variant="secondary"
            onPress={() => void importData()}
          />
        </View>
      </Section>
    </Page>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statBox}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  statGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  statBox: {
    width: '48%',
    backgroundColor: colors.background,
    borderRadius: 14,
    alignItems: 'center',
    paddingVertical: 16
  },
  statValue: { color: colors.text, fontSize: 24, fontWeight: '800' },
  statLabel: { color: colors.muted, fontSize: 12, marginTop: 4 },
  historyRow: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingVertical: 12
  },
  historyDate: { color: colors.text, fontWeight: '800' },
  historyValue: { color: colors.muted, marginTop: 3 }
});
