import { useMemo, useState } from 'react';
import { Alert, StyleSheet, Text, View } from 'react-native';
import {
  AppButton,
  ChoiceRow,
  commonStyles,
  EmptyState,
  Field,
  Page,
  Section,
  colors
} from '@/src/components/ui';
import { useAppStore } from '@/src/context/AppStore';
import type { StudyMode } from '@/src/types';
import { isWeakCard } from '@/src/utils/data';

export default function CardsScreen() {
  const { cards, updateCard, deleteCard, clearAll } = useAppStore();
  const [filter, setFilter] = useState<StudyMode>('all');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');

  const filtered = useMemo(
    () =>
      cards.filter((card) => {
        if (filter === 'weak') return isWeakCard(card);
        if (filter === 'unseen') return card.correct + card.wrong === 0;
        return true;
      }),
    [cards, filter]
  );

  const beginEdit = (id: string) => {
    const card = cards.find((item) => item.id === id);
    if (!card) return;
    setEditingId(id);
    setQuestion(card.question);
    setAnswer(card.answer);
  };

  const saveEdit = () => {
    if (!editingId) return;
    if (!updateCard(editingId, question, answer)) {
      Alert.alert('保存できません', '未入力または同じカードが保存済みです。');
      return;
    }
    setEditingId(null);
  };

  const confirmDelete = (id: string) => {
    Alert.alert('カードを削除', 'このカードと関連する学習履歴を削除します。', [
      { text: 'キャンセル', style: 'cancel' },
      { text: '削除', style: 'destructive', onPress: () => deleteCard(id) }
    ]);
  };

  const confirmClear = () => {
    Alert.alert('すべて削除', 'カードと学習履歴をすべて削除しますか？', [
      { text: 'キャンセル', style: 'cancel' },
      {
        text: '次へ',
        style: 'destructive',
        onPress: () =>
          Alert.alert('最終確認', 'この操作は取り消せません。', [
            { text: 'キャンセル', style: 'cancel' },
            { text: '全削除', style: 'destructive', onPress: clearAll }
          ])
      }
    ]);
  };

  return (
    <Page>
      <Text style={commonStyles.title}>単語帳</Text>
      <Text style={commonStyles.subtitle}>{cards.length}枚保存されています。</Text>

      <Section
        title="カード一覧"
        right={
          cards.length ? (
            <AppButton label="全削除" variant="danger" onPress={confirmClear} />
          ) : null
        }
      >
        <ChoiceRow
          value={filter}
          onChange={setFilter}
          options={[
            { value: 'all', label: 'すべて' },
            { value: 'weak', label: '苦手' },
            { value: 'unseen', label: '未学習' }
          ]}
        />

        {!filtered.length ? (
          <EmptyState>該当するカードがありません。</EmptyState>
        ) : (
          filtered.map((card) => (
            <View key={card.id} style={styles.cardRow}>
              {editingId === card.id ? (
                <>
                  <Field label="問題" value={question} onChangeText={setQuestion} />
                  <Field label="答え" value={answer} onChangeText={setAnswer} />
                  <View style={commonStyles.row}>
                    <AppButton label="保存" variant="success" onPress={saveEdit} />
                    <AppButton
                      label="キャンセル"
                      variant="secondary"
                      onPress={() => setEditingId(null)}
                    />
                  </View>
                </>
              ) : (
                <>
                  <Text style={styles.question}>{card.question}</Text>
                  <Text style={styles.answer}>{card.answer}</Text>
                  <Text style={styles.stats}>
                    正解 {card.correct}回・もう一度 {card.wrong}回
                  </Text>
                  <View style={commonStyles.row}>
                    <AppButton
                      label="編集"
                      variant="secondary"
                      onPress={() => beginEdit(card.id)}
                    />
                    <AppButton
                      label="削除"
                      variant="danger"
                      onPress={() => confirmDelete(card.id)}
                    />
                  </View>
                </>
              )}
            </View>
          ))
        )}
      </Section>
    </Page>
  );
}

const styles = StyleSheet.create({
  cardRow: {
    borderTopColor: colors.border,
    borderTopWidth: 1,
    gap: 8,
    paddingVertical: 14
  },
  question: { color: colors.text, fontSize: 16, fontWeight: '800', lineHeight: 23 },
  answer: { color: colors.muted, fontSize: 15, lineHeight: 22 },
  stats: { color: colors.muted, fontSize: 12 }
});
