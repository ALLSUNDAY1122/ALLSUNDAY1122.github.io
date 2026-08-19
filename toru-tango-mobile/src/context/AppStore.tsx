import {
  createContext,
  type PropsWithChildren,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState
} from 'react';
import type {
  BackupData,
  Card,
  CardReviewStage,
  QuestionCandidate,
  StudyHistory
} from '@/src/types';
import { loadStoredState, saveStoredState } from '@/src/repositories/storage';
import { createId, isSameCard, toDateKey } from '@/src/utils/data';

function normalizeDeckName(value: string | undefined): string {
  return value?.trim() || 'メイン';
}

function uniqueDecks(values: string[]): string[] {
  return [...new Set(values.map((value) => value.trim()).filter(Boolean))];
}

export type AppStoreValue = {
  cards: Card[];
  history: StudyHistory[];
  decks: string[];
  hydrated: boolean;
  addDeck: (name: string) => boolean;
  addCard: (question: string, answer: string, deckName?: string) => boolean;
  addCards: (candidates: QuestionCandidate[], deckName?: string) => number;
  updateCard: (id: string, question: string, answer: string, note?: string) => boolean;
  setCardHidden: (id: string, hidden: boolean) => void;
  deleteCard: (id: string) => void;
  clearAll: () => void;
  gradeCard: (cardId: string, stage: CardReviewStage) => void;
  createBackup: () => BackupData;
  restoreBackup: (backup: BackupData) => void;
};

const AppStoreContext = createContext<AppStoreValue | null>(null);

