'use strict';
// Pin current, actually served question IDs rather than legacy topic/basis labels.
// A passing structural/wording regression is not independent verification of law.
const assert=require('node:assert/strict');
const PINS=[
  ['sm2-5y-r06-law-10','3か月以内','健康診断後の医師等の意見聴取'],
  ['sm2-5y-r07-law-07','14日以内','産業医の選任期限'],
  ['sm2-r7o-002','毎週1回','衛生管理者の定期巡視'],
  ['sm2-demo-006','3年間','衛生委員会議事記録の保存（代表問）'],
  ['sm2-5y-r07-law-01','調査審議','産業医による衛生委員会への審議要求'],
  ['sm2-r7a-012','WBGT28','熱中症対策の暑熱基準'],
  ['sm2-r7a-012','気温31','熱中症対策の気温基準'],
  ['sm2-r7a-012','継続1時間','熱中症対策の継続作業'],
  ['sm2-r7a-012','1日4時間','熱中症対策の通算作業'],
  ['sm2-5y-r08-law-06','月45時間','36協定の月上限'],
  ['sm2-5y-r10-law-06','40','事務室の相対湿度の下限'],
  ['sm2-5y-r10-law-06','70','事務室の相対湿度の上限'],
  ['sm2-5y-r10-law-08','5年間','一般健康診断個人票の保存'],
  ['sm2-5y-r10-law-09','45分','8時間労働の休憩'],
  ['sm2-5y-r09-law-03','1人以上','120人事業場の衛生管理者選任数'],
  ['sm2-5y-r10-law-03','35％','法定休日の割増率'],
  ['sm2-5y-r05-law-10','2026年8月1日','産業医辞任等の改正施行日']
];
// The old list belongs to a different question bank state. Retain it for
// traceability and to avoid silently treating displaced rules as verified.
const LEGACY_TOPICS=[
 '健康診断後の医師等の意見聴取','自発的健康診断後の意見聴取',
 '産業医の辞任等の報告','衛生管理者の選任期限','衛生管理者の定期巡視',
 '衛生委員会の開催頻度','衛生委員会記録の保存','暑熱な場所の基準',
 '熱中症対策の対象作業','法定労働時間（日）','法定労働時間（週）',
 '6時間超の休憩','8時間超の休憩','時間外労働の原則月上限',
 '時間外労働の原則年上限','特別条項の年上限','特別条項の単月上限',
 '特別条項の複数月平均','空調時の室温','空調時の相対湿度',
 '事務室の気流','供給空気の二酸化炭素','供給空気の一酸化炭素',
 '一般的な事務作業の照度'
];
function verifyCurrentLawContent(questions){
 assert.equal(questions.length,300,'expected canonical 300');
 const byId=new Map(questions.map(q=>[q.id,q]));
 assert.equal(byId.size,300,'duplicate IDs');
 for(const [id,needle,law] of PINS){
  const q=byId.get(id);assert.ok(q,law+': missing '+id);
  const text=[q.question,q.quick,q.explanation,q.choices[q.answer-1]].join(' ');
  assert.ok(text.includes(needle),law+': current ID '+id+' missing '+needle);
  assert.ok(/^https:\/\//.test(q.sourceUrl),id+': missing source URL');
  assert.ok(q.lawRelated && q.legalChecked,id+': missing law provenance metadata');
 }
 const topicMap=new Map(questions.filter(q=>LEGACY_TOPICS.includes(q.topic)).map(q=>[q.topic,q]));
 // Legacy topic labels are historical and may no longer describe their questions.
 const stale=LEGACY_TOPICS.filter(t=>{
  const q=topicMap.get(t);if(!q)return true;
  const present=[q.question,q.quick,q.explanation].join(' ');
  return !present.includes(t.slice(0,5));
 });
 const awaiting=questions.filter(q=>q.contentReviewStatus==='requires-independent-subject-expert-review'
  ||q.contentReviewStatus==='requires-independent-specialist-review'
  ||q.contentReviewStatus==='requires-independent-legal-review');
 console.log('PASS HM2_LIVE_LAW_PINS '+JSON.stringify({assertions:PINS.length,questionIds:new Set(PINS.map(p=>p[0])).size}));
 console.log('REVIEW_REQUIRED HM2_LEGACY_TOPIC_METADATA '+JSON.stringify({originalPins:LEGACY_TOPICS.length,apparentStale:stale.length,examples:stale.slice(0,8),independentReviewMarked:awaiting.length}));
 return {pins:PINS.length,legacyTopics:LEGACY_TOPICS.length,stale,awaiting};
}
module.exports={verifyCurrentLawContent,PINS,LEGACY_TOPICS};
