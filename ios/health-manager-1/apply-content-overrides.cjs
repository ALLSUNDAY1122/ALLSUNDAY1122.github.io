'use strict';
const fs = require('fs');
const path = require('path');
const EXPECTED_IDS = [3,11,12,17,18,29,43,1,2,4,5,6,7,8,9,10,13,14,15,16,19,20,21,22,23,24,25,26,27,28,30,31,32,33,34,35,36].map(n=>'practice-B-Q'+String(n).padStart(2,'0'));
function applyContentOverrides(questions, entries = JSON.parse(fs.readFileSync(path.join(__dirname, 'content-overrides-b-20261110.json'), 'utf8'))) {
  if (!Array.isArray(questions) || !Array.isArray(entries)) throw new Error('Invalid override inputs');
  if (entries.length !== EXPECTED_IDS.length || new Set(entries.map(e=>e.id)).size !== EXPECTED_IDS.length ||
      EXPECTED_IDS.some(id=>!entries.some(e=>e.id===id))) throw new Error('Override target set mismatch');
  const staged = entries.map(e=>{
    const matches = questions.filter(q=>q.id===e.id);
    if (matches.length !== 1) throw new Error('Override target missing or duplicated: '+e.id);
    const q = matches[0], r = e.replacement;
    if (q.round !== 'practice-B' || q.conceptKey !== e.expectedConceptKey || q.stem !== e.expectedStem)
      throw new Error('Override source drift: '+e.id);
    if (!r || typeof r.stem !== 'string' || !r.stem.trim() || !Array.isArray(r.choices) ||
        r.choices.length !== 5 || r.choices.some(c=>typeof c!=='string'||!c.trim()) ||
        new Set(r.choices).size !== 5 || !Number.isInteger(r.ans) || r.ans<0 || r.ans>4 ||
        ['short','key','detail','conceptKey','sourceRef','auditSourceURL','independenceReason'].some(k=>typeof r[k]!=='string'||!r[k].trim()))
      throw new Error('Invalid override data: '+e.id);
    for (const k of ['id','round','roundTitle','period','label','officialTopicQuestionNo']) {
      if (Object.hasOwn(r,k)) throw new Error('Override identity mutation: '+e.id);
    }
    return [q, JSON.parse(JSON.stringify(r))];
  });
  // Validate every entry before mutating any row: source drift cannot leave a partially applied batch.
  for (const [q,r] of staged) Object.assign(q,r);
  return staged.map(([q])=>q.id);
}
module.exports = { applyContentOverrides };
