(() => {
  'use strict';

  const MAX_QUESTION_LENGTH = 140;
  const MAX_ANSWER_LENGTH = 70;

  const normalizeText = (value) => String(value ?? '')
    .replace(/\r/g, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();

  const normalizeKey = (value) => normalizeText(value)
    .replace(/[\s「」『』（）()、，。・：:！？!?＿＿＿_]/g, '')
    .toLowerCase();

  const splitSentencesV2 = (text) => normalizeText(text)
    .split(/(?<=[。！？!?])|\n+/)
    .map((sentence) => sentence.trim().replace(/[。！？!?]+$/, ''))
    .filter((sentence) => sentence.length >= 12)
    .filter((sentence) => /(?:した|された|している|されている|である|とされる|とされている|考えられている|誕生|登場|発見|名付け|広げ|進む|分かれ)/.test(sentence));

  const cleanEntity = (value) => {
    let cleaned = normalizeText(value).replace(/[、，]$/, '').trim();
    const descriptorParts = cleaned.split(/(?:とよばれる|と呼ばれる|である[、，]?)/);
    if (descriptorParts.length > 1) cleaned = descriptorParts.at(-1);
    cleaned = cleaned.replace(/^.*?[、，]/, '');
    return cleaned
      .replace(/^(?:現在のところ|最古の|猿人の一種|一種|いわゆる)\s*/, '')
      .replace(/[、，]$/, '')
      .trim();
  };

  const extractLocation = (sentence, eventWord) => {
    const beforeEvent = eventWord ? sentence.split(eventWord)[0] : sentence;
    const candidates = [...beforeEvent.matchAll(/([^、，]{2,45}?(?:大陸|州|国|地方|地域|村付近|村|付近|半島|沿岸|タンザニア|エチオピア))で(?:は)?[、，]?/g)];
    const stripTime = (value) => cleanEntity(value)
      .replace(/^(?:約?\d+(?:\.\d+)?万?年前|数百万年前)(?:から約?\d+(?:\.\d+)?万?年前)?(?:に)?/, '')
      .trim();
    if (candidates.length) return stripTime(candidates.at(-1)[1]);
    const leading = beforeEvent.match(/^([^、，]{2,45}?)で(?:は)?[、，]/);
    return leading ? stripTime(leading[1]) : '';
  };

  const makeFact = (question, answer, source, priority = 50) => ({
    question: normalizeText(question).replace(/[。]+$/, '') + (/[？?]$/.test(question) ? '' : '？'),
    answer: normalizeText(answer).replace(/[。]+$/, ''),
    source: normalizeText(source),
    priority
  });

  const isValidFact = (fact) => {
    if (!fact.question || !fact.answer || !fact.source) return false;
    if (fact.question.length < 8 || fact.question.length > MAX_QUESTION_LENGTH) return false;
    if (fact.answer.length < 2 || fact.answer.length > MAX_ANSWER_LENGTH) return false;
    if (/^(?:こと|もの|これ|それ|人類史の|について)$/.test(fact.answer)) return false;
    if (/(?:の|は|が|を|に|で|と|について)$/.test(fact.answer)) return false;
    if (normalizeKey(fact.question).includes(normalizeKey(fact.answer))) return false;
    return true;
  };

  function extractFacts(sentence) {
    const facts = [];
    const age = sentence.match(/約?\d+(?:\.\d+)?万?年前/);
    const exactDate = sentence.match(/\d{4}年(?:\d{1,2}月(?:\d{1,2}日)?)?/);
    const named = sentence.match(/「([^」]{2,30})」と名付けられた/);

    if (named) {
      const name = named[1];
      if (age) facts.push(makeFact(`「${name}」と名付けられた化石骨は、約何年前のものか`, age[0], sentence, 100));
      if (exactDate) facts.push(makeFact(`「${name}」の化石骨が発見されたのはいつか`, exactDate[0], sentence, 99));
      const location = extractLocation(sentence, '発見');
      if (location) facts.push(makeFact(`「${name}」の化石骨が発見された場所はどこか`, location, sentence, 98));
    }

    const birth = sentence.match(/^(.{1,24}?)は[、，]?(.+?)(?:誕生した|誕生した、とされている|誕生したとされている)/);
    if (birth) {
      const subject = cleanEntity(birth[1]);
      const location = extractLocation(sentence, '誕生');
      if (subject && location) facts.push(makeFact(`${subject}はどこで誕生したとされているか`, location, sentence, 95));
      if (subject && age) facts.push(makeFact(`${subject}が誕生したとされるのは約何年前か`, age[0], sentence, 90));
    }

    const appeared = sentence.match(/(?:とよばれる|と呼ばれる)?\s*([^、，（）]{2,36}?)(?:（[^）]*）)?が登場した/);
    if (appeared) {
      const entity = cleanEntity(appeared[1]);
      const location = extractLocation(sentence, '登場');
      if (entity && age) facts.push(makeFact(`${entity}が登場したのは約何年前か`, age[0], sentence, 94));
      if (entity && location) facts.push(makeFact(`${entity}が登場した場所はどこか`, location, sentence, 89));
    }

    const fossil = sentence.match(/([^、，（）]{2,36}?)(?:（[^）]*）)?の化石(?:骨)?が(?:[^、，]*?)発見され(?:た|、)/);
    if (fossil) {
      const entity = cleanEntity(fossil[1]);
      const location = extractLocation(sentence, '発見');
      if (entity && location) facts.push(makeFact(`${entity}の化石が発見された場所はどこか`, location, sentence, 92));
      if (entity && exactDate && !named) facts.push(makeFact(`${entity}の化石が発見されたのはいつか`, exactDate[0], sentence, 88));
      if (entity && age && !named) facts.push(makeFact(`発見された${entity}の化石は、約何年前のものか`, age[0], sentence, 87));
    }

    if (/西方/.test(sentence) && /東方/.test(sentence) && /分かれて/.test(sentence)) {
      let west = '西方（ヨーロッパ方面）';
      let east = '東方（中央アジア・東アジア方面）';
      const westMatch = sentence.match(/西方（([^）]+)）/);
      const eastMatch = sentence.match(/東方（([^）]+)）/);
      if (westMatch) west = `西方（${westMatch[1].replace(/を、?/g, '').trim()}）`;
      if (eastMatch) east = `東方（${eastMatch[1].replace(/を、?/g, '').trim()}）`;
      facts.push(makeFact('ユーラシアへ広がった人類は、どの二方向に分かれたと考えられているか', `${west}と${east}`, sentence, 93));
    }

    const quoted = [...sentence.matchAll(/「([^」]{2,30})」/g)].map((match) => match[1]);
    for (const answer of quoted) {
      if (named && answer === named[1]) continue;
      if (sentence.includes(`「${answer}」と名付け`)) continue;
      const cloze = sentence.replace(`「${answer}」`, '「（　　）」');
      facts.push(makeFact(`${cloze}`, answer, sentence, 55));
    }

    return facts.filter(isValidFact);
  }

  const toCloze = (fact) => {
    const escaped = fact.answer.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const exact = new RegExp(escaped);
    if (!exact.test(fact.source)) return null;
    const cloze = fact.source.replace(exact, '（　　）');
    if (cloze === fact.source || cloze.length > 180) return null;
    return `${cloze}｜${fact.answer}`;
  };

  function generateQuestionsV2(text, count = 10, type = 'mix', difficulty = 'normal') {
    const requested = Math.max(1, Math.min(Number(count) || 10, 20));
    const allFacts = splitSentencesV2(text)
      .flatMap(extractFacts)
      .sort((a, b) => b.priority - a.priority);

    const seenQuestions = new Set();
    const seenAnswers = new Set();
    const unique = [];

    for (const fact of allFacts) {
      const qKey = normalizeKey(fact.question);
      const aKey = normalizeKey(fact.answer);
      if (!qKey || !aKey || seenQuestions.has(qKey)) continue;
      if (seenAnswers.has(aKey) && fact.priority < 95) continue;
      seenQuestions.add(qKey);
      seenAnswers.add(aKey);
      unique.push(fact);
    }

    const output = [];
    for (let index = 0; index < unique.length && output.length < requested; index += 1) {
      const fact = unique[index];
      const useCloze = type === 'cloze' || (type === 'mix' && index % 4 === 3 && fact.source.length <= 110);
      const cloze = useCloze ? toCloze(fact) : null;
      if (cloze) {
        output.push(cloze);
      } else {
        let question = fact.question;
        if (difficulty === 'easy') question = question.replace(/は、?/, 'は、');
        output.push(`${question}｜${fact.answer}`);
      }
    }

    return output;
  }

  globalThis.ToruTangoGeneratorV2 = { generateQuestionsV2, splitSentencesV2, extractFacts };

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
        const text = source.value.trim();
        status.classList.remove('hidden');
        if (text.length < 30) {
          status.textContent = '教材本文を30文字以上入力してください。';
          return;
        }
        const questions = generateQuestionsV2(
          text,
          Number(questionCount?.value || 10),
          questionType?.value || 'mix',
          difficulty?.value || 'normal'
        );
        if (!questions.length) {
          status.textContent = '意味のある問題を作れませんでした。主語・年代・場所・出来事が分かる文章を追加してください。';
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
          ? `品質を優先し、作成可能な${questions.length}問だけを生成しました。`
          : `${questions.length}問を作成しました。内容を確認してから追加してください。`;
      };
    }
  }
})();