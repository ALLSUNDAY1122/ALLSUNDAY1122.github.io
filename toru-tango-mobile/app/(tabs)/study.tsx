import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
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

type Direction = 'front' | 'back';
type StudyOrder = 'normal' | 'random';
type StudyRange = 'visible' | 'all';
type AutoAdvanceDelay = 'off' | '1' | '2' | '3' | '5';

function shuffle<T>(items: T[]): T[] {
  return [...items].sort(() => Math.random() - 0.5);
}

function filterByMode(cards: Card[], mode: StudyMode): Card[] {
  if (mode === 'unseen') return cards.filter((card) => card.correct + card.wrong === 0);
  if (mode === 'weak') return cards.filter((card) => getCardReviewStage(card) === 'weak');
  if (mode === 'review') return cards.filter((card) => isReviewDue(card));
  if (mode === 'mastered') return cards.filter((card) => getCardReviewStage(card) === 'mastered');
  return cards;
}

function buildStudyQueue(
  cards: Card[],
  mode: StudyMode,
  order: StudyOrder,
  range: StudyRange
): Card[] {
  const ranged = range === 'visible' ? cards.filter((card) => !card.isHidden) : cards;
  const filtered = filterByMode(ranged, mode);
  return order === 'random' ? shuffle(filtered) : [...filtered];
}

