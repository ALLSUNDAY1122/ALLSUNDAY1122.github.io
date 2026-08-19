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

export type AppStoreValue = {
  cards: Card[];
  history: StudyHistory[];
  hydrated: boolean;
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
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    let active = true;
    loadStoredState()
      .then((stored) => {
        if (!active) return;
        setCards(stored.cards);
        setHistory(stored.history);
      })
      .catch(() => {
        if (!active) return;
        setCards([]);
        setHistory([]);
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
    void saveStoredState({ cards, history }).catch(() => undefined);
  }, [cards, history, hydrated]);

  const addCard = useCallback(
    (question: string, answer: string, deckName = 'メイン'): boolean => {
      const candidate = { question: question.trim(), answer: answer.trim() };
      if (!candidate.question || !candidate.answer) return false;
      if (cards.some((card) => isSameCard(card, candidate))) return false;

      const now = new Date().toISOString();
      setCards((current) => [
        ...current,
        {
          id: createId(),
          question: candidate.question,
          answer: candidate.answer,
          deckName: deckName.trim() || 'メイン',
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
      const now = new Date().toISOString();
      setCards((current) => [
        ...current,
        ...accepted.map((candidate) => ({
          id: createId(),
          question: candidate.question,
          answer: candidate.answer,
          deckName: deckName.trim() || 'メイン',
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
      history
    }),
    [cards, history]
  );

  const restoreBackup = useCallback((backup: BackupData) => {
    setCards(backup.cards);
    setHistory(backup.history);
  }, []);

  const value = useMemo<AppStoreValue>(
    () => ({
      cards,
      history,
      hydrated,
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
      hydrated,
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