export function AppStoreProvider({ children }: PropsWithChildren) {
  const [cards, setCards] = useState<Card[]>([]);
  const [history, setHistory] = useState<StudyHistory[]>([]);
  const [decks, setDecks] = useState<string[]>([]);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    let active = true;
    loadStoredState()
      .then((stored) => {
        if (!active) return;
        setCards(stored.cards);
        setHistory(stored.history);
        setDecks(stored.decks);
      })
      .catch(() => {
        if (!active) return;
        setCards([]);
        setHistory([]);
        setDecks([]);
      })
      .finally(() => {
        if (active) setHydrated(true);
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    void saveStoredState({ cards, history, decks }).catch(() => undefined);
  }, [cards, history, decks, hydrated]);

  const addDeck = useCallback(
    (name: string): boolean => {
      const normalized = name.trim();
      if (!normalized) return false;
      if (decks.some((deck) => deck.localeCompare(normalized, 'ja', { sensitivity: 'accent' }) === 0)) {
        return false;
      }
      setDecks((current) => [...current, normalized]);
      return true;
    },
    [decks]
  );

  const addCard = useCallback(
    (question: string, answer: string, deckName = 'メイン'): boolean => {
      const candidate = { question: question.trim(), answer: answer.trim() };
      if (!candidate.question || !candidate.answer) return false;
      if (cards.some((card) => isSameCard(card, candidate))) return false;

      const normalizedDeck = normalizeDeckName(deckName);
      const now = new Date().toISOString();
      setCards((current) => [
        ...current,
        {
          id: createId(),
          question: candidate.question,
          answer: candidate.answer,
          deckName: normalizedDeck,
          note: '',
          isHidden: false,
          correct: 0,
          wrong: 0,
          reviewStage: 'review' as const,
          nextReviewAt: null,
          lastStudiedAt: null,
          createdAt: now,
          updatedAt: now
        }
      ]);
      setDecks((current) => uniqueDecks([...current, normalizedDeck]));
      return true;
    },
    [cards]
  );

  const addCards = useCallback(
    (candidates: QuestionCandidate[], deckName = 'メイン'): number => {
      const accepted: QuestionCandidate[] = [];
      for (const raw of candidates) {
        const candidate = {
          question: raw.question.trim(),
          answer: raw.answer.trim()
        };
        if (!candidate.question || !candidate.answer) continue;
        if (cards.some((card) => isSameCard(card, candidate))) continue;
        if (accepted.some((item) => isSameCard(item, candidate))) continue;
        accepted.push(candidate);
      }

      if (!accepted.length) return 0;
      const normalizedDeck = normalizeDeckName(deckName);
      const now = new Date().toISOString();
      setCards((current) => [
        ...current,
        ...accepted.map((candidate) => ({
          id: createId(),
          question: candidate.question,
          answer: candidate.answer,
          deckName: normalizedDeck,
          note: '',
          isHidden: false,
          correct: 0,
          wrong: 0,
          reviewStage: 'review' as const,
          nextReviewAt: null,
          lastStudiedAt: null,
          createdAt: now,
          updatedAt: now
        }))
      ]);
      setDecks((current) => uniqueDecks([...current, normalizedDeck]));
      return accepted.length;
    },
    [cards]
  );

  const updateCard = useCallback(
    (id: string, question: string, answer: string, note = ''): boolean => {
      const candidate = { question: question.trim(), answer: answer.trim() };
      if (!candidate.question || !candidate.answer) return false;
      if (cards.some((card) => card.id !== id && isSameCard(card, candidate))) {
        return false;
      }

      setCards((current) =>
        current.map((card) =>
          card.id === id
            ? {
                ...card,
                question: candidate.question,
                answer: candidate.answer,
                note: note.trim(),
                updatedAt: new Date().toISOString()
              }
            : card
        )
      );
      return true;
    },
    [cards]
  );

  const setCardHidden = useCallback((id: string, hidden: boolean) => {
    setCards((current) =>
      current.map((card) =>
        card.id === id
          ? {
              ...card,
              isHidden: hidden,
              updatedAt: new Date().toISOString()
            }
          : card
      )
    );
  }, []);

  const deleteCard = useCallback((id: string) => {
    setCards((current) => current.filter((card) => card.id !== id));
    setHistory((current) => current.filter((entry) => entry.cardId !== id));
  }, []);

  const clearAll = useCallback(() => {
    setCards([]);
    setHistory([]);
    setDecks([]);
  }, []);

  const gradeCard = useCallback((cardId: string, stage: CardReviewStage) => {
    const answeredAt = new Date();
    const correct = stage !== 'weak';
    const nextReviewAt =
      stage === 'review'
        ? new Date(answeredAt.getTime() + 3 * 24 * 60 * 60 * 1000).toISOString()
        : stage === 'weak'
          ? answeredAt.toISOString()
          : null;
    setCards((current) =>
      current.map((card) =>
        card.id === cardId
          ? {
              ...card,
              correct: card.correct + (correct ? 1 : 0),
              wrong: card.wrong + (correct ? 0 : 1),
              reviewStage: stage,
              nextReviewAt,
              lastStudiedAt: answeredAt.toISOString(),
              updatedAt: answeredAt.toISOString()
            }
          : card
      )
    );
    setHistory((current) => [
      ...current,
      {
        id: createId(),
        cardId,
        answeredAt: answeredAt.toISOString(),
        dateKey: toDateKey(answeredAt),
        correct
      }
    ]);
  }, []);

  const createBackup = useCallback(
    (): BackupData => ({
      version: 1,
      exportedAt: new Date().toISOString(),
      cards,
      history,
      decks
    }),
    [cards, history, decks]
  );

  const restoreBackup = useCallback((backup: BackupData) => {
    const deckNamesFromCards = backup.cards.map((card) => normalizeDeckName(card.deckName));
    setCards(backup.cards);
    setHistory(backup.history);
    setDecks(uniqueDecks([...(backup.decks ?? []), ...deckNamesFromCards]));
  }, []);

  const value = useMemo<AppStoreValue>(
    () => ({
      cards,
      history,
      decks,
      hydrated,
      addDeck,
      addCard,
      addCards,
      updateCard,
      setCardHidden,
      deleteCard,
      clearAll,
      gradeCard,
      createBackup,
      restoreBackup
    }),
    [
      cards,
      history,
      decks,
      hydrated,
      addDeck,
      addCard,
      addCards,
      updateCard,
      setCardHidden,
      deleteCard,
      clearAll,
      gradeCard,
      createBackup,
      restoreBackup
    ]
  );

  return <AppStoreContext.Provider value={value}>{children}</AppStoreContext.Provider>;
}

export function useAppStore(): AppStoreValue {
  const store = useContext(AppStoreContext);
  if (!store) throw new Error('useAppStore must be used inside AppStoreProvider');
  return store;
}
