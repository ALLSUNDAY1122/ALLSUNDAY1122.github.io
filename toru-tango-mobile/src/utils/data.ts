import type { Card, CardReviewStage, QuestionCandidate } from '@/src/types';

export const createId = (): string =>
  `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;

export const normalizeText = (value: string): string =>
  value.trim().replace(/\s+/g, ' ').toLocaleLowerCase('ja-JP');

export const isSameCard = (
  left: Pick<Card, 'question' | 'answer'> | QuestionCandidate,
  right: Pick<Card, 'question' | 'answer'> | QuestionCandidate
): boolean =>
  normalizeText(left.question) === normalizeText(right.question) &&
  normalizeText(left.answer) === normalizeText(right.answer);

export const isWeakCard = (card: Card): boolean =>
  getCardReviewStage(card) === 'weak';

export const getCardReviewStage = (card: Card): CardReviewStage => {
  if (card.reviewStage) return card.reviewStage;
  return card.wrong > card.correct || card.wrong >= 2 ? 'weak' : 'review';
};

export const isReviewDue = (card: Card, now = new Date()): boolean => {
  if (getCardReviewStage(card) !== 'review') return false;
  if (!card.nextReviewAt) return true;
  return new Date(card.nextReviewAt).getTime() <= now.getTime();
};

export const toDateKey = (date = new Date()): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const calculateStreak = (dateKeys: string[], now = new Date()): number => {
  const unique = new Set(dateKeys.filter((value) => /^\d{4}-\d{2}-\d{2}$/.test(value)));
  if (!unique.size) return 0;

  const cursor = new Date(now);
  cursor.setHours(12, 0, 0, 0);
  if (!unique.has(toDateKey(cursor))) {
    cursor.setDate(cursor.getDate() - 1);
  }

  let streak = 0;
  while (unique.has(toDateKey(cursor))) {
    streak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }
  return streak;
};