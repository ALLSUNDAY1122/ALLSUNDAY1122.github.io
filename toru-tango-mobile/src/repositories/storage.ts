import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Card, StudyHistory } from '@/src/types';

const CARD_KEY = 'toru-tango-mobile-cards-v1';
const HISTORY_KEY = 'toru-tango-mobile-history-v1';

export type StoredState = {
  cards: Card[];
  history: StudyHistory[];
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

export async function loadStoredState(): Promise<StoredState> {
  const values = await AsyncStorage.multiGet([CARD_KEY, HISTORY_KEY]);
  const cardsRaw = values.find(([key]) => key === CARD_KEY)?.[1];
  const historyRaw = values.find(([key]) => key === HISTORY_KEY)?.[1];

  return {
    cards: parseArray(cardsRaw, isCard),
    history: parseArray(historyRaw, isHistory)
  };
}

export async function saveStoredState(state: StoredState): Promise<void> {
  await AsyncStorage.multiSet([
    [CARD_KEY, JSON.stringify(state.cards)],
    [HISTORY_KEY, JSON.stringify(state.history)]
  ]);
}
