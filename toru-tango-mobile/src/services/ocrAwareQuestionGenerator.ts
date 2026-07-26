import { generateLocalQuestions } from './localQuestionGenerator';
import type { Difficulty, QuestionCandidate, QuestionType } from '@/src/types';

const JAPANESE_RANGE = '\\u3040-\\u30ff\\u3400-\\u9fff々〆ヶ';

type StructuredFact = QuestionCandidate & {
  source: string;
  priority: number;
  factKey: string;
};

export function repairOcrText(value: string): string {
  const raw = value.normalize('NFKC').replace(/\r/g, '');
  const lines = raw
    .split(/\n+/)
    .map((original) => {
      let line = original
        .replace(/[|｜¦]+/g, ' ')
        .replace(/[＿_=<>]{2,}/g, ' ')
        .replace(/[‐‑‒–—―ー]{3,}/g, ' ')
        .replace(/^[\\/＿_=<>#~|¦・･…\s]+/, '')
        .replace(/[ \t]+/g, ' ')
        .trim();

      for (let index = 0; index < 5; index += 1) {
        line = line
          .replace(
            new RegExp(`([${JAPANESE_RANGE}0-9])\\s+([${JAPANESE_RANGE}0-9])`, 'g'),
            '$1$2'
          )
          .replace(
            new RegExp(`([${JAPANESE_RANGE}])\\s+([A-Za-z])(?=[${JAPANESE_RANGE}])`, 'g'),
            '$1$2'
          )
          .replace(new RegExp(`([A-Za-z])\\s+([${JAPANESE_RANGE}])`, 'g'), '$1$2');
      }

      line = line
        .replace(/\s*([()（）:：、。・/%％±~〜])\s*/g, '$1')
        .replace(
          /(\d)\s+(?=(?:万|億|千|百|十|年|月|日|歳|回|人|円|か月|ヶ月|%|％))/g,
          '$1'
        )
        .replace(/楼続(?=入院)/g, '継続')
        .replace(/(?:競|新|吉)業不能(?=保険|給付)/g, '就業不能')
        .replace(/返選金/g, '返還金')
        .replace(/給付移月額/g, '給付金月額')
        .replace(/才和限度/g, '支払限度')
        .replace(/~/g, '～')
        .replace(/[ ]{2,}/g, ' ')
        .trim();

      const meaningful = (
        line.match(new RegExp(`[${JAPANESE_RANGE}0-9]`, 'g')) ?? []
      ).length;
      const noise = (line.match(/[A-Za-z|_=<>]/g) ?? []).length;
      if (meaningful < 2) return '';
      if (meaningful < 5 && noise > meaningful * 2) return '';
      return line;
    })
    .filter(Boolean);

  return lines.join('\n').replace(/\n{3,}/g, '\n\n').trim();
}

function normalizeKey(value: string): string {
  return repairOcrText(value)
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_\[\]]/g, '')
    .toLocaleLowerCase('ja-JP');
}

function makeFact(
  question: string,
  answer: string,
  source: string,
  priority: number,
  factKey: string
): StructuredFact {
  return {
    question: `${question.replace(/[。]+$/, '')}${/[？?]$/.test(question) ? '' : '？'}`,
    answer,
    source,
    priority,
    factKey
  };
}

function amountInTenThousands(value: string): string {
  return `${value.replace(/[^0-9]/g, '')}万円`;
}

