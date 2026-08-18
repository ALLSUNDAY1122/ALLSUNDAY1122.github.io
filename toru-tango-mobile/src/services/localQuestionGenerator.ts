import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';

const MAX_QUESTION_LENGTH = 150;
const MAX_ANSWER_LENGTH = 90;
const TIME_EXPRESSION =
  '(?:(?:約|およそ)?\\d+(?:\\.\\d+)?万?\\d*年前(?:±\\d+(?:\\.\\d+)?万?\\d*年)?|数百万年前)';
const EXACT_DATE_EXPRESSION = '\\d{4}年(?:\\d{1,2}月(?:\\d{1,2}日)?)?';

type Fact = {
  question: string;
  answer: string;
  source: string;
  priority: number;
  factKey: string;
};

const cleanText = (value: string): string =>
  value.replace(/\r/g, '').replace(/[ \t]+/g, ' ').replace(/\n{3,}/g, '\n\n').trim();

const normalizeKey = (value: string): string =>
  cleanText(value)
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_\[\]]/g, '')
    .toLocaleLowerCase('ja-JP');

function cleanEntity(value: string): string {
  let cleaned = cleanText(value).replace(/^.*?(?:では|によると)[、，]\s*/, '');
  const descriptorParts = cleaned.split(/(?:とよばれる|と呼ばれる|である[、，]?)/);
  if (descriptorParts.length > 1) cleaned = descriptorParts[descriptorParts.length - 1] ?? cleaned;
  return cleaned
    .replace(
      /^(?:そして|また|一方|なお|現在のところ|最古の|猿人の一種|一種|いわゆる)\s*/,
      ''
    )
    .replace(/[、，]$/, '')
    .trim();
}

function splitSentences(text: string): string[] {
  return cleanText(text)
    .split(/(?<=[。！？!?])|\n+/)
    .map((sentence) => sentence.trim().replace(/[。！？!?]+$/, ''))
    .filter((sentence) => sentence.length >= 8)
    .filter((sentence) => !/^(?:\[[0-9]+\]|出典|参考文献|脚注)$/.test(sentence));
}

function makeFact(
  question: string,
  answer: string,
  source: string,
  priority = 50,
  factKey = ''
): Fact {
  const normalizedQuestion = cleanText(question).replace(/[。]+$/, '');
  return {
    question: `${normalizedQuestion}${/[？?]$/.test(normalizedQuestion) ? '' : '？'}`,
    answer: cleanText(answer).replace(/[。]+$/, ''),
    source: cleanText(source),
    priority,
    factKey: factKey || normalizeKey(`${question}|${answer}`)
  };
}

function isValidFact(fact: Fact): boolean {
  if (!fact.question || !fact.answer || !fact.source) return false;
  if (fact.question.length < 6 || fact.question.length > MAX_QUESTION_LENGTH) return false;
  if (fact.answer.length < 1 || fact.answer.length > MAX_ANSWER_LENGTH) return false;
  if (/^(?:こと|もの|これ|それ|について|人類史の)$/.test(fact.answer)) return false;
  if (/(?:の|は|が|を|に|で|と|について)$/.test(fact.answer)) return false;
  return !normalizeKey(fact.question).includes(normalizeKey(fact.answer));
}

function extractLocation(sentence: string, eventWord: string): string {
  const beforeEvent = sentence.split(eventWord)[0] ?? sentence;
  const candidates = [
    ...beforeEvent.matchAll(
      /([^、，]{2,60}?(?:大陸|州|国|地方|地域|村付近|村|付近|半島|沿岸|タンザニア|エチオピア|アフリカ|ヨーロッパ|アジア))で(?:は)?[、，]?/g
    )
  ];
  if (!candidates.length) return '';
  const latest = candidates[candidates.length - 1];
  return cleanEntity(latest?.[1] ?? '')
    .replace(new RegExp(`^${TIME_EXPRESSION}(?:に)?`), '')
    .trim();
}

function eventQuestion(subject: string, event: string): string {
  const endings: Record<string, string> = {
    登場: '登場したとされるのは約何年前か',
    誕生: '誕生したとされるのは約何年前か',
    成立: '成立したのは約何年前か',
    開始: '始まったのは約何年前か',
    発生: '発生したのは約何年前か',
    発見: '発見されたのは約何年前か'
  };
  return `${subject}が${endings[event] ?? `${event}したのは約何年前か`}`;
}

