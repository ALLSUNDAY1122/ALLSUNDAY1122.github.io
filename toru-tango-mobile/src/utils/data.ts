import type { Card, QuestionCandidate } from '@/src/types';

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
  card.wrong > card.correct || card.wrong >= 2;

export const toDateKey = (date = new Date()): string => {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
};

export const calculateStreak = (dateKeys: string[]): number => {
  const unique = new Set(dateKeys);
  let streak = 0;
  const cursor = new Date();

  while (true) {
    const target = new Date(cursor);
    target.setDate(cursor.getDate() - streak);
    if (!unique.has(toDateKey(target))) break;
    streak += 1;
  }

  return streak;
};
