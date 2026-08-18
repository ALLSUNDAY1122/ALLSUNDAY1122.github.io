(() => {
  'use strict';

  const MAX_QUESTION_LENGTH = 160;
  const MAX_ANSWER_LENGTH = 100;
  const TIME_EXPRESSION = '(?:(?:約|およそ)?\\d+(?:\\.\\d+)?万?\\d*年前(?:±\\d+(?:\\.\\d+)?万?\\d*年)?|数百万年前)';
  const EXACT_DATE_EXPRESSION = '\\d{4}年(?:\\d{1,2}月(?:\\d{1,2}日)?)?';
  const JP = '\\u3040-\\u30ff\\u3400-\\u9fff々〆ヶ';

  const repairOcrText = (value) => {
    const raw = String(value ?? '').normalize('NFKC').replace(/\r/g, '');
    const lines = raw.split(/\n+/).map((original) => {
      let line = original
        .replace(/[|｜¦]+/g, ' ')
        .replace(/[＿_=<>]{2,}/g, ' ')
        .replace(/[‐‑‒–—―ー]{3,}/g, ' ')
        .replace(/^[\\/＿_=<>#~|¦・･…\s]+/, '')
        .replace(/[ \t]+/g, ' ')
        .trim();
      for (let index = 0; index < 5; index += 1) {
        line = line
          .replace(new RegExp(`([${JP}0-9])\\s+([${JP}0-9])`, 'g'), '$1$2')
          .replace(new RegExp(`([${JP}])\\s+([A-Za-z])(?=[${JP}])`, 'g'), '$1$2')
          .replace(new RegExp(`([A-Za-z])\\s+([${JP}])`, 'g'), '$1$2');
      }
      line = line
        .replace(/\s*([()（）:：、。・/%％±~〜])\s*/g, '$1')
        .replace(/(\d)\s+(?=(?:万|億|千|百|十|年|月|日|歳|回|人|円|か月|ヶ月|%|％))/g, '$1')
        .replace(/(?<=(?:約|およそ))\s+(?=\d)/g, '')
        .replace(/楼続(?=入院)/g, '継続')
        .replace(/(?:競|新|吉)業不能(?=保険|給付)/g, '就業不能')
        .replace(/返選金/g, '返還金')
        .replace(/給付移月額/g, '給付金月額')
        .replace(/才和限度/g, '支払限度')
        .replace(/~/g, '～')
        .replace(/[ ]{2,}/g, ' ')
        .trim();
      const meaningful = (line.match(new RegExp(`[${JP}0-9]`, 'g')) || []).length;
      const noise = (line.match(/[A-Za-z|_=<>]/g) || []).length;
      if (meaningful < 2) return '';
      if (meaningful < 5 && noise > meaningful * 2) return '';
      return line;
    }).filter(Boolean);
    return lines.join('\n').replace(/\n{3,}/g, '\n\n').trim();
  };

  const normalizeText = (value) => repairOcrText(value)
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  const normalizeKey = (value) => normalizeText(value)
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_\[\]]/g, '')
    .toLowerCase();
  const cleanEntity = (value) => {
    let cleaned = normalizeText(value)
      .replace(/^.*?(?:では|によると)[、，]?/, '')
      .replace(/^(?:そして|また|一方|なお|現在のところ|最古の|猿人の一種|一種|いわゆる)/, '')
      .replace(/[、，]$/, '')
      .trim();
    const descriptors = cleaned.split(/(?:とよばれる|と呼ばれる|である[、，]?)/);
    if (descriptors.length > 1) cleaned = descriptors.at(-1).trim();
    return cleaned;
  };
  const splitSentencesV2 = (text) => normalizeText(text)
    .split(/(?<=[。！？!?])|\n+/)
    .map((sentence) => sentence.trim().replace(/[。！？!?]+$/, ''))
    .filter((sentence) => sentence.length >= 5)
    .filter((sentence) => !/^(?:\[[0-9]+\]|出典|参考文献|脚注)$/.test(sentence));
  const makeFact = (question, answer, source, priority = 50, factKey = '') => {
    const q = normalizeText(question).replace(/[。]+$/, '');
    return {
      question: q + (/[？?]$/.test(q) ? '' : '？'),
      answer: normalizeText(answer).replace(/[。]+$/, ''),
      source: normalizeText(source),
      priority,
      factKey: factKey || normalizeKey(`${question}|${answer}`)
    };
  };
  const isValidFact = (fact) => {
    if (!fact.question || !fact.answer || !fact.source) return false;
    if (fact.question.length < 5 || fact.question.length > MAX_QUESTION_LENGTH) return false;
    if (fact.answer.length < 1 || fact.answer.length > MAX_ANSWER_LENGTH) return false;
    if (/^(?:こと|もの|これ|それ|について|人類史の)$/.test(fact.answer)) return false;
    if (/(?:の|は|が|を|に|で|と|について)$/.test(fact.answer)) return false;
    return !normalizeKey(fact.question).includes(normalizeKey(fact.answer));
  };
  const yen = (value) => `${String(value).replace(/[^0-9]/g, '')}万円`;

  function extractStructuredFacts(text) {
    const source = normalizeText(text);
    const compact = source.replace(/\s+/g, '');
    const facts = [];
    const add = (question, answer, priority, factKey) => {
      const fact = makeFact(question, answer, source, priority, factKey);
      if (isValidFact(fact)) facts.push(fact);
    };
    if (/継続入院所得保障保険/.test(compact) && /14日以上継続入院/.test(compact)) add('継続入院所得保障保険の主な支払事由は何か', '14日以上継続入院', 100, 'insurance-hospitalization-14');
    if (/メンタル疾病.*14日以上[継楼]続入院/.test(compact)) add('メンタル入院所得保障充実型で給付対象となる入院は何か', 'メンタル疾病で14日以上継続入院', 99, 'mental-hospitalization-14');
    if (/給付金月額6か月分/.test(compact)) add('継続入院所得保障保険では、1回の継続入院で給付金月額の何か月分を受け取れるか', '6か月分', 98, 'benefit-six-months');
    if (/給付金月額2か月分/.test(compact)) add('メンタル疾病による継続入院では、追加で給付金月額の何か月分を受け取れるか', '2か月分', 97, 'benefit-two-months');
    const limit = compact.match(/(?:支払|才和)?限度.{0,20}?各?(\d{1,2})回/);
    if (limit) add('支払限度は何回か', `各${limit[1]}回`, 96, 'payment-limit');
    const packageAmount = compact.match(/パッケージ契約[:：]?(?:給付金)?月額(\d{1,3})万/);
    if (packageAmount) add('パッケージ契約の給付金月額はいくらか', yen(packageAmount[1]), 95, 'package-amount');
    const singleAmount = compact.match(/単品[:：]?(?:給付金)?月額(\d{1,3})万/);
    if (singleAmount) add('単品契約の給付金月額はいくらか', yen(singleAmount[1]), 94, 'single-amount');
    const maxAmount = compact.match(/最高.{0,25}?給付金月額(\d{1,3})万/);
    if (maxAmount) add('継続入院所得保障保険の最高給付金月額はいくらか', yen(maxAmount[1]), 93, 'max-benefit-amount');
    if (/就業不能保険/.test(compact) && /給付金月額30万/.test(compact)) add('参考の就業不能保険の給付金月額上限はいくらか', '30万円', 90, 'reference-disability-max');
    let age = compact.match(/契約年齢(\d{1,2})[~〜\-](\d{1,2})歳/);
    if (!age) {
      const joined = compact.match(/契約年齢(\d{4})歳/);
      if (joined) {
        const first = Number(joined[1].slice(0, 2));
        const second = Number(joined[1].slice(2));
        if (first >= 0 && first <= 90 && second > first && second <= 100) age = [joined[0], String(first), String(second)];
      }
    }
    if (age) add('契約年齢は何歳から何歳までか', `${age[1]}～${age[2]}歳`, 92, 'contract-age');
    if (/法人契約.{0,20}?取扱う/.test(compact)) add('法人契約の取扱いはあるか', '取り扱う', 88, 'corporate-contract');
    if (/健診割.{0,30}?対象/.test(compact) && /充実割.{0,30}?対象/.test(compact)) add('対象となる割引は何か', '健診割と充実割', 87, 'discounts');
    if (/(?:保険|保障)見直し/.test(compact) && /この保険からの見直し/.test(compact) && /この保険への見直し/.test(compact)) add('保障見直しの取扱範囲は何か', 'この保険からの見直しと、この保険への見直しの両方', 86, 'policy-review');
    const launchYear = compact.match(/継続入院所得保障保険\(無解約返還金\)(20\d{2})/);
    if (launchYear) add('継続入院所得保障保険（無解約返還金）の発売年はいつか', `${launchYear[1]}年`, 91, 'launch-year');
    if (/給付金月額10万.{0,30}?就業不能保険.{0,10}?通算/.test(compact) || /給付金月額10万\(「?就業不能保険」?と通算\)/.test(compact)) add('最高給付金月額は、どの保険と通算されるか', '就業不能保険', 92, 'combined-policy');
    if (/被保険者を従業員/.test(compact) && /受取人を法人/.test(compact)) add('法人契約では、被保険者と受取人をそれぞれ誰にするか', '被保険者は従業員、受取人は法人', 89, 'corporate-roles');
    return facts;
  }

  function extractLocation(sentence, eventWord) {
    const beforeEvent = eventWord && sentence.includes(eventWord) ? sentence.split(eventWord)[0] : sentence;
    const candidates = [...beforeEvent.matchAll(/(?:^|[、，])([^、，]{2,70}?(?:大陸|州|国|地方|地域|村付近|村|付近|半島|沿岸|タンザニア|エチオピア|アフリカ|ヨーロッパ|アジア))(?:で|では)[、，]?/g)];
    if (!candidates.length) return '';
    return cleanEntity(candidates.at(-1)[1]).replace(new RegExp(`^${TIME_EXPRESSION}(?:に)?`), '').trim();
  }

  function extractFacts(sentence) {
    const facts = [];
    const age = sentence.match(new RegExp(TIME_EXPRESSION));
    const exactDate = sentence.match(new RegExp(EXACT_DATE_EXPRESSION));
    const named = sentence.match(/「([^」]{2,30})」と名付けられた/);
    if (named) {
      const name = named[1];
      const objectName = sentence.includes('化石骨') ? '化石骨' : sentence.includes('化石') ? '化石' : '資料';
      if (age) facts.push(makeFact(`「${name}」と名付けられた${objectName}は、約何年前のものか`, age[0], sentence, 100, `name-age-${name}`));
      if (exactDate) facts.push(makeFact(`「${name}」が発見されたのはいつか`, exactDate[0], sentence, 99, `name-date-${name}`));
      const location = extractLocation(sentence, '発見');
      if (location) facts.push(makeFact(`「${name}」が発見された場所はどこか`, location, sentence, 98, `name-location-${name}`));
    }
    const birthPattern = new RegExp(`^([^、，]{1,30}?)は[、，]?(${TIME_EXPRESSION})に?([^、，]{2,70}?)で(?:誕生した|誕生した、とされている|誕生したとされている)`);
    const birth = sentence.match(birthPattern);
    if (birth) {
      const subject = cleanEntity(birth[1]);
      const location = cleanEntity(birth[3]);
      if (subject && birth[2]) facts.push(makeFact(`${subject}が誕生したとされるのは約何年前か`, birth[2], sentence, 97, `birth-age-${normalizeKey(subject)}`));
      if (subject && location) facts.push(makeFact(`${subject}はどこで誕生したとされているか`, location, sentence, 96, `birth-location-${normalizeKey(subject)}`));
    }
    const eventPattern = new RegExp(`([^、，]{2,70}?)が(?:初めて)?(登場|誕生|成立|開始|発生|発見)(?:したとされる|するとされる|した|する)のは[、，]?\\s*(${TIME_EXPRESSION})`, 'g');
    for (const match of sentence.matchAll(eventPattern)) {
      const subject = cleanEntity(match[1]);
      if (subject) facts.push(makeFact(`${subject}が${match[2]}したのは約何年前か`, match[3], sentence, 97, `event-${match[2]}-${normalizeKey(subject)}`));
    }
    const ageFirstEventPattern = new RegExp(`^(${TIME_EXPRESSION})(?:に)?([^、，]{0,70}?)(?:で[、，]?)?(.{2,70}?)が(登場|誕生|成立|開始|発生|発見)(?:した|する)`);
    const ageFirstEvent = sentence.match(ageFirstEventPattern);
    if (ageFirstEvent) {
      const subject = cleanEntity(ageFirstEvent[3]);
      if (subject) facts.push(makeFact(`${subject}が${ageFirstEvent[4]}したのは約何年前か`, ageFirstEvent[1], sentence, 95, `age-first-${ageFirstEvent[4]}-${normalizeKey(subject)}`));
      const location = cleanEntity(ageFirstEvent[2].replace(/で[、，]?$/, ''));
      if (subject && location && /(?:大陸|州|国|地方|地域|村|半島|沿岸|アフリカ|ヨーロッパ|アジア)/.test(location)) facts.push(makeFact(`${subject}が${ageFirstEvent[4]}した場所はどこか`, location, sentence, 90, `age-first-location-${normalizeKey(subject)}`));
    }
    const fossil = sentence.match(/([^、，（）()]{2,40}?)(?:[（(][^）)]*[）)])?の化石(?:骨)?が(?:[^、，]*?)発見され(?:た|、)/);
    if (fossil) {
      const entity = cleanEntity(fossil[1]);
      const location = extractLocation(sentence, '発見');
      if (entity && location) facts.push(makeFact(`${entity}の化石が発見された場所はどこか`, location, sentence, 94, `fossil-location-${normalizeKey(entity)}`));
      if (entity && exactDate && !named) facts.push(makeFact(`${entity}の化石が発見されたのはいつか`, exactDate[0], sentence, 91, `fossil-date-${normalizeKey(entity)}`));
    }
    if (/西方/.test(sentence) && /東方/.test(sentence) && /分かれて/.test(sentence)) facts.push(makeFact('ユーラシアへ広がった人類は、どの二方向に分かれたと考えられているか', '西方と東方', sentence, 93, 'migration-directions'));
    if (!facts.length) {
      const definition = sentence.match(/^([^、，]{2,45}?)(?:とは|は)[、，]?\\s*([^。]{3,90}?)(?:をいう|と呼ばれる|である|とされている|とされる)$/);
      if (definition) {
        const subject = cleanEntity(definition[1]);
        const answer = cleanEntity(definition[2]);
        if (subject && answer && !new RegExp(TIME_EXPRESSION).test(answer)) facts.push(makeFact(`${subject}とは何か`, answer, sentence, 70, `definition-${normalizeKey(subject)}`));
      }
    }
    return facts.filter(isValidFact);
  }

  const toCloze = (fact) => {
    if (!fact.source.includes(fact.answer) || fact.source.length > 180) return null;
    const cloze = fact.source.replace(fact.answer, '（　　）');
    return cloze === fact.source ? null : `${cloze}｜${fact.answer}`;
  };
  function generateQuestionsV2(text, count = 10, type = 'mix', difficulty = 'normal') {
    const requested = Math.max(1, Math.min(Number(count) || 10, 20));
    const repaired = repairOcrText(text);
    const facts = [...extractStructuredFacts(repaired), ...splitSentencesV2(repaired).flatMap(extractFacts)].sort((left, right) => right.priority - left.priority);
    const unique = [];
    const seenFacts = new Set();
    const seenQuestions = new Set();
    for (const fact of facts) {
      const factKey = fact.factKey || normalizeKey(`${fact.question}|${fact.answer}`);
      const questionKey = normalizeKey(fact.question);
      const answerKey = normalizeKey(fact.answer);
      if (!factKey || !questionKey || !answerKey || seenFacts.has(factKey) || seenQuestions.has(questionKey)) continue;
      seenFacts.add(factKey);
      seenQuestions.add(questionKey);
      unique.push(fact);
    }
    const output = [];
    for (let index = 0; index < unique.length && output.length < requested; index += 1) {
      const fact = unique[index];
      const useCloze = type === 'cloze' || (type === 'mix' && index % 4 === 3);
      const cloze = useCloze ? toCloze(fact) : null;
      if (cloze) output.push(cloze);
      else output.push(`${difficulty === 'easy' ? fact.question.replace(/は、?/, 'は、') : fact.question}｜${fact.answer}`);
    }
    return output;
  }

  globalThis.ToruTangoGeneratorV2 = { generateQuestionsV2, repairOcrText, splitSentencesV2, extractFacts, extractStructuredFacts };

  if (typeof document !== 'undefined') {
    const button = document.querySelector('#generate');
    const source = document.querySelector('#sourceText');
    const status = document.querySelector('#genStatus');
    const generated = document.querySelector('#generated');
    const addGenerated = document.querySelector('#addGenerated');
    const removeDuplicates = document.querySelector('#removeDuplicates');
    const questionCount = document.querySelector('#questionCount');
    const questionType = document.querySelector('#questionType');
    const difficulty = document.querySelector('#difficulty');
    if (button && source && status && generated) {
      button.onclick = () => {
        const repaired = repairOcrText(source.value);
        source.value = repaired;
        status.classList.remove('hidden');
        if (repaired.length < 20) {
          status.textContent = '教材本文を20文字以上入力してください。';
          return;
        }
        const questions = generateQuestionsV2(repaired, Number(questionCount?.value || 10), questionType?.value || 'mix', difficulty?.value || 'normal');
        if (!questions.length) {
          status.textContent = 'OCR文字を整形しましたが、確認できる事実を抽出できませんでした。AI作問を使用するか、認識結果を修正してください。';
          generated.classList.add('hidden');
          addGenerated?.classList.add('hidden');
          removeDuplicates?.classList.add('hidden');
          return;
        }
        generated.value = questions.join('\n');
        generated.classList.remove('hidden');
        addGenerated?.classList.remove('hidden');
        removeDuplicates?.classList.remove('hidden');
        const requested = Number(questionCount?.value || 10);
        status.textContent = questions.length < requested
          ? `OCR空白と罫線ノイズを整形し、確認可能な${questions.length}枚を生成しました。`
          : `OCR空白と罫線ノイズを整形し、${questions.length}枚を生成しました。`;
      };
    }
  }
})();
