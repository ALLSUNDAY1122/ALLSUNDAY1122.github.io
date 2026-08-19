import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Card, StudyHistory } from '@/src/types';

const CARD_KEY = 'toru-tango-mobile-cards-v1';
const HISTORY_KEY = 'toru-tango-mobile-history-v1';
const DECK_KEY = 'toru-tango-mobile-decks-v1';

export type StoredState = {
  cards: Card[];
  history: StudyHistory[];
  decks: string[];
};

function isCard(value: unknown): value is Card {
  if (!value || typeof value !== 'object') return false;
  const card = value as Record<string, unknown>;
  return (
    typeof card.id === 'string' &&
    typeof card.question === 'string' &&
    typeof card.answer === 'string' &&
    Number.isFinite(card.correct) &&
    Number.isFinite(card.wrong) &&
    (card.lastStudiedAt === null || typeof card.lastStudiedAt === 'string') &&
    typeof card.createdAt === 'string' &&
    typeof card.updatedAt === 'string'
  );
}

function isHistory(value: unknown): value is StudyHistory {
  if (!value || typeof value !== 'object') return false;
  const history = value as Record<string, unknown>;
  return (
    typeof history.id === 'string' &&
    typeof history.cardId === 'string' &&
    typeof history.answeredAt === 'string' &&
    typeof history.dateKey === 'string' &&
    typeof history.correct === 'boolean'
  );
}

function parseArray<T>(raw: string | null | undefined, guard: (value: unknown) => value is T): T[] {
  if (!raw) return [];
  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter(guard) : [];
  } catch {
    return [];
  }
}

function normalizeDecks(values: unknown[]): string[] {
  return [...new Set(
    values
      .filter((value): value is string => typeof value === 'string')
      .map((value) => value.trim())
      .filter(Boolean)
  )];
}

export async function loadStoredState(): Promise<StoredState> {
  const values = await AsyncStorage.multiGet([CARD_KEY, HISTORY_KEY, DECK_KEY]);
  const cardsRaw = values.find(([key]) => key === CARD_KEY)?.[1];
  const historyRaw = values.find(([key]) => key === HISTORY_KEY)?.[1];
  const decksRaw = values.find(([key]) => key === DECK_KEY)?.[1];
  const cards = parseArray(cardsRaw, isCard);

  let storedDecks: string[] = [];
  if (decksRaw) {
    try {
      const parsed: unknown = JSON.parse(decksRaw);
      storedDecks = Array.isArray(parsed) ? normalizeDecks(parsed) : [];
    } catch {
      storedDecks = [];
    }
  }

  const decksFromCards = normalizeDecks(cards.map((card) => card.deckName ?? 'メイン'));

  return {
    cards,
    history: parseArray(historyRaw, isHistory),
    decks: normalizeDecks([...storedDecks, ...decksFromCards])
  };
}

export async function saveStoredState(state: StoredState): Promise<void> {
  await AsyncStorage.multiSet([
    [CARD_KEY, JSON.stringify(state.cards)],
    [HISTORY_KEY, JSON.stringify(state.history)],
    [DECK_KEY, JSON.stringify(normalizeDecks(state.decks))]
  ]);
}