function extractFacts(sentence: string): Fact[] {
  const facts: Fact[] = [];
  const contextMatch = sentence.match(/^([^、，]{2,50}?)(?:では|によると)[、，]/);
  const context = contextMatch ? cleanEntity(contextMatch[1] ?? '') : '';
  const age = sentence.match(new RegExp(TIME_EXPRESSION));
  const exactDate = sentence.match(new RegExp(EXACT_DATE_EXPRESSION));
  const named = sentence.match(/「([^」]{2,30})」と名付けられた/);

  if (named) {
    const name = named[1] ?? '';
    const objectName = sentence.includes('化石骨')
      ? '化石骨'
      : sentence.includes('化石')
        ? '化石'
        : '資料';
    if (age) {
      facts.push(
        makeFact(
          `「${name}」と名付けられた${objectName}は、約何年前のものか`,
          age[0],
          sentence,
          100,
          `name-age-${name}`
        )
      );
    }
    if (exactDate) {
      facts.push(
        makeFact(
          `「${name}」が発見されたのはいつか`,
          exactDate[0],
          sentence,
          99,
          `name-date-${name}`
        )
      );
    }
    const location = extractLocation(sentence, '発見');
    if (location) {
      facts.push(
        makeFact(
          `「${name}」が発見された場所はどこか`,
          location,
          sentence,
          98,
          `name-location-${name}`
        )
      );
    }
  }

  const eventPattern = new RegExp(
    `([^、，]{2,70}?)が(?:初めて)?(登場|誕生|成立|開始|発生|発見)(?:する|した|したとされる|するとされる)のは[、，]?\\s*(${TIME_EXPRESSION})`,
    'g'
  );
  for (const match of sentence.matchAll(eventPattern)) {
    const subject = cleanEntity(match[1] ?? '');
    const event = match[2] ?? '';
    const answer = match[3] ?? '';
    if (!subject || !event || !answer) continue;
    facts.push(
      makeFact(
        eventQuestion(subject, event),
        answer,
        sentence,
        97,
        `event-${event}-${normalizeKey(subject)}`
      )
    );
  }

  const birth = sentence.match(
    /^(.{1,30}?)は[、，]?(.+?)(?:誕生した|誕生した、とされている|誕生したとされている)/
  );
  if (birth) {
    const subject = cleanEntity(birth[1] ?? '');
    const location = extractLocation(sentence, '誕生');
    if (subject && location) {
      facts.push(
        makeFact(
          `${subject}はどこで誕生したとされているか`,
          location,
          sentence,
          96,
          `birth-location-${normalizeKey(subject)}`
        )
      );
    }
    if (subject && age) {
      facts.push(
        makeFact(
          `${subject}が誕生したとされるのは約何年前か`,
          age[0],
          sentence,
          95,
          `birth-age-${normalizeKey(subject)}`
        )
      );
    }
  }

  const hasNamedEvent = /(?:誕生|登場|発見|成立|開始|発生)/.test(sentence);
  if (!hasNamedEvent) {
    const quantitativePattern = new RegExp(
      `(?:^|[、，])([^、，]{2,90}?)(?:は|が)[、，]?\\s*(${TIME_EXPRESSION})(?:のこと)?(?:とされる|とされている|であり|である|と推定された|と推定される|と考えられている)?`,
      'g'
    );
    for (const match of sentence.matchAll(quantitativePattern)) {
      const subject = cleanEntity(match[1] ?? '');
      const answer = match[2] ?? '';
      if (!subject || !answer || /^(?:約|およそ|数)$/.test(subject)) continue;
      const prefix = context && !subject.includes(context) ? `${context}で、` : '';
      const question =
        subject.endsWith('年代') || subject.endsWith('時期')
          ? `${prefix}${subject}はいつ頃か`
          : `${prefix}${subject}は約何年前か`;
      facts.push(
        makeFact(
          question,
          answer,
          sentence,
          94,
          `time-${normalizeKey(subject)}`
        )
      );
    }

    const clausePattern = new RegExp(
      `([^、，]{3,100}?)(?:は|が)[、，]?\\s*(${TIME_EXPRESSION})(?=(?:であり|である|と推定|とされ|[、，]|$))`,
      'g'
    );
    for (const match of sentence.matchAll(clausePattern)) {
      const subject = cleanEntity(match[1] ?? '');
      const answer = match[2] ?? '';
      if (!subject || !answer) continue;
      const prefix = context && !subject.includes(context) ? `${context}で、` : '';
      facts.push(
        makeFact(
          `${prefix}${subject}はいつ頃か`,
          answer,
          sentence,
          93,
          `clause-${normalizeKey(subject)}`
        )
      );
    }
  }

  const appeared = sentence.match(
    /(?:とよばれる|と呼ばれる)?\s*([^、，（）]{2,40}?)(?:（[^）]*）)?が登場(?:した|する)/
  );
  if (appeared) {
    const entity = cleanEntity(appeared[1] ?? '');
    const location = extractLocation(sentence, '登場');
    if (entity && age) {
      facts.push(
        makeFact(
          `${entity}が登場したのは約何年前か`,
          age[0],
          sentence,
          94,
          `appear-age-${normalizeKey(entity)}`
        )
      );
    }
    if (entity && location) {
      facts.push(
        makeFact(
          `${entity}が登場した場所はどこか`,
          location,
          sentence,
          89,
          `appear-location-${normalizeKey(entity)}`
        )
      );
    }
  }

  const fossil = sentence.match(
    /([^、，（）]{2,40}?)(?:（[^）]*）)?の化石(?:骨)?が(?:[^、，]*?)発見され(?:た|、)/
  );
  if (fossil) {
    const entity = cleanEntity(fossil[1] ?? '');
    const location = extractLocation(sentence, '発見');
    if (entity && location) {
      facts.push(
        makeFact(
          `${entity}の化石が発見された場所はどこか`,
          location,
          sentence,
          92,
          `fossil-location-${normalizeKey(entity)}`
        )
      );
    }
    if (entity && exactDate && !named) {
      facts.push(
        makeFact(
          `${entity}の化石が発見されたのはいつか`,
          exactDate[0],
          sentence,
          88,
          `fossil-date-${normalizeKey(entity)}`
        )
      );
    }
  }

  if (/西方/.test(sentence) && /東方/.test(sentence) && /分かれて/.test(sentence)) {
    facts.push(
      makeFact(
        'ユーラシアへ広がった人類は、どの二方向に分かれたと考えられているか',
        '西方と東方',
        sentence,
        93,
        'migration-directions'
      )
    );
  }

  if (!facts.length) {
    const definition = sentence.match(
      /^([^、，]{2,45}?)(?:とは|は)[、，]?\s*([^。]{3,90}?)(?:をいう|と呼ばれる|である|とされている|とされる)$/
    );
    if (definition) {
      const subject = cleanEntity(definition[1] ?? '');
      const answer = cleanEntity(definition[2] ?? '');
      if (subject && answer && !new RegExp(TIME_EXPRESSION).test(answer)) {
        facts.push(
          makeFact(
            `${subject}とは何か`,
            answer,
            sentence,
            70,
            `definition-${normalizeKey(subject)}`
          )
        );
      }
    }
  }

  return facts.filter(isValidFact);
}

