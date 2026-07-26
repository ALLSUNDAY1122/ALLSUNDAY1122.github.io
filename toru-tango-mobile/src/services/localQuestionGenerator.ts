import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';

const MAX_QUESTION_LENGTH = 140;
const MAX_ANSWER_LENGTH = 70;

type Fact = {
  question: string;
  answer: string;
  source: string;
  priority: number;
};

const cleanText = (value: string): string =>
  value.replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();

const normalizeKey = (value: string): string =>
  cleanText(value)
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_]/g, '')
    .toLocaleLowerCase('ja-JP');

function splitSentences(text: string): string[] {
  return cleanText(text)
    .split(/[。！？!?\n]+/)
    .map((sentence) => sentence.trim())
    .filter((sentence) => sentence.length >= 12)
    .filter((sentence) =>
      /(?:した|された|している|されている|である|とされる|とされている|考えられている|誕生|登場|発見|名付け|広げ|進む|分かれ)/.test(
        sentence
      )
    );
}

function cleanEntity(value: string): string {
  let cleaned = cleanText(value).replace(/[、，]$/, '').trim();
  const descriptorParts = cleaned.split(/(?:とよばれる|と呼ばれる|である[、，]?)/);
  if (descriptorParts.length > 1) cleaned = descriptorParts[descriptorParts.length - 1];
  cleaned = cleaned.replace(/^.*?[、，]/, '');
  return cleaned
    .replace(/^(?:現在のところ|最古の|猿人の一種|一種|いわゆる)\s*/, '')
    .replace(/[、，]$/, '')
    .trim();
}

function extractLocation(sentence: string, eventWord: string): string {
  const beforeEvent = sentence.split(eventWord)[0] ?? sentence;
  const candidates = [
    ...beforeEvent.matchAll(
      /([^、，]{2,45}?(?:大陸|州|国|地方|地域|村付近|村|付近|半島|沿岸|タンザニア|エチオピア))で(?:は)?[、，]?/g
    )
  ];
  const stripTime = (value: string): string =>
    cleanEntity(value)
      .replace(
        /^(?:約?\d+(?:\.\d+)?万?年前|数百万年前)(?:から約?\d+(?:\.\d+)?万?年前)?(?:に)?/,
        ''
      )
      .trim();

  if (candidates.length > 0) {
    const latest = candidates[candidates.length - 1];
    return stripTime(latest[1] ?? '');
  }

  const leading = beforeEvent.match(/^([^、，]{2,45}?)で(?:は)?[、，]/);
  return leading ? stripTime(leading[1]) : '';
}

function makeFact(
  question: string,
  answer: string,
  source: string,
  priority = 50
): Fact {
  const trimmedQuestion = cleanText(question).replace(/[。]+$/, '');
  return {
    question: `${trimmedQuestion}${/[？?]$/.test(trimmedQuestion) ? '' : '？'}`,
    answer: cleanText(answer).replace(/[。]+$/, ''),
    source: cleanText(source),
    priority
  };
}

function isValidFact(fact: Fact): boolean {
  if (!fact.question || !fact.answer || !fact.source) return false;
  if (fact.question.length < 8 || fact.question.length > MAX_QUESTION_LENGTH) return false;
  if (fact.answer.length < 2 || fact.answer.length > MAX_ANSWER_LENGTH) return false;
  if (/^(?:こと|もの|これ|それ|人類史の|について)$/.test(fact.answer)) return false;
  if (/(?:の|は|が|を|に|で|と|について)$/.test(fact.answer)) return false;
  return !normalizeKey(fact.question).includes(normalizeKey(fact.answer));
}

