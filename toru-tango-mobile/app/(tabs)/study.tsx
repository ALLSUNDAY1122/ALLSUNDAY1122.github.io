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
  const { cards, gradeCard, recordStudyActivity } = useAppStore();
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
  const [settingsExpanded, setSettingsExpanded] = useState(true);
  const [playbackPaused, setPlaybackPaused] = useState(false);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const sessionStarted = queue.length > 0;

  const currentCard = useMemo(
    () => cards.find((card) => card.id === queue[position]) ?? null,
    [cards, queue, position]
  );
  const currentCardId = currentCard?.id ?? null;
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
    setPlaybackPaused(false);
    setPosition((current) => current + 1);
    setRevealed(false);
  }, [cancelPlayback]);

  useEffect(() => {
    if (!sessionStarted || completed || !currentCardId) return;
    recordStudyActivity(currentCardId);
  }, [completed, currentCardId, recordStudyActivity, sessionStarted]);

  useEffect(() => {
    if (!sessionStarted || completed || !currentCardId || !voiceEnabled || playbackPaused) return;

    let cancelled = false;
    cancelPlayback();
    const delay = autoAdvanceDelay === 'off' ? 0 : Number(autoAdvanceDelay) * 1000;

    const runAfterDelay = (callback: () => void) => {
      if (cancelled) return;
      if (!delay) {
        callback();
        return;
      }
      timerRef.current = setTimeout(() => {
        timerRef.current = null;
        if (!cancelled) callback();
      }, delay);
    };

    const scheduleAdvance = () => {
      if (cancelled || autoAdvanceDelay === 'off') return;
      runAfterDelay(() => {
        setPosition((current) => current + 1);
        setRevealed(false);
      });
    };

    if (fullRead) {
      Speech.speak(firstText, {
        language: 'ja-JP',
        rate: 0.95,
        onDone: () => {
          if (cancelled) return;
          runAfterDelay(() => {
            if (cancelled) return;
            setRevealed(true);
            Speech.speak(secondText, {
              language: 'ja-JP',
              rate: 0.95,
              onDone: scheduleAdvance
            });
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
    currentCardId,
    direction,
    firstText,
    fullRead,
    playbackPaused,
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
    setPlaybackPaused(false);
    setSettingsExpanded(false);
  };

  const grade = (stage: CardReviewStage) => {
    if (!currentCard) return;
    cancelPlayback();
    gradeCard(currentCard.id, stage);
    setPlaybackPaused(false);
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

  const togglePause = () => {
    if (playbackPaused) {
      setRevealed(false);
      setPlaybackPaused(false);
      return;
    }
    cancelPlayback();
    setPlaybackPaused(true);
  };

  const directionLabel = direction === 'front' ? '表→裏' : '裏→表';
  const modeLabel = {
    all: 'すべて',
    weak: '弱点',
    review: '定期確認',
    mastered: '確認不要',
    unseen: '未学習'
  }[mode];
  const delayLabel = autoAdvanceDelay === 'off' ? '次カード自動送りオフ' : `${autoAdvanceDelay}秒間隔`;

  return (
    <Page>
      <Text style={commonStyles.title}>学習</Text>
      <Text style={commonStyles.subtitle}>
        読み上げ方法と出題条件を決めてから開始します。
      </Text>

      {!sessionStarted || settingsExpanded ? (
        <>
          <View style={styles.infoBanner}>
            <Text style={styles.infoIcon}>✦</Text>
            <View style={styles.infoCopy}>
              <Text style={styles.infoTitle}>手を使わず、一定テンポで表と裏を復習</Text>
              <Text style={styles.infoText}>表の読み上げ後と裏の読み上げ後の両方に、同じ待ち時間を入れます。</Text>
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
              <Text style={styles.settingLabel}>自動めくり・次カードまでの待ち時間</Text>
              <Text style={styles.settingHint}>表→裏と、裏→次カードの両方に同じ時間を入れます。</Text>
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
                  例：表を読む → 3秒 → 裏を読む → 3秒 → 次カード
                </Text>
              </View>
            </View>
          </Section>

          <AppButton
            label={sessionStarted && !completed ? 'この設定で最初から開始' : '学習を開始'}
            onPress={start}
            disabled={!eligibleCount}
          />
        </>
      ) : (
        <View style={styles.sessionSummary}>
          <View style={styles.sessionSummaryCopy}>
            <Text style={styles.sessionSummaryTitle}>学習中</Text>
            <Text style={styles.sessionSummaryText}>{directionLabel}・{modeLabel}・{delayLabel}</Text>
          </View>
          <Pressable onPress={() => {
            cancelPlayback();
            setPlaybackPaused(true);
            setSettingsExpanded(true);
          }} style={styles.settingsLink}>
            <Text style={styles.settingsLinkText}>設定を変更</Text>
          </Pressable>
        </View>
      )}

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
              {voiceEnabled && fullRead ? (
                <AppButton
                  label={playbackPaused ? '自動再生を再開' : '自動再生を一時停止'}
                  variant="secondary"
                  onPress={togglePause}
                />
              ) : null}
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
                  自動学習は連続学習日に記録します。評価は手動で選んだときだけ変更します。
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
    borderRadius: 16,
    flexDirection: 'row',
    gap: 10,
    marginBottom: 12,
    padding: 12
  },
  infoIcon: { color: colors.primary, fontSize: 24, fontWeight: '900' },
  infoCopy: { flex: 1 },
  infoTitle: { color: colors.primaryDark, fontSize: 14, fontWeight: '900', lineHeight: 19 },
  infoText: { color: colors.muted, fontSize: 12, lineHeight: 17, marginTop: 2 },
  rangeHint: { color: colors.muted, fontSize: 12, lineHeight: 18 },
  settingRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    minHeight: 50,
    gap: 12
  },
  settingCopy: { flex: 1 },
  settingLabel: { color: colors.text, fontSize: 14, fontWeight: '800', lineHeight: 20 },
  settingHint: { color: colors.muted, fontSize: 12, lineHeight: 18, marginTop: 2 },
  settingDivider: { backgroundColor: colors.border, height: 1 },
  delayBlock: { gap: 9 },
  exampleBox: { backgroundColor: colors.primarySoft, borderRadius: 10, padding: 9 },
  exampleText: { color: colors.primaryDark, fontSize: 11, fontWeight: '700', lineHeight: 17 },
  sessionSummary: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 16,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 10,
    justifyContent: 'space-between',
    marginBottom: 12,
    padding: 12
  },
  sessionSummaryCopy: { flex: 1 },
  sessionSummaryTitle: { color: colors.text, fontSize: 15, fontWeight: '900' },
  sessionSummaryText: { color: colors.muted, fontSize: 12, marginTop: 2 },
  settingsLink: { justifyContent: 'center', minHeight: 40, paddingHorizontal: 6 },
  settingsLinkText: { color: colors.primaryDark, fontSize: 13, fontWeight: '800' },
  progressTrack: {
    height: 7,
    borderRadius: 99,
    backgroundColor: colors.border,
    overflow: 'hidden'
  },
  progressBar: { height: '100%', backgroundColor: colors.primary },
  studyBox: { alignItems: 'center', gap: 12, paddingVertical: 10 },
  flashCard: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.primary,
    borderRadius: 20,
    borderWidth: 2,
    justifyContent: 'center',
    minHeight: 235,
    paddingHorizontal: 18,
    paddingVertical: 22,
    width: '100%'
  },
  cardPressed: { opacity: 0.78 },
  side: {
    backgroundColor: colors.primarySoft,
    borderRadius: 7,
    color: colors.primaryDark,
    fontSize: 11,
    fontWeight: '900',
    letterSpacing: 2,
    overflow: 'hidden',
    paddingHorizontal: 8,
    paddingVertical: 3
  },
  studyText: {
    color: colors.text,
    fontSize: 21,
    fontWeight: '800',
    lineHeight: 31,
    marginVertical: 18,
    textAlign: 'center'
  },
  flipHint: { color: colors.muted, fontSize: 11 },
  counter: { color: colors.muted },
  completed: { color: colors.text, fontSize: 25, fontWeight: '800' },
  manualActions: { flexDirection: 'row', flexWrap: 'wrap', gap: 7, justifyContent: 'center' },
  gradeActions: { gap: 8 },
  gradeRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, justifyContent: 'center' },
  gradeHint: { color: colors.muted, fontSize: 12, lineHeight: 18, textAlign: 'center' }
});