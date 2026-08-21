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

// Individually reviewed items whose old distractors still exposed the answer
// by wording or length. Keep the verified answer text and replace all four
// distractors with same-domain competing statements.
const reviewedDistractors={
  L096:[
    '完成検査後は、設備基準への適合維持義務はなくなる',
    '消火設備だけを技術基準に適合させれば足りる',
    '危険物取扱者が選任されていれば設備維持は不要である',
    '定期点検対象施設だけが位置・構造・設備を維持すればよい'
  ],
  L113:[
    '運転免許を持つ運転者がいれば危険物取扱者は不要である',
    '危険物取扱者は別車両で随行すれば乗車しなくてよい',
    '消防設備士が乗車すれば危険物取扱者でなくてもよい',
    '指定数量未満に分割すれば危険物取扱者の乗車は不要である'
  ],
  L141:[
    '危険物は液体そのものが燃え、蒸気の発生は重要でない',
    '第四類の蒸気は一般に空気より軽く、高所にだけ滞留する',
    '危険物火災では可燃物を除去しても延焼防止にはつながらない',
    '危険物の種類にかかわらず棒状注水が最も適した消火方法である'
  ],
  S099:[
    'アセトンは非水溶性、ガソリンは水溶性である',
    'アセトンもガソリンも水溶性の第一石油類である',
    'アセトンもガソリンも非水溶性の第一石油類である',
    'アセトンはアルコール類、ガソリンは第一石油類である'
  ],
  S103:[
    '重油0.5倍、エチレングリコール1倍',
    '重油1倍、エチレングリコール1倍',
    '重油2倍、エチレングリコール0.5倍',
    '重油0.5倍、エチレングリコール0.5倍'
  ],
  S106:[
    '蒸気は上方だけに集まるので、床面より上だけ換気する',
    '蒸気を封じ込めるため、ピットを密閉して自然消散を待つ',
    '換気を優先し、防爆性を確認していない送風機を近くで使う',
    '蒸気濃度を下げるため、水で排水溝へ洗い流してから換気する'
  ],
  S107:[
    '流速を上げて移替え時間を短くし、帯電時間を減らす',
    '絶縁性の高い容器を用い、接地しないことで電流を遮断する',
    '液面へ落下させて注入し、容器との接触面を小さくする',
    '移替え前にボンディングを外し、設備間を電気的に分離する'
  ],
  S108:[
    '水による冷却効果が優先するため、液面を強くかき混ぜるほどよい',
    '非水溶性危険物は水より重いので、注水すると必ず底部へ沈む',
    '棒状注水で蒸気濃度を下げれば、燃焼液の移動は問題にならない',
    '水と混ざらないため、強い棒状注水でも燃焼面積は変化しない'
  ],
  S113:[
    '霧状化すると液体の密度が大きくなり、着火温度が下がるため',
    '霧状化すると沸点が急上昇し、高温部分に長く残るため',
    '霧状化すると引火点そのものが必ず0℃まで低下するため',
    '霧状化すると液体が水溶性へ変化し、燃焼範囲が広がるため'
  ],
  S114:[
    '漏えいを続けたまま、高温配管だけを直接冷却して様子を見る',
    '換気を優先し、漏えい源を止める前に周囲の機器を再起動する',
    '高温面の近くで吸着材へ回収し、十分たまってから搬出する',
    '発火点を現場測定できるまで、漏えい源への操作を見合わせる'
  ],
  S115:[
    '蒸発潜熱が布の内部に蓄積し、温度が上昇するため',
    '布中の水分が分解して水素を生じ、自然発火するため',
    '布同士の摩擦だけで連続的に発熱し、着火温度へ達するため',
    '積み重ねると引火点が自動的に低下し、常温で必ず発火するため'
  ],
  S116:[
    '大量の水で希釈しながら排水溝へ流し、流出量を減らす',
    '棒状注水で危険物を排水溝方向へ押し、床面から早く除去する',
    '排水溝を開放して蒸気を逃がし、液体の流入はそのままにする',
    '洗剤で乳化して排水へ流し、吸着材の使用量を少なくする'
  ],
  S117:[
    '測定値から漏えいした危険物の引火点を直接求めるため',
    '測定値から施設内の指定数量倍数を算定するため',
    '酸素濃度だけで着火の有無を判定できることを確認するため',
    '蒸気濃度から液体の比重と水溶性を同時に判定するため'
  ],
  S118:[
    '換気量を優先し、防爆仕様でない電動送風機を近くに置く',
    '操作しやすいよう、スイッチ類を可燃性蒸気の滞留部に置く',
    '送風中は静電気が逃げるため、接地やボンディングを外す',
    '排気口を火気使用場所の近くへ向け、蒸気を早く屋外へ出す'
  ],
  S119:[
    '第四類なら水溶性に関係なく、すべて棒状注水を第一選択とする',
    '第四類なら品名に関係なく、すべて普通泡消火剤を使用する',
    '引火点だけで消火剤を決め、火災規模や設備条件は考慮しない',
    '指定数量倍数だけで消火剤を決め、危険物の性状は考慮しない'
  ],
  S120:[
    '所有者の到着を待ち、それまでは流出拡大防止の措置を行わない',
    '原因究明と清掃を完了してから、消防機関へ事故内容を報告する',
    '操業を維持するため移送を続け、危険が拡大した時点で停止する',
    '現場の応急措置は行わず、消防機関の到着後にすべて任せる'
  ]
};
for(const q of Q){
  const wrongs=reviewedDistractors[q.id];
  if(!wrongs)continue;
  const correct=answer(q);
  if(!rotate(q,correct,wrongs))throw new Error(`${q.id}: reviewed distractors could not be applied`);
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
  rules:['no generic clone variants','no >=2 absurd distractors','peer-concept distractors','reviewed answer-cue outliers','difficulty 2/3 calibrated by reasoning type']
};
fs.writeFileSync(bankPath, JSON.stringify(bank,null,2)+'\n');
console.log(JSON.stringify({ok:true,total:Q.length,difficulty:Object.fromEntries([...new Set(Q.map(q=>q.difficulty))].sort().map(d=>[d,Q.filter(q=>q.difficulty===d).length]))},null,2));