function extractFacts(sentence: string): Fact[] {
  const facts: Fact[] = [];
  const age = sentence.match(/約?\d+(?:\.\d+)?万?年前/);
  const exactDate = sentence.match(/\d{4}年(?:\d{1,2}月(?:\d{1,2}日)?)?/);
  const named = sentence.match(/「([^」]{2,30})」と名付けられた/);

  if (named) {
    const name = named[1];
    if (age) {
      facts.push(
        makeFact(`「${name}」と名付けられた化石骨は、約何年前のものか`, age[0], sentence, 100)
      );
    }
    if (exactDate) {
      facts.push(makeFact(`「${name}」の化石骨が発見されたのはいつか`, exactDate[0], sentence, 99));
    }
    const location = extractLocation(sentence, '発見');
    if (location) {
      facts.push(makeFact(`「${name}」の化石骨が発見された場所はどこか`, location, sentence, 98));
    }
  }

  const birth = sentence.match(/^(.{1,24}?)は[、，]?(.+?)(?:誕生した|誕生した、とされている|誕生したとされている)/);
  if (birth) {
    const subject = cleanEntity(birth[1]);
    const location = extractLocation(sentence, '誕生');
    if (subject && location) {
      facts.push(makeFact(`${subject}はどこで誕生したとされているか`, location, sentence, 95));
    }
    if (subject && age) {
      facts.push(makeFact(`${subject}が誕生したとされるのは約何年前か`, age[0], sentence, 90));
    }
  }

  const appeared = sentence.match(
    /(?:とよばれる|と呼ばれる)?\s*([^、，（）]{2,36}?)(?:（[^）]*）)?が登場した/
  );
  if (appeared) {
    const entity = cleanEntity(appeared[1]);
    const location = extractLocation(sentence, '登場');
    if (entity && age) {
      facts.push(makeFact(`${entity}が登場したのは約何年前か`, age[0], sentence, 94));
    }
    if (entity && location) {
      facts.push(makeFact(`${entity}が登場した場所はどこか`, location, sentence, 89));
    }
  }

  const fossil = sentence.match(
    /([^、，（）]{2,36}?)(?:（[^）]*）)?の化石(?:骨)?が(?:[^、，]*?)発見され(?:た|、)/
  );
  if (fossil) {
    const entity = cleanEntity(fossil[1]);
    const location = extractLocation(sentence, '発見');
    if (entity && location) {
      facts.push(makeFact(`${entity}の化石が発見された場所はどこか`, location, sentence, 92));
    }
    if (entity && exactDate && !named) {
      facts.push(makeFact(`${entity}の化石が発見されたのはいつか`, exactDate[0], sentence, 88));
    }
    if (entity && age && !named) {
      facts.push(makeFact(`発見された${entity}の化石は、約何年前のものか`, age[0], sentence, 87));
    }
  }

  if (/西方/.test(sentence) && /東方/.test(sentence) && /分かれて/.test(sentence)) {
    const westMatch = sentence.match(/西方（([^）]+)）/);
    const eastMatch = sentence.match(/東方（([^）]+)）/);
    const west = westMatch
      ? `西方（${westMatch[1].replace(/を、?/g, '').trim()}）`
      : '西方（ヨーロッパ方面）';
    const east = eastMatch
      ? `東方（${eastMatch[1].replace(/を、?/g, '').trim()}）`
      : '東方（中央アジア・東アジア方面）';
    facts.push(
      makeFact(
        'ユーラシアへ広がった人類は、どの二方向に分かれたと考えられているか',
        `${west}と${east}`,
        sentence,
        93
      )
    );
  }

  return facts.filter(isValidFact);
}

function toCloze(fact: Fact): QuestionCandidate | null {
  if (!fact.source.includes(fact.answer) || fact.source.length > 180) return null;
  return {
    question: fact.source.replace(fact.answer, '（　　）'),
    answer: fact.answer
  };
}

export function generateLocalQuestions(
  text: string,
  count: number,
  type: QuestionType,
  difficulty: Difficulty
): QuestionCandidate[] {
  const requested = Math.max(1, Math.min(count || 10, 20));
  const facts = splitSentences(text)
    .flatMap(extractFacts)
    .sort((left, right) => right.priority - left.priority);
  const unique: Fact[] = [];
  const seenQuestions = new Set<string>();
  const seenAnswers = new Set<string>();

  for (const fact of facts) {
    const questionKey = normalizeKey(fact.question);
    const answerKey = normalizeKey(fact.answer);
    if (!questionKey || !answerKey || seenQuestions.has(questionKey)) continue;
    if (seenAnswers.has(answerKey) && fact.priority < 95) continue;
    seenQuestions.add(questionKey);
    seenAnswers.add(answerKey);
    unique.push(fact);
  }

  const output: QuestionCandidate[] = [];
  for (let index = 0; index < unique.length && output.length < requested; index += 1) {
    const fact = unique[index];
    const useCloze =
      type === 'cloze' || (type === 'mix' && index % 4 === 3 && fact.source.length <= 110);
    const cloze = useCloze ? toCloze(fact) : null;
    if (cloze) {
      output.push(cloze);
      continue;
    }
    output.push({
      question:
        difficulty === 'easy' ? fact.question.replace(/は、?/, 'は、') : fact.question,
      answer: fact.answer
    });
  }

  return output;
}