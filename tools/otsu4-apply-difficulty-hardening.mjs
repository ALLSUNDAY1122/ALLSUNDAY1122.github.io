import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const bankPath = path.join(repo, 'kikenbutsu-otsu4-sprint', 'questions.generated.json');
const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
const Q = bank.questions;

const badRe=/(?:酸素になる|質量が0になる|必ず0(?:になる)?|燃料を(?:追加|増や)す|酸素を(?:追加|増や)す|温度を上げる|圧力だけ上げる|一切問題にならない|火災に関係しない|確認する必要はない|全く同じ挙動|会社規程だけ|任意基準だけ|手続不要|許可不要|警察への口頭連絡だけ|税務署への申告|道路ならどこでもよい|工場敷地ならどこでもよい|無許可倉庫)/;
const cloneRe=/^(?:本番で同じ知識を使う場面を想定する。|条件を取り違えないように判断する。|基本事項を応用して答える。|誤りやすい選択肢に注意して答える。)/;
const uniq=a=>[...new Set(a.filter(Boolean))];
const answer=q=>q.choices[q.answer];
const rotate=(q,correct,wrongs)=>{
  const pool=uniq([correct,...wrongs.filter(x=>x!==correct)]).slice(0,5);
  if(pool.length!==5)return false;
  const shift=(Number(q.id.slice(1))*3)%5;
  q.choices=pool.slice(shift).concat(pool.slice(0,shift));
  q.answer=q.choices.indexOf(correct);
  return true;
};

for(const q of Q){
  if(cloneRe.test(q.question))throw new Error(`${q.id}: generic difficulty clone is forbidden`);
}

const physicsGroups=[
  ['引火点','発火点','沸点','蒸気圧','揮発性','減圧沸騰'],
  ['蒸気比重','液比重','水密度','密度','比重'],
  ['燃焼三要素','完全燃焼','不完全燃焼','酸化','発熱反応','吸熱反応'],
  ['冷却消火','窒息消火','除去消火','抑制消火','泡消火','二酸化炭素消火','粉末消火'],
  ['熱伝導','対流','放射','蒸発潜熱','比熱','表面積'],
  ['静電気','接地','燃焼下限','燃焼上限','シャルル法則','定積圧力']
];
const phyByTopic=new Map(Q.filter(q=>q.subject==='物理・化学').map(q=>[q.topic,q]));
for(const topics of physicsGroups){
  const members=topics.map(t=>phyByTopic.get(t)).filter(Boolean);
  const pool=uniq(members.map(answer));
  for(const q of members){
    const correct=answer(q);
    const start=Number(q.id.slice(1))%Math.max(1,pool.length);
    const ordered=pool.slice(start).concat(pool.slice(0,start));
    const wrongs=ordered.filter(x=>x!==correct).slice(0,4);
    if(wrongs.length===4)rotate(q,correct,wrongs);
  }
}

for(const topic of ['水溶性','性質・火災予防']){
  const members=Q.filter(q=>q.subject==='性質・消火'&&q.topic===topic);
  const pool=uniq(members.map(answer));
  for(const q of members){
    const correct=answer(q);
    const start=Number(q.id.slice(1))%Math.max(1,pool.length);
    const ordered=pool.slice(start).concat(pool.slice(0,start));
    const wrongs=ordered.filter(x=>x!==correct).slice(0,4);
    if(wrongs.length===4)rotate(q,correct,wrongs);
  }
}

const lawFallback={
  authority:['市町村長等','その市町村長','都道府県知事','所轄消防長または消防署長','総務大臣'],
  procedure:['市町村長等の許可','所轄消防長または消防署長の承認','市町村長等への届出','完成検査を受ける','危険物保安監督者を選任する'],
  source:['消防法','政令','規則','市町村条例','消防庁告示']
};
const lawFamily=q=>{
  const a=answer(q);
  if(/(?:市町村長|消防長|消防署長|知事|大臣)/.test(a))return 'authority';
  if(/(?:許可|承認|届出|検査|選任)/.test(a))return 'procedure';
  if(/^(?:消防法|政令|規則|市町村条例|消防庁告示)$/.test(a))return 'source';
  return null;
};
const law=Q.filter(q=>q.subject==='法令');
for(const q of law){
  const currentWrong=q.choices.filter((_,i)=>i!==q.answer);
  if(currentWrong.filter(x=>badRe.test(String(x))).length===0)continue;
  const fam=lawFamily(q);
  if(!fam)continue;
  const correct=answer(q);
  const candidates=uniq([
    ...law.filter(x=>x.id!==q.id&&lawFamily(x)===fam).map(answer),
    ...(lawFallback[fam]||[])
  ]).filter(x=>x!==correct);
  const kept=currentWrong.filter(x=>!badRe.test(String(x)));
  const replacements=candidates.filter(x=>!kept.includes(x)).slice(0,4-kept.length);
  rotate(q,correct,[...kept,...replacements]);
}

// Last-resort replacement uses real correct answers from the same subject,
// preferring the same topic. It changes distractors only; the verified correct
// answer and explanation remain untouched.
for(const q of Q){
  const correct=answer(q);
  const wrongs=q.choices.filter((_,i)=>i!==q.answer);
  const badCount=wrongs.filter(x=>badRe.test(String(x))).length;
  if(badCount<2)continue;
  const sameTopic=Q.filter(x=>x.id!==q.id&&x.subject===q.subject&&x.topic===q.topic).map(answer);
  const sameSubject=Q.filter(x=>x.id!==q.id&&x.subject===q.subject).map(answer);
  const candidates=uniq([...sameTopic,...sameSubject]).filter(x=>x!==correct&&!badRe.test(String(x)));
  const kept=wrongs.filter(x=>!badRe.test(String(x)));
  const replacements=candidates.filter(x=>!kept.includes(x)).slice(0,4-kept.length);
  if(!rotate(q,correct,[...kept,...replacements])){
    throw new Error(`${q.id}: could not build five plausible choices`);
  }
}

for(const q of Q){
  if(q.subject==='法令'){
    q.difficulty=/(倍数合算|指定数量判定|組合せ|誤っている|該当しない)/.test(`${q.topic} ${q.question}`)?3:2;
  }else if(q.subject==='物理・化学'){
    q.difficulty=/(計算|燃焼範囲判定)/.test(q.topic)?3:2;
  }else{
    q.difficulty=/(指定数量応用|石油類区分|比較応用|組合せ|誤っている)/.test(`${q.topic} ${q.question}`)?3:2;
  }
}

const residual=[];
for(const q of Q){
  const bad=q.choices.filter((_,i)=>i!==q.answer).filter(x=>badRe.test(String(x)));
  if(bad.length>=2)residual.push(`${q.id}:${bad.join(' / ')}`);
}
if(residual.length)throw new Error(`difficulty hardening incomplete (${residual.length}): ${residual.slice(0,12).join(' | ')}`);

bank.difficultyAudit={
  policy:'2026-08 exam-level v1',
  transformedAtBuildTime:true,
  rules:['no generic clone variants','no >=2 absurd distractors','peer-concept distractors','difficulty 2/3 calibrated by reasoning type']
};
fs.writeFileSync(bankPath, JSON.stringify(bank,null,2)+'\n');
console.log(JSON.stringify({ok:true,total:Q.length,difficulty:Object.fromEntries([...new Set(Q.map(q=>q.difficulty))].sort().map(d=>[d,Q.filter(q=>q.difficulty===d).length]))},null,2));
