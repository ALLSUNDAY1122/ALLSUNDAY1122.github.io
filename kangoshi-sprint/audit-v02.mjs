import fs from 'node:fs';
import vm from 'node:vm';
const context={window:{}};vm.createContext(context);
for(const name of ['questions.js','questions-numeric.js'])vm.runInContext(fs.readFileSync(new URL(`./${name}`,import.meta.url),'utf8'),context);
const q=context.window.KANGOSHI_QUESTIONS||[], errors=[], ids=new Set(), texts=new Set();
const expected={必修:24,一般:24,状況設定:12};
if(q.length!==60)errors.push(`question count expected 60, got ${q.length}`);
for(const [cat,n] of Object.entries(expected)){const got=q.filter(x=>x.category===cat).length;if(got!==n)errors.push(`${cat}: expected ${n}, got ${got}`)}
for(const x of q){
 if(!x.id||ids.has(x.id))errors.push(`duplicate/missing id: ${x.id}`);ids.add(x.id);
 if(!x.question||texts.has(x.question))errors.push(`duplicate/missing question: ${x.id}`);texts.add(x.question);
 if(!x.point||!x.detail)errors.push(`explanation missing: ${x.id}`);
 if(x.rightsStatus!=='original-mvp')errors.push(`rightsStatus invalid: ${x.id}`);
 if(!x.sourceStatus)errors.push(`sourceStatus missing: ${x.id}`);
 if(x.answerType==='singleChoice'){
  if(!Array.isArray(x.choices)||x.choices.length<2)errors.push(`choices invalid: ${x.id}`);
  if(!Number.isInteger(x.answer)||x.answer<0||x.answer>=x.choices.length)errors.push(`single answer invalid: ${x.id}`);
 }else if(x.answerType==='multiChoice'){
  if(!Array.isArray(x.choices)||x.choices.length<2)errors.push(`choices invalid: ${x.id}`);
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
if(errors.length){console.error(errors.join('\n'));process.exit(1)}
console.log(`OK: ${q.length} questions / category 24-24-12 / types ${JSON.stringify(types)} / schemas and rights flags valid`);