function extractStructuredFacts(text: string): StructuredFact[] {
  const source = repairOcrText(text);
  const compact = source.replace(/\s+/g, '');
  const facts: StructuredFact[] = [];
  const add = (question: string, answer: string, priority: number, factKey: string) => {
    if (!question || !answer) return;
    facts.push(makeFact(question, answer, source, priority, factKey));
  };

  if (/継続入院所得保障保険/.test(compact) && /14日以上継続入院/.test(compact)) {
    add(
      '継続入院所得保障保険の主な支払事由は何か',
      '14日以上継続入院',
      100,
      'insurance-hospitalization-14'
    );
  }
  if (/メンタル疾病.*14日以上[継楼]続入院/.test(compact)) {
    add(
      'メンタル入院所得保障充実型で給付対象となる入院は何か',
      'メンタル疾病で14日以上継続入院',
      99,
      'mental-hospitalization-14'
    );
  }
  if (/給付金月額6か月分/.test(compact)) {
    add(
      '継続入院所得保障保険では、1回の継続入院で給付金月額の何か月分を受け取れるか',
      '6か月分',
      98,
      'benefit-six-months'
    );
  }
  if (/給付金月額2か月分/.test(compact)) {
    add(
      'メンタル疾病による継続入院では、追加で給付金月額の何か月分を受け取れるか',
      '2か月分',
      97,
      'benefit-two-months'
    );
  }

  const limit = compact.match(/(?:支払|才和)?限度.{0,20}?各?(\d{1,2})回/);
  if (limit?.[1]) add('支払限度は何回か', `各${limit[1]}回`, 96, 'payment-limit');

  const packageAmount = compact.match(/パッケージ契約[:：]?(?:給付金)?月額(\d{1,3})万/);
  if (packageAmount?.[1]) {
    add(
      'パッケージ契約の給付金月額はいくらか',
      amountInTenThousands(packageAmount[1]),
      95,
      'package-amount'
    );
  }

  const singleAmount = compact.match(/単品[:：]?(?:給付金)?月額(\d{1,3})万/);
  if (singleAmount?.[1]) {
    add(
      '単品契約の給付金月額はいくらか',
      amountInTenThousands(singleAmount[1]),
      94,
      'single-amount'
    );
  }

  const maxAmount = compact.match(/最高.{0,25}?給付金月額(\d{1,3})万/);
  if (maxAmount?.[1]) {
    add(
      '継続入院所得保障保険の最高給付金月額はいくらか',
      amountInTenThousands(maxAmount[1]),
      93,
      'max-benefit-amount'
    );
  }

  let age = compact.match(/契約年齢(\d{1,2})[～\-](\d{1,2})歳/);
  if (!age) {
    const joined = compact.match(/契約年齢(\d{4})歳/);
    if (joined?.[1]) {
      const first = Number(joined[1].slice(0, 2));
      const second = Number(joined[1].slice(2));
      if (first >= 0 && first <= 90 && second > first && second <= 100) {
        age = [joined[0], String(first), String(second)];
      }
    }
  }
  if (age?.[1] && age[2]) {
    add('契約年齢は何歳から何歳までか', `${age[1]}～${age[2]}歳`, 92, 'contract-age');
  }

  if (
    /給付金月額10万.{0,30}?就業不能保険.{0,10}?通算/.test(compact) ||
    /給付金月額10万\(「?就業不能保険」?と通算\)/.test(compact)
  ) {
    add(
      '最高給付金月額は、どの保険と通算されるか',
      '就業不能保険',
      92,
      'combined-policy'
    );
  }

  const launchYear = compact.match(/継続入院所得保障保険\(無解約返還金\)(20\d{2})/);
  if (launchYear?.[1]) {
    add(
      '継続入院所得保障保険（無解約返還金）の発売年はいつか',
      `${launchYear[1]}年`,
      91,
      'launch-year'
    );
  }

  if (/被保険者を従業員/.test(compact) && /受取人を法人/.test(compact)) {
    add(
      '法人契約では、被保険者と受取人をそれぞれ誰にするか',
      '被保険者は従業員、受取人は法人',
      89,
      'corporate-roles'
    );
  }
  if (/法人契約.{0,20}?取扱う/.test(compact)) {
    add('法人契約の取扱いはあるか', '取り扱う', 88, 'corporate-contract');
  }
  if (/健診割.{0,30}?対象/.test(compact) && /充実割.{0,30}?対象/.test(compact)) {
    add('対象となる割引は何か', '健診割と充実割', 87, 'discounts');
  }
  if (
    /(?:保険|保障)見直し/.test(compact) &&
    /この保険からの見直し/.test(compact) &&
    /この保険への見直し/.test(compact)
  ) {
    add(
      '保障見直しの取扱範囲は何か',
      'この保険からの見直しと、この保険への見直しの両方',
      86,
      'policy-review'
    );
  }

  return facts;
}

function toCandidate(fact: StructuredFact, type: QuestionType, index: number): QuestionCandidate {
  const shouldUseCloze = type === 'cloze' || (type === 'mix' && index % 4 === 3);
  if (shouldUseCloze && fact.source.includes(fact.answer) && fact.source.length <= 180) {
    return {
      question: fact.source.replace(fact.answer, '（　　）'),
      answer: fact.answer
    };
  }
  return { question: fact.question, answer: fact.answer };
}

export function generateOcrAwareQuestions(
  text: string,
  count: number,
  type: QuestionType,
  difficulty: Difficulty
): QuestionCandidate[] {
  const requested = Math.max(1, Math.min(count || 10, 20));
  const repaired = repairOcrText(text);
  const structured = extractStructuredFacts(repaired)
    .sort((left, right) => right.priority - left.priority)
    .map((fact, index) => toCandidate(fact, type, index));
  const general = generateLocalQuestions(repaired, requested, type, difficulty);
  const output: QuestionCandidate[] = [];
  const seenFacts = new Set<string>();
  const seenQuestions = new Set<string>();

  for (const candidate of [...structured, ...general]) {
    const questionKey = normalizeKey(candidate.question);
    const answerKey = normalizeKey(candidate.answer);
    const factKey = `${questionKey}|${answerKey}`;
    if (!questionKey || !answerKey || seenFacts.has(factKey) || seenQuestions.has(questionKey)) continue;
    seenFacts.add(factKey);
    seenQuestions.add(questionKey);
    output.push(candidate);
    if (output.length >= requested) break;
  }

  return output;
}
