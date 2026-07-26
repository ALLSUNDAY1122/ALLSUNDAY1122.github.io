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
import type { Card, StudyMode } from '@/src/types';
import { isWeakCard } from '@/src/utils/data';

function shuffle<T>(items: T[]): T[] {
  return [...items].sort(() => Math.random() - 0.5);
}

function selectCards(cards: Card[], mode: StudyMode): Card[] {
  if (mode === 'unseen') {
    return shuffle(cards.filter((card) => card.correct + card.wrong === 0));
  }
  if (mode === 'weak') {
    const weak = shuffle(cards.filter(isWeakCard));
    const others = shuffle(cards.filter((card) => !isWeakCard(card)));
    return [...weak, ...others];
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

  const grade = (correct: boolean) => {
    if (!currentCard) return;
    gradeCard(currentCard.id, correct);
    if (!correct) setQueue((current) => [...current, currentCard.id]);
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
        カードをタップして表と裏を切り替えます。「もう一度」は末尾へ戻ります。
      </Text>

      <Section title="学習条件">
        <ChoiceRow
          value={mode}
          onChange={setMode}
          options={[
            { value: 'all', label: 'すべて' },
            { value: 'weak', label: '苦手を優先' },
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
              <View style={commonStyles.row}>
                <AppButton
                  label="もう一度"
                  variant="danger"
                  onPress={() => grade(false)}
                />
                <AppButton
                  label="覚えた"
                  variant="success"
                  onPress={() => grade(true)}
                />
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
  completed: { color: colors.text, fontSize: 26, fontWeight: '800' }
});