export default function StudyScreen() {
  const { cards, gradeCard } = useAppStore();
  const [mode, setMode] = useState<StudyMode>('all');
  const [order, setOrder] = useState<StudyOrder>('normal');
  const [range, setRange] = useState<StudyRange>('visible');
  const [direction, setDirection] = useState<Direction>('front');
  const [voiceEnabled, setVoiceEnabled] = useState(true);
  const [fullRead, setFullRead] = useState(true);
  const [autoAdvanceDelay, setAutoAdvanceDelay] = useState<AutoAdvanceDelay>('3');
  const [queue, setQueue] = useState<string[]>([]);
  const [position, setPosition] = useState(0);
  const [revealed, setRevealed] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sessionStarted = queue.length > 0;

  const currentCard = useMemo(
    () => cards.find((card) => card.id === queue[position]) ?? null,
    [cards, queue, position]
  );
  const completed = queue.length > 0 && position >= queue.length;
  const progress = queue.length ? Math.min(position / queue.length, 1) : 0;
  const firstText = currentCard
    ? direction === 'front'
      ? currentCard.question
      : currentCard.answer
    : '';
  const secondText = currentCard
    ? direction === 'front'
      ? currentCard.answer
      : currentCard.question
    : '';

  const eligibleCount = useMemo(
    () => buildStudyQueue(cards, mode, 'normal', range).length,
    [cards, mode, range]
  );

  const cancelTimer = useCallback(() => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  }, []);

  const cancelPlayback = useCallback(() => {
    cancelTimer();
    void Speech.stop();
  }, [cancelTimer]);

  const advanceWithoutGrade = useCallback(() => {
    cancelPlayback();
    setPosition((current) => current + 1);
    setRevealed(false);
  }, [cancelPlayback]);

  useEffect(() => {
    if (!sessionStarted || completed || !currentCard || !voiceEnabled) return;

    let cancelled = false;
    cancelPlayback();
    setRevealed(false);

    const scheduleAdvance = () => {
      if (cancelled || autoAdvanceDelay === 'off') return;
      const delay = Number(autoAdvanceDelay) * 1000;
      timerRef.current = setTimeout(() => {
        if (cancelled) return;
        setPosition((current) => current + 1);
        setRevealed(false);
      }, delay);
    };

    if (fullRead) {
      Speech.speak(firstText, {
        language: 'ja-JP',
        rate: 0.95,
        onDone: () => {
          if (cancelled) return;
          setRevealed(true);
          Speech.speak(secondText, {
            language: 'ja-JP',
            rate: 0.95,
            onDone: scheduleAdvance
          });
        }
      });
    } else {
      Speech.speak(firstText, { language: 'ja-JP', rate: 0.95 });
    }

    return () => {
      cancelled = true;
      cancelPlayback();
    };
  }, [
    autoAdvanceDelay,
    cancelPlayback,
    completed,
    currentCard,
    direction,
    firstText,
    fullRead,
    position,
    secondText,
    sessionStarted,
    voiceEnabled
  ]);

  useEffect(
    () => () => {
      cancelPlayback();
    },
    [cancelPlayback]
  );

  const start = () => {
    cancelPlayback();
    const selected = buildStudyQueue(cards, mode, order, range);
    setQueue(selected.map((card) => card.id));
    setPosition(0);
    setRevealed(false);
  };

  const grade = (stage: CardReviewStage) => {
    if (!currentCard) return;
    cancelPlayback();
    gradeCard(currentCard.id, stage);
    setPosition((current) => current + 1);
    setRevealed(false);
  };

  const showOtherSide = () => {
    cancelPlayback();
    setRevealed((current) => !current);
  };

  const speakSide = (text: string) => {
    cancelPlayback();
    Speech.speak(text, { language: 'ja-JP', rate: 0.95 });
  };

  return (
    <Page>
      <Text style={commonStyles.title}>学習</Text>
      <Text style={commonStyles.subtitle}>
        読み上げ方法と出題条件を決めてから開始します。設定はいつでも変更できます。
      </Text>

      <View style={styles.infoBanner}>
        <Text style={styles.infoIcon}>✦</Text>
        <View style={styles.infoCopy}>
          <Text style={styles.infoTitle}>全文読み上げなら、手を使わずに復習できます</Text>
          <Text style={styles.infoText}>表と裏を読み終えたあと、既定では3秒後に次のカードへ進みます。</Text>
        </View>
      </View>

      <Section title="学習の向き">
        <ChoiceRow
          value={direction}
          onChange={(value) => {
            cancelPlayback();
            setDirection(value);
          }}
          options={[
            { value: 'front', label: '表 → 裏' },
            { value: 'back', label: '裏 → 表' }
          ]}
        />
      </Section>

      <Section title="出題順">
        <ChoiceRow
          value={order}
          onChange={setOrder}
          options={[
            { value: 'normal', label: '通常順' },
            { value: 'random', label: 'ランダム' }
          ]}
        />
      </Section>

      <Section title="出題範囲">
        <ChoiceRow
          value={range}
          onChange={setRange}
          options={[
            { value: 'visible', label: '表示中のカード' },
            { value: 'all', label: 'すべてのカード' }
          ]}
        />
        <Text style={styles.rangeHint}>
          対象 {eligibleCount}枚。非表示カードは「表示中のカード」では出題されません。
        </Text>
      </Section>

      <Section title="学習モード">
        <ChoiceRow
          value={mode}
          onChange={setMode}
          options={[
            { value: 'all', label: 'すべて' },
            { value: 'weak', label: '弱点' },
            { value: 'review', label: '定期確認' },
            { value: 'mastered', label: '確認不要' },
            { value: 'unseen', label: '未学習' }
          ]}
        />
      </Section>

      <Section title="読み上げ設定">
        <View style={styles.settingRow}>
          <View style={styles.settingCopy}>
            <Text style={styles.settingLabel}>音声読み上げ</Text>
            <Text style={styles.settingHint}>学習開始後に自動で読み上げます</Text>
          </View>
          <Switch
            value={voiceEnabled}
            onValueChange={(value) => {
              cancelPlayback();
              setVoiceEnabled(value);
            }}
            trackColor={{ false: '#d7dce1', true: colors.primary }}
          />
        </View>

        <View style={styles.settingDivider} />

        <View style={styles.settingRow}>
          <View style={styles.settingCopy}>
            <Text style={styles.settingLabel}>全文読み上げ</Text>
            <Text style={styles.settingHint}>現在のカードの表と裏を続けて全文読み上げ</Text>
          </View>
          <Switch
            disabled={!voiceEnabled}
            value={voiceEnabled && fullRead}
            onValueChange={(value) => {
              cancelPlayback();
              setFullRead(value);
            }}
            trackColor={{ false: '#d7dce1', true: colors.primary }}
          />
        </View>

        <View style={styles.settingDivider} />

        <View style={styles.delayBlock}>
          <Text style={styles.settingLabel}>読み上げ完了後、次のカードへ自動移動</Text>
          <Text style={styles.settingHint}>全文の読み上げが終わってから待つ時間です。</Text>
          <ChoiceRow
            value={autoAdvanceDelay}
            onChange={(value) => {
              cancelTimer();
              setAutoAdvanceDelay(value);
            }}
            options={[
              { value: 'off', label: 'オフ' },
              { value: '1', label: '1秒' },
              { value: '2', label: '2秒' },
              { value: '3', label: '3秒' },
              { value: '5', label: '5秒' }
            ]}
          />
          <View style={styles.exampleBox}>
            <Text style={styles.exampleText}>
              例：表→裏を全文読み上げ → 3秒待機 → 自動で次カードへ
            </Text>
          </View>
        </View>
      </Section>

      <AppButton
        label={sessionStarted && !completed ? 'この設定で最初から開始' : '学習を開始'}
        onPress={start}
        disabled={!eligibleCount}
      />

      <Section title="単語カード">
        <View style={styles.progressTrack}>
          <View style={[styles.progressBar, { width: `${progress * 100}%` }]} />
        </View>

        {!cards.length ? (
          <EmptyState>先にカードを追加してください。</EmptyState>
        ) : !queue.length ? (
          <EmptyState>上の設定を確認して「学習を開始」を押してください。</EmptyState>
        ) : completed ? (
          <View style={styles.studyBox}>
            <Text style={styles.completed}>学習完了</Text>
            <Text style={styles.counter}>{queue.length}枚を最後まで進めました。</Text>
            <AppButton label="もう一度始める" onPress={start} />
          </View>
        ) : currentCard ? (
          <View style={styles.studyBox}>
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={revealed ? 'カードの2面目' : 'カードの1面目'}
              accessibilityHint="タップすると反対側を表示します"
              onPress={showOtherSide}
              style={({ pressed }) => [styles.flashCard, pressed && styles.cardPressed]}
            >
              <Text style={styles.side}>
                {revealed ? (direction === 'front' ? '裏' : '表') : direction === 'front' ? '表' : '裏'}
              </Text>
              <Text style={styles.studyText}>{revealed ? secondText : firstText}</Text>
              <Text style={styles.flipHint}>タップして反対側へ</Text>
            </Pressable>

            <Text style={styles.counter}>{position + 1} / {queue.length}</Text>

            <View style={styles.manualActions}>
              <AppButton
                label={`${direction === 'front' ? '表' : '裏'}を読む`}
                variant="secondary"
                onPress={() => speakSide(firstText)}
              />
              <AppButton
                label={`${direction === 'front' ? '裏' : '表'}を読む`}
                variant="secondary"
                onPress={() => speakSide(secondText)}
              />
              <AppButton label="次カード" variant="secondary" onPress={advanceWithoutGrade} />
            </View>

            {!revealed ? (
              <AppButton label="反対側を見る" onPress={() => {
                cancelPlayback();
                setRevealed(true);
              }} />
            ) : (
              <View style={styles.gradeActions}>
                <View style={styles.gradeRow}>
                  <AppButton label="弱点に登録" variant="danger" onPress={() => grade('weak')} />
                  <AppButton label="覚えた" variant="success" onPress={() => grade('review')} />
                  <AppButton label="確認不要" variant="secondary" onPress={() => grade('mastered')} />
                </View>
                <Text style={styles.gradeHint}>
                  手動評価したカードだけ学習履歴へ記録します。自動送りは評価を変更しません。
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
  infoBanner: {
    alignItems: 'center',
    backgroundColor: colors.primarySoft,
    borderRadius: 18,
    flexDirection: 'row',
    gap: 12,
    marginBottom: 14,
    padding: 14
  },
  infoIcon: { color: colors.primary, fontSize: 28, fontWeight: '900' },
  infoCopy: { flex: 1 },
  infoTitle: { color: colors.primaryDark, fontSize: 14, fontWeight: '900', lineHeight: 20 },
  infoText: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 3 },
  rangeHint: { color: colors.muted, fontSize: 12, lineHeight: 18 },
  settingRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 54,
    gap: 12
  },
  settingCopy: { flex: 1 },
  settingLabel: { color: colors.text, fontSize: 14, fontWeight: '800', lineHeight: 20 },
  settingHint: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 2 },
  settingDivider: { backgroundColor: colors.border, height: 1 },
  delayBlock: { gap: 10 },
  exampleBox: { backgroundColor: colors.primarySoft, borderRadius: 10, padding: 10 },
  exampleText: { color: colors.primaryDark, fontSize: 11, fontWeight: '700', lineHeight: 17 },
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
    borderRadius: 24,
    borderWidth: 2,
    justifyContent: 'center',
    minHeight: 300,
    paddingHorizontal: 22,
    paddingVertical: 30,
    width: '100%'
  },
  cardPressed: { opacity: 0.78 },
  side: {
    backgroundColor: colors.primarySoft,
    borderRadius: 7,
    color: colors.primaryDark,
    fontSize: 12,
    fontWeight: '900',
    letterSpacing: 2,
    overflow: 'hidden',
    paddingHorizontal: 9,
    paddingVertical: 4
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
  manualActions: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  gradeActions: { gap: 8 },
  gradeRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  gradeHint: { color: colors.muted, fontSize: 12, lineHeight: 18, textAlign: 'center' }
});
