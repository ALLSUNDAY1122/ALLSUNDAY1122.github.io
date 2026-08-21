import { useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { useRouter } from 'expo-router';
import * as Speech from 'expo-speech';
import {
  AppButton,
  ChoiceRow,
  commonStyles,
  EmptyState,
  Field,
  Page,
  colors
} from '@/src/components/ui';
import { useAppStore } from '@/src/context/AppStore';
import type { Card } from '@/src/types';
import { getCardReviewStage, isReviewDue } from '@/src/utils/data';

type CardSort = 'updated' | 'newest' | 'weakest' | 'alphabetical';
type CardFilter = 'all' | 'unseen' | 'weak' | 'visible' | 'hidden';

type DeckSummary = {
  name: string;
  cards: Card[];
  total: number;
  studied: number;
  weak: number;
  unseen: number;
  updatedAt: string;
};

function deckOf(card: Card): string {
  return card.deckName?.trim() || 'メイン';
}

function formatUpdatedAt(value: string): string {
  const time = new Date(value).getTime();
  const minutes = Math.max(0, Math.floor((Date.now() - time) / 60000));
  if (minutes < 1) return 'たった今';
  if (minutes < 60) return `${minutes}分前`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}時間前`;
  const days = Math.floor(hours / 24);
  if (days < 7) return `${days}日前`;
  return new Date(value).toLocaleDateString('ja-JP');
}

export default function CardsScreen() {
  const router = useRouter();
  const {
    cards,
    decks,
    addDeck,
    updateCard,
    setCardHidden,
    deleteCard,
    clearAll
  } = useAppStore();
  const [selectedDeck, setSelectedDeck] = useState<string | null>(null);
  const [folderSearch, setFolderSearch] = useState('');
  const [cardSearch, setCardSearch] = useState('');
  const [filter, setFilter] = useState<CardFilter>('all');
  const [sort, setSort] = useState<CardSort>('updated');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [question, setQuestion] = useState('');
  const [answer, setAnswer] = useState('');
  const [note, setNote] = useState('');

  const deckSummaries = useMemo<DeckSummary[]>(() => {
    const grouped = new Map<string, Card[]>();
    decks.forEach((name) => grouped.set(name, []));
    cards.forEach((card) => {
      const name = deckOf(card);
      grouped.set(name, [...(grouped.get(name) ?? []), card]);
    });
    return [...grouped.entries()]
      .map(([name, deckCards]) => ({
        name,
        cards: deckCards,
        total: deckCards.length,
        studied: deckCards.filter((card) => card.correct + card.wrong > 0).length,
        weak: deckCards.filter((card) => getCardReviewStage(card) === 'weak').length,
        unseen: deckCards.filter((card) => card.correct + card.wrong === 0).length,
        updatedAt: deckCards.reduce(
          (latest, card) => (card.updatedAt > latest ? card.updatedAt : latest),
          deckCards[0]?.updatedAt ?? ''
        )
      }))
      .sort((left, right) => {
        if (!left.updatedAt && !right.updatedAt) return left.name.localeCompare(right.name, 'ja');
        if (!left.updatedAt) return 1;
        if (!right.updatedAt) return -1;
        return right.updatedAt.localeCompare(left.updatedAt);
      });
  }, [cards, decks]);

  const visibleDecks = useMemo(() => {
    const query = folderSearch.trim().toLocaleLowerCase('ja-JP');
    if (!query) return deckSummaries;
    return deckSummaries.filter((deck) =>
      deck.name.toLocaleLowerCase('ja-JP').includes(query)
    );
  }, [deckSummaries, folderSearch]);

  const selectedDeckCards = useMemo(
    () => (selectedDeck ? cards.filter((card) => deckOf(card) === selectedDeck) : []),
    [cards, selectedDeck]
  );

  const filteredCards = useMemo(() => {
    const query = cardSearch.trim().toLocaleLowerCase('ja-JP');
    const result = selectedDeckCards.filter((card) => {
      if (
        query &&
        !`${card.question} ${card.answer} ${card.note ?? ''}`
          .toLocaleLowerCase('ja-JP')
          .includes(query)
      ) {
        return false;
      }
      if (filter === 'unseen') return card.correct + card.wrong === 0;
      if (filter === 'weak') return getCardReviewStage(card) === 'weak';
      if (filter === 'visible') return !card.isHidden;
      if (filter === 'hidden') return Boolean(card.isHidden);
      return true;
    });

    return result.sort((left, right) => {
      if (sort === 'newest') return right.createdAt.localeCompare(left.createdAt);
      if (sort === 'weakest') return right.wrong - left.wrong;
      if (sort === 'alphabetical') return left.question.localeCompare(right.question, 'ja');
      return right.updatedAt.localeCompare(left.updatedAt);
    });
  }, [cardSearch, filter, selectedDeckCards, sort]);

  const beginEdit = (card: Card) => {
    setEditingId(card.id);
    setQuestion(card.question);
    setAnswer(card.answer);
    setNote(card.note ?? '');
  };

  const saveEdit = () => {
    if (!editingId) return;
    if (!updateCard(editingId, question, answer, note)) {
      Alert.alert('保存できません', '表・裏の未入力または重複カードを確認してください。');
      return;
    }
    setEditingId(null);
  };

  const speak = (text: string) => {
    void Speech.stop();
    Speech.speak(text, { language: 'ja-JP', rate: 0.95 });
  };

  const confirmDelete = (id: string) => {
    Alert.alert('カードを削除', 'このカードと関連する学習履歴を削除します。', [
      { text: 'キャンセル', style: 'cancel' },
      { text: '削除', style: 'destructive', onPress: () => deleteCard(id) }
    ]);
  };

  const confirmClear = () => {
    Alert.alert('すべて削除', 'フォルダ、カード、学習履歴をすべて削除しますか？', [
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

  const promptAddFolder = () => {
    Alert.prompt(
      'フォルダ追加',
      'あとからカードを入れられます。分かりやすい名前を入力してください。',
      [
        { text: 'キャンセル', style: 'cancel' },
        {
          text: '追加',
          onPress: (value?: string) => {
            const name = value?.trim() ?? '';
            if (!addDeck(name)) {
              Alert.alert('追加できません', 'フォルダ名の未入力または同名フォルダを確認してください。');
              return;
            }
            setFolderSearch('');
          }
        }
      ],
      'plain-text',
      ''
    );
  };

  const openCreate = () => router.push('/(tabs)/create');

  if (!selectedDeck) {
    return (
      <Page>
        <View style={styles.heroRow}>
          <View style={styles.heroTitleWrap}>
            <View style={styles.cameraBadge}>
              <Text style={styles.cameraBadgeText}>📷</Text>
            </View>
            <View>
              <Text style={commonStyles.title}>撮る単語帳</Text>
              <Text style={styles.heroSubtitle}>フォルダからカードをすぐ見つける</Text>
            </View>
          </View>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="フォルダを追加"
            onPress={promptAddFolder}
            style={({ pressed }) => [styles.addFolderButton, pressed && styles.pressed]}
          >
            <Text style={styles.addFolderPlus}>＋</Text>
            <Text style={styles.addFolderText}>フォルダ追加</Text>
          </Pressable>
        </View>

        <View style={styles.searchBar}>
          <Text style={styles.searchIcon}>⌕</Text>
          <TextInput
            accessibilityLabel="フォルダを検索"
            value={folderSearch}
            onChangeText={setFolderSearch}
            placeholder="フォルダを検索"
            placeholderTextColor="#98a2b3"
            style={styles.searchInput}
            autoCorrect={false}
          />
        </View>

        <View style={styles.folderHeader}>
          <View>
            <Text style={styles.sectionEyebrow}>フォルダ</Text>
            <Text style={styles.folderCount}>{deckSummaries.length}個</Text>
          </View>
          {deckSummaries.length || cards.length ? (
            <Pressable onPress={confirmClear} style={styles.clearLink}>
              <Text style={styles.clearLinkText}>全データ削除</Text>
            </Pressable>
          ) : null}
        </View>

        {!visibleDecks.length ? (
          <View style={styles.emptyFolderBox}>
            <Text style={styles.emptyFolderIcon}>📂</Text>
            <Text style={styles.emptyFolderTitle}>
              {deckSummaries.length ? '該当するフォルダがありません' : 'まだフォルダがありません'}
            </Text>
            <Text style={styles.emptyFolderText}>
              フォルダを先に作るか、カードを作成するとここに整理して表示されます。
            </Text>
            <View style={commonStyles.row}>
              <AppButton label="フォルダを作る" onPress={promptAddFolder} />
              <AppButton label="カードを作る" variant="secondary" onPress={openCreate} />
            </View>
          </View>
        ) : (
          <View style={styles.folderGrid}>
            {visibleDecks.map((deck, index) => {
              const progress = deck.total ? Math.round((deck.studied / deck.total) * 100) : 0;
              const accent = [colors.primary, '#36b76b', '#8b5cf6', '#f39a18'][index % 4];
              return (
                <Pressable
                  key={deck.name}
                  accessibilityRole="button"
                  accessibilityLabel={`${deck.name}、${deck.total}枚`}
                  onPress={() => {
                    setSelectedDeck(deck.name);
                    setCardSearch('');
                    setFilter('all');
                  }}
                  style={({ pressed }) => [styles.folderCard, pressed && styles.folderPressed]}
                >
                  <View style={styles.folderCardTop}>
                    <View style={[styles.folderIcon, { backgroundColor: `${accent}18` }]}>
                      <Text style={styles.folderIconText}>📁</Text>
                    </View>
                    <Text style={styles.moreText}>•••</Text>
                  </View>
                  <Text style={styles.folderName} numberOfLines={2}>{deck.name}</Text>
                  <Text style={styles.folderMeta}>{deck.total}枚</Text>
                  <Text style={styles.folderSubMeta}>未学習 {deck.unseen}・弱点 {deck.weak}</Text>
                  <View style={styles.progressRow}>
                    <View style={styles.folderProgressTrack}>
                      <View
                        style={[
                          styles.folderProgressBar,
                          { backgroundColor: accent, width: `${progress}%` }
                        ]}
                      />
                    </View>
                    <Text style={[styles.progressPercent, { color: accent }]}>{progress}%</Text>
                  </View>
                </Pressable>
              );
            })}
          </View>
        )}
      </Page>
    );
  }

  return (
    <Page>
      <View style={styles.detailHeader}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="フォルダ一覧へ戻る"
          onPress={() => {
            void Speech.stop();
            setEditingId(null);
            setSelectedDeck(null);
          }}
          style={({ pressed }) => [styles.backButton, pressed && styles.pressed]}
        >
          <Text style={styles.backText}>‹ 戻る</Text>
        </Pressable>
        <Text style={styles.deckTitle} numberOfLines={1}>{selectedDeck}</Text>
        <Pressable onPress={openCreate} style={styles.headerAddButton}>
          <Text style={styles.headerAddText}>＋</Text>
        </Pressable>
      </View>

      <View style={styles.searchBar}>
        <Text style={styles.searchIcon}>⌕</Text>
        <TextInput
          accessibilityLabel="カードを検索"
          value={cardSearch}
          onChangeText={setCardSearch}
          placeholder="カードを検索"
          placeholderTextColor="#98a2b3"
          style={styles.searchInput}
          autoCorrect={false}
        />
      </View>

      <ChoiceRow
        value={filter}
        onChange={setFilter}
        options={[
          { value: 'all', label: 'すべて' },
          { value: 'unseen', label: '未学習' },
          { value: 'weak', label: '苦手' },
          { value: 'visible', label: '表示中' },
          { value: 'hidden', label: '非表示' }
        ]}
      />

      <View style={styles.listHeader}>
        <Text style={styles.cardCount}>{filteredCards.length}枚</Text>
        <ChoiceRow
          value={sort}
          onChange={setSort}
          options={[
            { value: 'updated', label: '更新順' },
            { value: 'newest', label: '新しい順' },
            { value: 'weakest', label: '弱点順' },
            { value: 'alphabetical', label: '問題順' }
          ]}
        />
      </View>

      {!filteredCards.length ? (
        <EmptyState>この条件に合うカードはありません。</EmptyState>
      ) : (
        filteredCards.map((card) => (
          <View key={card.id} style={[styles.cardRow, card.isHidden && styles.cardRowHidden]}>
            {editingId === card.id ? (
              <View style={styles.editWrap}>
                <Text style={styles.editTitle}>カードを編集</Text>
                <Field label="表" value={question} onChangeText={setQuestion} multiline />
                <Field label="裏" value={answer} onChangeText={setAnswer} multiline />
                <Field
                  label="メモ（任意）"
                  value={note}
                  onChangeText={setNote}
                  multiline
                  placeholder="覚え方・補足・出典など"
                />
                <View style={commonStyles.row}>
                  <AppButton label="保存" variant="success" onPress={saveEdit} />
                  <AppButton
                    label="キャンセル"
                    variant="secondary"
                    onPress={() => setEditingId(null)}
                  />
                  <AppButton label="削除" variant="danger" onPress={() => confirmDelete(card.id)} />
                </View>
              </View>
            ) : (
              <>
                <View style={styles.facesRow}>
                  <View style={styles.faceColumn}>
                    <Text style={styles.faceLabel}>表</Text>
                    <Text style={styles.faceText} numberOfLines={2}>{card.question}</Text>
                  </View>
                  <View style={styles.faceDivider} />
                  <View style={styles.faceColumn}>
                    <Text style={styles.faceLabel}>裏</Text>
                    <Text style={styles.faceText} numberOfLines={2}>{card.answer}</Text>
                  </View>
                </View>

                <View style={styles.statusRow}>
                  <View style={styles.statusChips}>
                    {card.isHidden ? (
                      <Text style={[styles.statusChip, styles.hiddenChip]}>非表示</Text>
                    ) : card.correct + card.wrong === 0 ? (
                      <Text style={styles.statusChip}>未学習</Text>
                    ) : getCardReviewStage(card) === 'weak' ? (
                      <Text style={[styles.statusChip, styles.weakChip]}>苦手</Text>
                    ) : (
                      <Text style={[styles.statusChip, styles.visibleChip]}>表示中</Text>
                    )}
                    <Text style={styles.updatedText}>{formatUpdatedAt(card.updatedAt)}</Text>
                  </View>
                  <Text style={styles.reviewText}>
                    {getCardReviewStage(card) === 'review' && isReviewDue(card)
                      ? '今日確認'
                      : `○${card.correct}・△${card.wrong}`}
                  </Text>
                </View>

                {card.note ? <Text style={styles.noteText} numberOfLines={1}>メモ：{card.note}</Text> : null}

                <View style={styles.actionGrid}>
                  <Pressable onPress={() => speak(card.question)} style={styles.smallAction}>
                    <Text style={styles.smallActionText}>🔊 表</Text>
                  </Pressable>
                  <Pressable onPress={() => speak(card.answer)} style={styles.smallAction}>
                    <Text style={styles.smallActionText}>🔊 裏</Text>
                  </Pressable>
                  <Pressable
                    onPress={() => setCardHidden(card.id, !card.isHidden)}
                    style={[styles.smallAction, card.isHidden && styles.smallActionActive]}
                  >
                    <Text style={[styles.smallActionText, card.isHidden && styles.smallActionActiveText]}>
                      {card.isHidden ? '表示' : '非表示'}
                    </Text>
                  </Pressable>
                  <Pressable onPress={() => beginEdit(card)} style={styles.smallAction}>
                    <Text style={styles.smallActionText}>✎ 編集</Text>
                  </Pressable>
                </View>
              </>
            )}
          </View>
        ))
      )}

      <Pressable
        accessibilityRole="button"
        accessibilityLabel="カードを追加"
        onPress={openCreate}
        style={({ pressed }) => [styles.floatingAdd, pressed && styles.pressed]}
      >
        <Text style={styles.floatingAddText}>＋ カード追加</Text>
      </Pressable>
    </Page>
  );
}

const styles = StyleSheet.create({
  pressed: { opacity: 0.72 },
  heroRow: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 16
  },
  heroTitleWrap: { alignItems: 'center', flexDirection: 'row', flexShrink: 1, gap: 10 },
  cameraBadge: {
    alignItems: 'center',
    backgroundColor: colors.primarySoft,
    borderRadius: 16,
    height: 50,
    justifyContent: 'center',
    width: 50
  },
  cameraBadgeText: { fontSize: 25 },
  heroSubtitle: { color: colors.muted, fontSize: 12, marginTop: 2 },
  addFolderButton: {
    alignItems: 'center',
    flexDirection: 'row',
    gap: 4,
    minHeight: 44,
    paddingHorizontal: 6
  },
  addFolderPlus: { color: colors.primary, fontSize: 28, fontWeight: '400' },
  addFolderText: { color: colors.primaryDark, fontSize: 14, fontWeight: '800' },
  searchBar: {
    alignItems: 'center',
    backgroundColor: '#eef1f4',
    borderRadius: 14,
    flexDirection: 'row',
    minHeight: 48,
    paddingHorizontal: 12,
    marginBottom: 12
  },
  searchIcon: { color: colors.muted, fontSize: 24, marginRight: 7 },
  searchInput: { color: colors.text, flex: 1, fontSize: 15, minHeight: 44 },
  folderHeader: {
    alignItems: 'flex-end',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10
  },
  sectionEyebrow: { color: colors.primaryDark, fontSize: 16, fontWeight: '800' },
  folderCount: { color: colors.muted, fontSize: 12, marginTop: 2 },
  clearLink: { minHeight: 44, justifyContent: 'center' },
  clearLinkText: { color: colors.danger, fontSize: 12, fontWeight: '700' },
  emptyFolderBox: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 20,
    borderWidth: 1,
    gap: 10,
    padding: 24
  },
  emptyFolderIcon: { fontSize: 36 },
  emptyFolderTitle: { color: colors.text, fontSize: 18, fontWeight: '800' },
  emptyFolderText: { color: colors.muted, lineHeight: 20, textAlign: 'center' },
  folderGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  folderCard: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 18,
    borderWidth: 1,
    minHeight: 170,
    padding: 13,
    width: '48%',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.05,
    shadowRadius: 10,
    elevation: 1
  },
  folderPressed: { opacity: 0.78, transform: [{ scale: 0.99 }] },
  folderCardTop: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between' },
  folderIcon: {
    alignItems: 'center',
    borderRadius: 13,
    height: 40,
    justifyContent: 'center',
    width: 40
  },
  folderIconText: { fontSize: 20 },
  moreText: { color: '#98a2b3', fontSize: 15, fontWeight: '900' },
  folderName: { color: colors.text, fontSize: 16, fontWeight: '800', lineHeight: 21, marginTop: 10 },
  folderMeta: { color: colors.text, fontSize: 13, fontWeight: '700', marginTop: 7 },
  folderSubMeta: { color: colors.muted, fontSize: 10, marginTop: 2 },
  progressRow: { alignItems: 'center', flexDirection: 'row', gap: 7, marginTop: 10 },
  folderProgressTrack: {
    backgroundColor: '#edf0f3',
    borderRadius: 99,
    flex: 1,
    height: 5,
    overflow: 'hidden'
  },
  folderProgressBar: { borderRadius: 99, height: '100%' },
  progressPercent: { fontSize: 11, fontWeight: '800' },
  detailHeader: {
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 12
  },
  backButton: { justifyContent: 'center', minHeight: 44, minWidth: 64 },
  backText: { color: colors.primaryDark, fontSize: 16, fontWeight: '800' },
  deckTitle: { color: colors.text, flex: 1, fontSize: 21, fontWeight: '800', textAlign: 'center' },
  headerAddButton: { alignItems: 'center', justifyContent: 'center', minHeight: 44, minWidth: 64 },
  headerAddText: { color: colors.primary, fontSize: 30, fontWeight: '500' },
  listHeader: { gap: 7, marginBottom: 8, marginTop: 10 },
  cardCount: { color: colors.text, fontSize: 14, fontWeight: '800' },
  cardRow: {
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 15,
    borderWidth: 1,
    gap: 7,
    marginBottom: 8,
    padding: 10,
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.03,
    shadowRadius: 6,
    elevation: 1
  },
  cardRowHidden: { backgroundColor: '#fafafa', opacity: 0.8 },
  facesRow: { flexDirection: 'row', gap: 9 },
  faceColumn: { flex: 1, minHeight: 56 },
  faceDivider: { backgroundColor: colors.border, width: 1 },
  faceLabel: {
    alignSelf: 'flex-start',
    backgroundColor: colors.primarySoft,
    borderRadius: 6,
    color: colors.primaryDark,
    fontSize: 10,
    fontWeight: '900',
    overflow: 'hidden',
    paddingHorizontal: 6,
    paddingVertical: 2
  },
  faceText: { color: colors.text, fontSize: 14, fontWeight: '700', lineHeight: 19, marginTop: 5 },
  statusRow: { alignItems: 'center', flexDirection: 'row', justifyContent: 'space-between', gap: 7 },
  statusChips: { alignItems: 'center', flexDirection: 'row', flexWrap: 'wrap', flexShrink: 1, gap: 6 },
  statusChip: {
    backgroundColor: '#f1f3f5',
    borderRadius: 6,
    color: colors.muted,
    fontSize: 10,
    fontWeight: '800',
    overflow: 'hidden',
    paddingHorizontal: 7,
    paddingVertical: 3
  },
  weakChip: { backgroundColor: colors.dangerSoft, color: colors.danger },
  visibleChip: { backgroundColor: colors.successSoft, color: colors.success },
  hiddenChip: { backgroundColor: '#eceff1', color: '#667085' },
  updatedText: { color: colors.muted, fontSize: 10 },
  reviewText: { color: colors.muted, fontSize: 10 },
  noteText: {
    backgroundColor: colors.warningSoft,
    borderRadius: 8,
    color: colors.text,
    fontSize: 11,
    lineHeight: 16,
    paddingHorizontal: 8,
    paddingVertical: 6
  },
  actionGrid: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 },
  smallAction: {
    alignItems: 'center',
    backgroundColor: colors.surface,
    borderColor: colors.border,
    borderRadius: 10,
    borderWidth: 1,
    justifyContent: 'center',
    minHeight: 36,
    paddingHorizontal: 9
  },
  smallActionText: { color: colors.text, fontSize: 11, fontWeight: '800' },
  smallActionActive: { backgroundColor: colors.primarySoft, borderColor: colors.primary },
  smallActionActiveText: { color: colors.primaryDark },
  editWrap: { gap: 10 },
  editTitle: { color: colors.text, fontSize: 16, fontWeight: '800' },
  floatingAdd: {
    alignItems: 'center',
    alignSelf: 'flex-end',
    backgroundColor: colors.primary,
    borderRadius: 999,
    justifyContent: 'center',
    marginTop: 4,
    minHeight: 48,
    paddingHorizontal: 18,
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 5 },
    shadowOpacity: 0.14,
    shadowRadius: 12,
    elevation: 4
  },
  floatingAddText: { color: '#ffffff', fontSize: 14, fontWeight: '900' }
});