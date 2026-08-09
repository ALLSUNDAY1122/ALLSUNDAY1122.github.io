import fs from 'node:fs';
import vm from 'node:vm';
const context={window:{}};vm.createContext(context);
for(const name of ['questions.js','questions-numeric.js','questions-audit-v1.js'])vm.runInContext(fs.readFileSync(new URL(`./${name}`,import.meta.url),'utf8'),context);
const q=context.window.KANGOSHI_QUESTIONS||[], errors=[], ids=new Set(), texts=new Set();
const expected={必修:24,一般:24,状況設定:12};
const majors=new Set(['人体の構造と機能','疾病の成り立ちと回復の促進','健康支援と社会保障制度','基礎看護学','地域・在宅看護論','成人看護学','老年看護学','小児看護学','母性看護学','精神看護学','看護の統合と実践','その他・横断']);
const weakDistractor=/髪型|好きな色|好物|靴のサイズ|誕生月|爪の長さ|髪の長さ|好きなテレビ番組|旅行歴だけ|身長の推移/;
if(q.length!==60)errors.push(`question count expected 60, got ${q.length}`);
for(const [cat,n] of Object.entries(expected)){const got=q.filter(x=>x.category===cat).length;if(got!==n)errors.push(`${cat}: expected ${n}, got ${got}`)}
for(const x of q){
 if(!x.id||ids.has(x.id))errors.push(`duplicate/missing id: ${x.id}`);ids.add(x.id);
 if(!x.question||texts.has(x.question))errors.push(`duplicate/missing question: ${x.id}`);texts.add(x.question);
 if(!x.point||!x.detail)errors.push(`explanation missing: ${x.id}`);
 if(String(x.point).length<18)errors.push(`memory point too short: ${x.id}`);
 if(String(x.detail).length<30)errors.push(`detail too short: ${x.id}`);
 if(x.rightsStatus!=='original-mvp')errors.push(`rightsStatus invalid: ${x.id}`);
 if(!x.sourceStatus)errors.push(`sourceStatus missing: ${x.id}`);
 if(x.auditStatus!=='ai-content-audit-v1')errors.push(`auditStatus missing: ${x.id}`);
 if(x.reviewStatus!=='MVP_AI監査済・専門家最終監査前')errors.push(`reviewStatus invalid: ${x.id}`);
 if(!majors.has(x.majorSubject))errors.push(`majorSubject invalid: ${x.id} ${x.majorSubject}`);
 if(!Number.isFinite(Number(x.difficulty))||Number(x.difficulty)<1||Number(x.difficulty)>3)errors.push(`difficulty invalid: ${x.id}`);
 if(x.answerType==='singleChoice'){
  if(!Array.isArray(x.choices)||x.choices.length!==4)errors.push(`single choices invalid: ${x.id}`);
  if(new Set(x.choices).size!==x.choices.length)errors.push(`duplicate choices: ${x.id}`);
  if((x.choices||[]).some(c=>weakDistractor.test(c)))errors.push(`weak distractor remains: ${x.id}`);
  if(!Number.isInteger(x.answer)||x.answer<0||x.answer>=x.choices.length)errors.push(`single answer invalid: ${x.id}`);
 }else if(x.answerType==='multiChoice'){
  if(!Array.isArray(x.choices)||x.choices.length!==4)errors.push(`multi choices invalid: ${x.id}`);
  if(new Set(x.choices).size!==x.choices.length)errors.push(`duplicate choices: ${x.id}`);
  if((x.choices||[]).some(c=>weakDistractor.test(c)))errors.push(`weak distractor remains: ${x.id}`);
  if(!Array.isArray(x.answer)||x.answer.length!==x.selectCount||new Set(x.answer).size!==x.answer.length)errors.push(`multi answer invalid: ${x.id}`);
  for(const a of x.answer||[])if(!Number.isInteger(a)||a<0||a>=x.choices.length)errors.push(`multi answer range invalid: ${x.id}`);
 }else if(x.answerType==='numeric'){
  if(!Number.isFinite(Number(x.answer)))errors.push(`numeric answer invalid: ${x.id}`);
  if(Number(x.tolerance||0)<0)errors.push(`numeric tolerance invalid: ${x.id}`);
  if(!x.unit)errors.push(`numeric unit missing: ${x.id}`);
 }else errors.push(`answerType invalid: ${x.id}`);
 if(x.category==='状況設定'&&(!x.scenarioId||!x.scenario))errors.push(`scenario missing: ${x.id}`);
}
const types=Object.fromEntries(['singleChoice','multiChoice','numeric'].map(t=>[t,q.filter(x=>x.answerType===t).length]));
if(types.multiChoice<1)errors.push('multiChoice example missing');if(types.numeric<1)errors.push('numeric example missing');
const other=q.filter(x=>x.majorSubject==='その他・横断').map(x=>x.id);
if(other.length)errors.push(`unclassified majorSubject remains: ${other.join(',')}`);
if(errors.length){console.error(errors.join('\n'));process.exit(1)}
console.log(`OK: ${q.length} audited questions / 24-24-12 / types ${JSON.stringify(types)} / no trivial distractors / majorSubject complete`);
