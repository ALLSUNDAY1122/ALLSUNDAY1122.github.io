import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';
import { normalizeText } from '@/src/utils/data';

const STOP_WORDS = [
  'こと',
  'ため',
  'もの',
  'これ',
  'それ',
  'について',
  'によって',
  'として',
  'および',
  'または'
];

function splitSentences(text: string): string[] {
  return text
    .replace(/\r/g, '')
    .split(/[。！？!?\n]+/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length >= 8);
}

function extractKeyword(sentence: string): string {
  const quoted = sentence.match(/[「『“"]([^」』”"]{2,24})[」』”"]/);
  if (quoted) return quoted[1];

  const date = sentence.match(/\d{4}年(?:\d{1,2}月(?:\d{1,2}日)?)?/);
  if (date) return date[0];

  const number = sentence.match(
    /\d+(?:\.\d+)?(?:％|%|人|円|年|回|個|か月|ヶ月|日|時間)/
  );
  if (number) return number[0];

  const definition = sentence.match(/^(.{2,24}?)(?:とは|は|をいう|と呼ばれる)/);
  if (definition) return definition[1].replace(/[、，]/g, '').trim();

  const words = sentence.match(/[一-龠々ァ-ヶA-Za-z]{3,18}/g) ?? [];
  return (
    words
      .filter((word) => !STOP_WORDS.some((stopWord) => word.includes(stopWord)))
      .sort((left, right) => right.length - left.length)[0] ?? ''
  );
}

function buildQuestion(
  sentence: string,
  keyword: string,
  type: QuestionType,
  difficulty: Difficulty
): QuestionCandidate[] {
  const hidden = difficulty === 'easy' ? '（　　）' : '＿＿＿＿';
  const masked = sentence.replace(keyword, hidden);
  const prefix =
    difficulty === 'hard'
      ? '次の説明に当てはまる語句を答えてください。'
      : '空欄に当てはまる語句は何ですか。';

  if (type === 'qa') {
    return [{ question: `${prefix}${masked}`, answer: keyword }];
  }

  if (type === 'cloze') {
    return [{ question: masked, answer: keyword }];
  }

  return [
    { question: `${prefix}${masked}`, answer: keyword },
    { question: masked, answer: keyword }
  ];
}

export function generateLocalQuestions(
  text: string,
  count: number,
  type: QuestionType,
  difficulty: Difficulty
): QuestionCandidate[] {
  const output: QuestionCandidate[] = [];
  const seenKeywords = new Set<string>();
  const seenQuestions = new Set<string>();

  for (const sentence of splitSentences(text)) {
    const keyword = extractKeyword(sentence);
    const normalizedKeyword = normalizeText(keyword);
    if (!keyword || seenKeywords.has(normalizedKeyword)) continue;
    seenKeywords.add(normalizedKeyword);

    for (const candidate of buildQuestion(sentence, keyword, type, difficulty)) {
      const key = `${normalizeText(candidate.question)}|${normalizeText(candidate.answer)}`;
      if (seenQuestions.has(key)) continue;
      seenQuestions.add(key);
      output.push(candidate);
      if (output.length >= count) return output;
    }
  }

  return output.slice(0, count);
}
