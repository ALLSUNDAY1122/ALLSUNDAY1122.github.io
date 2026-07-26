import AsyncStorage from '@react-native-async-storage/async-storage';
import type { Card, StudyHistory } from '@/src/types';

const CARD_KEY = 'toru-tango-mobile-cards-v1';
const HISTORY_KEY = 'toru-tango-mobile-history-v1';

export type StoredState = {
  cards: Card[];
  history: StudyHistory[];
};

export async function loadStoredState(): Promise<StoredState> {
  const values = await AsyncStorage.multiGet([CARD_KEY, HISTORY_KEY]);
  const cardsRaw = values.find(([key]) => key === CARD_KEY)?.[1];
  const historyRaw = values.find(([key]) => key === HISTORY_KEY)?.[1];

  const cards = cardsRaw ? JSON.parse(cardsRaw) : [];
  const history = historyRaw ? JSON.parse(historyRaw) : [];

  return {
    cards: Array.isArray(cards) ? cards : [],
    history: Array.isArray(history) ? history : []
  };
}

export async function saveStoredState(state: StoredState): Promise<void> {
  await AsyncStorage.multiSet([
    [CARD_KEY, JSON.stringify(state.cards)],
    [HISTORY_KEY, JSON.stringify(state.history)]
  ]);
}
