export type Card = {
  id: string;
  question: string;
  answer: string;
  correct: number;
  wrong: number;
  lastStudiedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type StudyHistory = {
  id: string;
  cardId: string;
  answeredAt: string;
  dateKey: string;
  correct: boolean;
};

export type QuestionType = 'mix' | 'qa' | 'cloze';
export type Difficulty = 'easy' | 'normal' | 'hard';
export type StudyMode = 'all' | 'weak' | 'unseen';

export type QuestionCandidate = {
  question: string;
  answer: string;
};

export type BackupData = {
  version: 1;
  exportedAt: string;
  cards: Card[];
  history: StudyHistory[];
};
