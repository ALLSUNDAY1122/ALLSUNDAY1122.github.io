'use strict';
const fs=require('fs');
const path=require('path');
const vm=require('vm');

const IOS_DIR=__dirname;
const REPO_ROOT=path.resolve(IOS_DIR,'..','..');
const WEB=path.join(REPO_ROOT,'apps','sanitary-manager-2');
const patch=path.join(WEB,'difficulty-patch-v5.js');
if(!fs.existsSync(patch)) throw new Error('Missing difficulty-patch-v5.js');
if(!global.window || !Array.isArray(global.window.Q_PARTS)) throw new Error('Question corpus is not initialized');
vm.runInThisContext(fs.readFileSync(patch,'utf8'),{filename:patch});

const qs=global.window.Q_PARTS;
const stat=global.window.SM2_DIFFICULTY_PATCH_V5||{};
if(qs.length!==300) throw new Error(`Difficulty gate expected 300 questions, got ${qs.length}`);
if(stat.generatedQuestions!==210) throw new Error(`Expected 210 generated rewrites, got ${stat.generatedQuestions}`);
if(stat.manualQuestions!==40) throw new Error(`Expected 40 manual rewrites, got ${stat.manualQuestions}`);
if(stat.coveredQuestions!==250) throw new Error(`Expected 250 difficulty-covered questions, got ${stat.coveredQuestions}`);

const covered=qs.filter(q=>q.noCommonSenseShortcut===true && q.difficultyModel);
if(covered.length!==250) throw new Error(`Expected 250 questions with difficulty provenance, got ${covered.length}`);

const generated=qs.filter(q=>q.fiveYearExpansion);
for(const q of generated){
  if(q.difficultyModel!=='exam-paired-judgment-v1') throw new Error(`${q.id}: expansion difficulty model missing`);
  if(!Array.isArray(q.choices)||q.choices.length!==5) throw new Error(`${q.id}: difficulty choices must be 5`);
  if(new Set(q.choices).size!==5) throw new Error(`${q.id}: duplicate choices after difficulty rewrite`);
  if(!q.choices.every(c=>String(c).includes(' ― '))) throw new Error(`${q.id}: paired-judgment choice malformed`);
  const answer=q.choices[q.answer-1];
  if(!answer.startsWith(`${q.topic} ― `)) throw new Error(`${q.id}: correct paired choice no longer matches topic`);
  // Only the keyed answer may pair the canonical topic with its own clue.
  const correctPairs=q.choices.filter(c=>c.startsWith(`${q.topic} ― `));
  if(correctPairs.length!==1) throw new Error(`${q.id}: topic appears in ${correctPairs.length} choices`);
}

const manual=qs.filter(q=>q.difficultyModel==='manual-exam-rewrite-v1');
for(const q of manual){
  if(!Array.isArray(q.choices)||q.choices.length!==5||new Set(q.choices).size!==5) throw new Error(`${q.id}: manual rewrite choices invalid`);
  const lens=q.choices.map(c=>String(c).length);
  const max=Math.max(...lens),min=Math.min(...lens);
  if(max-min>110) throw new Error(`${q.id}: choice-length cue too large after manual rewrite`);
}

// Re-export the post-difficulty corpus so Codemagic validates and ships exactly
// the questions users see in WKWebView, not the pre-patch generator output.
const sets=['令和8年4月','令和7年10月','令和7年4月','5年分相当｜第4回','5年分相当｜第5回','5年分相当｜第6回','5年分相当｜第7回','5年分相当｜第8回','5年分相当｜第9回','5年分相当｜第10回'];
const examRound=Object.fromEntries(sets.map((name,i)=>[name,i+1]));
const out=qs.map(q=>({
  id:q.id,round:examRound[q.examSet],exam_set:q.examSet,subject:q.subject,topic:q.topic,
  question:q.question,choices:q.choices,correct_index:q.answer-1,quick:q.quick,explanation:q.explanation,
  primary_basis:q.basis,source_url:q.sourceUrl,baseline_date:q.baselineDate,origin_type:q.originType,
  rights_basis:q.rightsBasis,law_related:Boolean(q.lawRelated),legal_checked:q.legalChecked||null,
  audit_status:q.auditStatus,publication_status:q.publicationStatus,difficulty_model:q.difficultyModel||null,
  no_common_sense_shortcut:Boolean(q.noCommonSenseShortcut)
}));
fs.writeFileSync(path.join(IOS_DIR,'release-questions.json'),JSON.stringify(out,null,2)+'\n');
console.log(`PASS: HM2 difficulty gate covered ${covered.length}/300 questions (210 paired-judgment + 40 manual exam-level rewrites).`);