function toCloze(fact: Fact): QuestionCandidate | null {
  if (!fact.source.includes(fact.answer) || fact.source.length > 180) return null;
  const cloze = fact.source.replace(fact.answer, '（　　）');
  if (cloze === fact.source) return null;
  return { question: cloze, answer: fact.answer };
}

export function generateLocalQuestions(
  text: string,
  count: number,
  type: QuestionType,
  difficulty: Difficulty
): QuestionCandidate[] {
  const requested = Math.max(1, Math.min(Number(count) || 10, 20));
  const facts = splitSentences(text)
    .flatMap(extractFacts)
    .sort((left, right) => right.priority - left.priority);

  const unique: Fact[] = [];
  const seenFacts = new Set<string>();
  const seenQuestions = new Set<string>();
  const seenAnswers = new Set<string>();

  for (const fact of facts) {
    const factKey = fact.factKey || normalizeKey(`${fact.question}|${fact.answer}`);
    const questionKey = normalizeKey(fact.question);
    const answerKey = normalizeKey(fact.answer);
    if (!factKey || !questionKey || seenFacts.has(factKey) || seenQuestions.has(questionKey)) {
      continue;
    }
    if (seenAnswers.has(answerKey) && fact.priority < 95) continue;
    seenFacts.add(factKey);
    seenQuestions.add(questionKey);
    seenAnswers.add(answerKey);
    unique.push(fact);
  }

  const output: QuestionCandidate[] = [];
  for (let index = 0; index < unique.length && output.length < requested; index += 1) {
    const fact = unique[index];
    const useCloze = type === 'cloze' || (type === 'mix' && index % 4 === 3);
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
