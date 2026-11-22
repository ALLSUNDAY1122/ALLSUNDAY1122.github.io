import { router, useFocusEffect } from 'expo-router';
import { useCallback, useMemo, useState } from 'react';
import { getAnonymousId } from '@/src/services/anonymousId';
import { getTransactionJws } from '@/src/services/iap';
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
import { pickBackup, pickCardsCsv, shareBackup, shareCardsCsv } from '@/src/services/backup';
import { calculateStreak, getCardReviewStage, isReviewDue } from '@/src/utils/data';

export default function RecordsScreen() {
  const [usageDisplay,setUsageDisplay]=useState('確認中…');
  const refreshUsage=useCallback(()=>{
    let alive=true;
    (async()=>{
      try {
        const configured=process.env.EXPO_PUBLIC_AI_API_URL?.trim()||'';
        const url=configured.replace(/\/generate\/?$/,'/usage');
        const id=await getAnonymousId();
        const jws=await getTransactionJws();
        const response=await fetch(url,{method:'POST',headers:{'X-Toru-Tango-Anonymous-Id':id,...(jws?{'X-Toru-Tango-Transaction-JWS':jws}:{})}});
        const data=await response.json() as {used?:number;limit?:number;tier?:string};
        if(!response.ok)throw new Error('usage unavailable');
        if(alive)setUsageDisplay(`今月 ${data.used ?? 0}/${data.limit ?? 5}回（${data.tier==='free'?'無料':'有料'}）`);
      }catch {if(alive)setUsageDisplay('利用状況を取得できませんでした。');}
    })();
    return ()=>{alive=false;};
  },[]);
  useFocusEffect(refreshUsage);
  const { cards, history, studyDays, addCards, createBackup, restoreBackup } = useAppStore();

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
      streak: calculateStreak(studyDays),
      studyDayCount: new Set(studyDays).size,
      weak: cards.filter((card) => getCardReviewStage(card) === 'weak').length,
      due: cards.filter((card) => isReviewDue(card)).length,
      mastered: cards.filter((card) => getCardReviewStage(card) === 'mastered').length,
      daily: [...daily.entries()]
        .sort(([left], [right]) => right.localeCompare(left))
        .slice(0, 14)
    };
  }, [cards, history, studyDays]);

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

  const exportCsv = async () => {
    try {
      await shareCardsCsv(cards);
    } catch {
      Alert.alert('CSVを保存できません', 'カードCSVを共有できませんでした。');
    }
  };

  const importCsv = async () => {
    try {
      const candidates = await pickCardsCsv();
      if (!candidates) return;
      const added = addCards(candidates);
      Alert.alert('CSVを読み込みました', `${added}枚を追加しました。重複カードは除外されています。`);
    } catch {
      Alert.alert('CSVを読み込めません', '1行目を「表,裏,メモ」としたCSVを選択してください。');
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
          <Stat label="学習した日" value={`${summary.studyDayCount}日`} />
          <Stat label="弱点カード" value={`${summary.weak}`} />
          <Stat label="今日の定期確認" value={`${summary.due}`} />
        </View>
        <Text style={styles.streakHint}>自動読み上げ・自動送りで学習した日も連続学習に含めます。</Text>

        {!summary.daily.length ? (
          <EmptyState>まだ手動評価の記録がありません。</EmptyState>
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

      <Section title="クラウドAIプラン">
        <Text style={styles.usageCount}>{usageDisplay}</Text>
        <MutedText>Gemini作問とGemini OCRを合計して月5回無料。月額プランで50回・100回を選べます。成功したAI処理のみをカウントします。</MutedText>
        <AppButton label="利用状況を更新" variant="secondary" onPress={refreshUsage} />
        <AppButton label="プランを見る" onPress={() => router.push("/paywall")} />
      </Section>
      <Section title="バックアップ">
        <MutedText>
          JSONファイルとして保存できます。復元時は現在のカード・学習記録・連続学習日を置き換えます。
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

      <Section title="カードの入出力">
        <MutedText>表・裏・メモのCSVをExcelやPCで編集して、カードとして追加できます。</MutedText>
        <View style={commonStyles.row}>
          <AppButton label="CSVを書き出す" onPress={() => void exportCsv()} />
          <AppButton label="CSVを読み込む" variant="secondary" onPress={() => void importCsv()} />
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
  usageCount: {color:colors.text,fontSize:18,fontWeight:'800',marginBottom:8},
  statGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  statBox: {
    width: '48%',
    backgroundColor: colors.background,
    borderRadius: 14,
    alignItems: 'center',
    paddingVertical: 13
  },
  statValue: { color: colors.text, fontSize: 22, fontWeight: '800' },
  statLabel: { color: colors.muted, fontSize: 12, marginTop: 4 },
  streakHint: {
    color: colors.primaryDark,
    backgroundColor: colors.primarySoft,
    borderRadius: 10,
    fontSize: 12,
    lineHeight: 18,
    padding: 10
  },
  historyRow: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    paddingVertical: 12
  },
  historyDate: { color: colors.text, fontWeight: '800' },
  historyValue: { color: colors.muted, marginTop: 3 }
});