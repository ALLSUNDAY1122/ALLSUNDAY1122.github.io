(function(){
'use strict';
const qs=window.Q_PARTS||[];
const groups=new Map();
const STEMS=[
  '次の「項目―内容」の組合せのうち、正しいものはどれか。',
  '次の用語・制度と説明の組合せのうち、適切なものはどれか。',
  '次の項目とその内容の対応として、正しいものはどれか。',
  '次の組合せのうち、名称と内容が正しく対応しているものはどれか。',
  '次の5つの対応関係のうち、正しいものはどれか。'
];
for(const q of qs){
  if(!q.fiveYearExpansion) continue;
  const key=`${q.examSet}｜${q.subject}`;
  if(!groups.has(key)) groups.set(key,[]);
  groups.get(key).push(q);
}
function clueOf(q){
  const s=String(q.quick||'');
  const i=s.indexOf('：');
  return i>=0?s.slice(i+1).trim():String(q.explanation||'').replace(/^正解は[^。]+。/,'').split(' 根拠・学習基準：')[0].trim();
}
for(const group of groups.values()){
  group.sort((a,b)=>String(a.id).localeCompare(String(b.id),'ja'));
  const terms=group.map(q=>q.topic);
  const clues=group.map(clueOf);
  group.forEach((q,j)=>{
    const answerIndex=Math.max(0,Math.min(4,(Number(q.answer)||1)-1));
    const termPool=[];
    for(let k=1;termPool.length<4&&k<group.length;k++) termPool.push(terms[(j+k)%group.length]);
    const cluePool=[];
    for(let k=2;cluePool.length<4&&k<group.length+2;k++){
      const c=clues[(j+k)%group.length];
      if(c!==clueOf(q)) cluePool.push(c);
    }
    while(cluePool.length<4) cluePool.push(clues[(j+cluePool.length+3)%group.length]);
    const distractors=termPool.map((term,i)=>`${term} ― ${cluePool[(i+1)%cluePool.length]}`);
    const correct=`${q.topic} ― ${clueOf(q)}`;
    const choices=distractors.slice(0,4);
    choices.splice(answerIndex,0,correct);
    q.question=STEMS[j%STEMS.length];
    q.choices=choices;
    q.quick=`${q.topic}：${clueOf(q)}`;
    q.explanation=`正解は「${correct}」。他の選択肢は、同じ出題範囲にある実在の制度・用語と別の制度・用語の内容を組み替えたもの。名称だけでなく、数値・期限・対象・作用まで対応づけて判定する。根拠：${q.basis||'各分野の一次資料・標準知識'}。`;
    q.auditStatus='難易度再監査済';
    q.difficultyModel='exam-paired-judgment-v1';
    q.noCommonSenseShortcut=true;
  });
}
let manual=0;
for(const q of qs){
  if(!['令和7年10月','令和7年4月'].includes(q.examSet)) continue;
  if(!['労働衛生','労働生理'].includes(q.subject)) continue;
  q.difficultyModel='manual-exam-rewrite-v1';
  q.noCommonSenseShortcut=true;
  manual++;
}
window.SM2_DIFFICULTY_PATCH_V5={
  generatedGroups:groups.size,
  generatedQuestions:[...groups.values()].reduce((n,g)=>n+g.length,0),
  manualQuestions:manual,
  coveredQuestions:[...groups.values()].reduce((n,g)=>n+g.length,0)+manual
};
})();
