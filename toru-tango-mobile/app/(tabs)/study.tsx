import { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import * as Speech from 'expo-speech';
import {
  AppButton,
  ChoiceRow,
  commonStyles,
  EmptyState,
  Page,
  Section,
  colors
} from '@/src/components/ui';
import { useAppStore } from '@/src/context/AppStore';
import type { Card, CardReviewStage, StudyMode } from '@/src/types';
import { getCardReviewStage, isReviewDue } from '@/src/utils/data';

function shuffle<T>(items: T[]): T[] {
  return [...items].sort(() => Math.random() - 0.5);
}

function selectCards(cards: Card[], mode: StudyMode): Card[] {
  if (mode === 'unseen') {
    return shuffle(cards.filter((card) => card.correct + card.wrong === 0));
  }
  if (mode === 'weak') {
    return shuffle(cards.filter((card) => getCardReviewStage(card) === 'weak'));
  }
  if (mode === 'review') {
    return shuffle(cards.filter((card) => isReviewDue(card)));
  }
  if (mode === 'mastered') {
    return shuffle(cards.filter((card) => getCardReviewStage(card) === 'mastered'));
  }
  return shuffle(cards);
}

export default function StudyScreen() {
  const { cards, gradeCard } = useAppStore();
  const [mode, setMode] = useState<StudyMode>('all');
  const [queue, setQueue] = useState<string[]>([]);
  const [position, setPosition] = useState(0);
  const [revealed, setRevealed] = useState(false);

  const currentCard = useMemo(
    () => cards.find((card) => card.id === queue[position]) ?? null,
    [cards, queue, position]
  );
  const completed = queue.length > 0 && position >= queue.length;
  const progress = queue.length ? Math.min(position / queue.length, 1) : 0;

  const start = () => {
    const selected = selectCards(cards, mode);
    setQueue(selected.map((card) => card.id));
    setPosition(0);
    setRevealed(false);
  };

  const grade = (stage: CardReviewStage) => {
    if (!currentCard) return;
    gradeCard(currentCard.id, stage);
    setPosition((current) => current + 1);
    setRevealed(false);
  };

  const speakSide = (side: 'front' | 'back') => {
    if (!currentCard) return;
    Speech.stop();
    Speech.speak(side === 'front' ? currentCard.question : currentCard.answer, {
      language: 'ja-JP',
      rate: 0.95
    });
  };

  return (
    <Page>
      <Text style={commonStyles.title}>学習</Text>
      <Text style={commonStyles.subtitle}>
        カードをタップして表と裏を切り替えます。答えの後に、次回の扱いを選びます。
      </Text>

      <Section title="学習条件">
        <ChoiceRow
          value={mode}
          onChange={setMode}
          options={[
            { value: 'all', label: 'すべて' },
            { value: 'weak', label: '弱点を復習' },
            { value: 'review', label: '定期確認' },
            { value: 'mastered', label: '確認不要' },
            { value: 'unseen', label: '未学習のみ' }
          ]}
        />
        <AppButton label="この条件で開始" onPress={start} disabled={!cards.length} />
      </Section>

      <Section title="単語カード">
        <View style={styles.progressTrack}>
          <View style={[styles.progressBar, { width: `${progress * 100}%` }]} />
        </View>

        {!cards.length ? (
          <EmptyState>先にカードを追加してください。</EmptyState>
        ) : !queue.length ? (
          <EmptyState>学習条件を選んで開始してください。</EmptyState>
        ) : completed ? (
          <View style={styles.studyBox}>
            <Text style={styles.completed}>学習完了</Text>
            <Text style={styles.counter}>{queue.length}回回答しました。</Text>
            <AppButton label="もう一度始める" onPress={start} />
          </View>
        ) : currentCard ? (
          <View style={styles.studyBox}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={revealed ? 'カードの裏面' : 'カードの表面'}
              accessibilityHint="タップすると反対側を表示します"
              onPress={() => setRevealed((current) => !current)}
              style={({ pressed }) => [styles.flashCard, pressed && styles.cardPressed]}
            >
              <Text style={styles.side}>{revealed ? '裏' : '表'}</Text>
              <Text style={styles.studyText}>
                {revealed ? currentCard.answer : currentCard.question}
              </Text>
              <Text style={styles.flipHint}>タップして{revealed ? '表' : '裏'}へ</Text>
            </Pressable>

            <Text style={styles.counter}>
              {position + 1} / {queue.length}
            </Text>

            <View style={commonStyles.row}>
              <AppButton
                label="表を読む"
                variant="secondary"
                onPress={() => speakSide('front')}
              />
              <AppButton
                label="裏を読む"
                variant="secondary"
                onPress={() => speakSide('back')}
              />
            </View>

            {!revealed ? (
              <AppButton label="裏を見る" onPress={() => setRevealed(true)} />
            ) : (
              <View style={styles.gradeActions}>
                <View style={styles.gradeRow}>
                  <AppButton
                    label="弱点に登録"
                    variant="danger"
                    onPress={() => grade('weak')}
                  />
                  <AppButton
                    label="覚えた"
                    variant="success"
                    onPress={() => grade('review')}
                  />
                  <AppButton
                    label="次へ"
                    variant="secondary"
                    onPress={() => grade('mastered')}
                  />
                </View>
                <Text style={styles.gradeHint}>
                  弱点＝優先して復習／覚えた＝3日後に確認／次へ＝確認不要
                </Text>
              </View>
            )}
          </View>
        ) : (
          <EmptyState>対象カードがありません。</EmptyState>
        )}
      </Section>
    </Page>
  );
}

const styles = StyleSheet.create({
  progressTrack: {
    height: 8,
    borderRadius: 99,
    backgroundColor: colors.border,
    overflow: 'hidden'
  },
  progressBar: { height: '100%', backgroundColor: colors.primary },
  studyBox: { alignItems: 'center', gap: 16, paddingVertical: 18 },
  flashCard: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.primary,
    borderRadius: 22,
    borderWidth: 2,
    justifyContent: 'center',
    minHeight: 300,
    paddingHorizontal: 22,
    paddingVertical: 30,
    width: '100%'
  },
  cardPressed: { opacity: 0.78 },
  side: {
    color: colors.primary,
    fontSize: 13,
    fontWeight: '900',
    letterSpacing: 2
  },
  studyText: {
    color: colors.text,
    fontSize: 24,
    fontWeight: '800',
    lineHeight: 36,
    marginVertical: 24,
    textAlign: 'center'
  },
  flipHint: { color: colors.muted, fontSize: 12 },
  counter: { color: colors.muted },
  completed: { color: colors.text, fontSize: 26, fontWeight: '800' },
  gradeActions: { gap: 8 },
  gradeRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  gradeHint: { color: colors.muted, fontSize: 12, lineHeight: 18, textAlign: 'center' }
});
