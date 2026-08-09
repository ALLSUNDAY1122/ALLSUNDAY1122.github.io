import fs from 'node:fs';
import vm from 'node:vm';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const manifest=JSON.parse(fs.readFileSync(path.join(here,'product-content/manifest.json'),'utf8'));
const errors=[];
const majors=new Set(['人体の構造と機能','疾病の成り立ちと回復の促進','健康支援と社会保障制度','基礎看護学','地域・在宅看護論','成人看護学','老年看護学','小児看護学','母性看護学','精神看護学','看護の統合と実践']);
const placeholder=/髪型|好きな色|好物|靴のサイズ|誕生月|爪の長さ|髪の長さ|テレビ番組|身長の推移|明らかに誤り|ダミー|仮問題/;

if(manifest.targetQuestions!==720)errors.push('manifest targetQuestions must be 720');
if(manifest.setCount!==3||manifest.questionsPerSet!==240)errors.push('manifest must be 3 sets x 240');
const c=manifest.compositionPerSet||{};
if(c['必修']!==50||c['一般']!==130||c['状況設定']!==60)errors.push('composition per set must be 50/130/60');
if(!Array.isArray(manifest.sets)||manifest.sets.length!==3)errors.push('manifest must define 3 sets');

const all=[];
for(const set of manifest.sets||[]){
 const file=path.join(here,'product-content',set.file);
 if(set.status==='not_started'){
   if(set.questionCount!==0)errors.push(`${set.id}: not_started count must be 0`);
   continue;
 }
 if(!fs.existsSync(file)){errors.push(`${set.id}: file missing ${set.file}`);continue;}
 const context={window:{}};vm.createContext(context);
 vm.runInContext(fs.readFileSync(file,'utf8'),context,{filename:set.file});
 const questions=context.window.KANGOSHI_PRODUCT_QUESTIONS||[];
 if(questions.length!==set.questionCount)errors.push(`${set.id}: manifest count ${set.questionCount}, file ${questions.length}`);
 if(set.status==='ready'&&questions.length!==240)errors.push(`${set.id}: ready set must contain 240 questions`);
 const byCat=Object.fromEntries(['必修','一般','状況設定'].map(k=>[k,questions.filter(q=>q.category===k).length]));
 if(set.status==='ready'&&(byCat['必修']!==50||byCat['一般']!==130||byCat['状況設定']!==60))errors.push(`${set.id}: ready composition must be 50/130/60, got ${JSON.stringify(byCat)}`);
 for(const q of questions){all.push({...q,_set:set.id});}
}

const ids=new Set(),stems=new Map();
for(const q of all){
 if(!q.id||ids.has(q.id))errors.push(`duplicate/missing id: ${q.id}`);ids.add(q.id);
 const stem=String(q.question||'').replace(/\s+/g,'').replace(/[。、・,.!?！？「」『』（）()]/g,'');
 if(!stem)errors.push(`missing stem: ${q.id}`);
 if(stems.has(stem))errors.push(`duplicate stem: ${q.id} == ${stems.get(stem)}`);else stems.set(stem,q.id);
 if(!majors.has(q.majorSubject))errors.push(`invalid majorSubject: ${q.id}`);
 if(!q.subject)errors.push(`missing subject: ${q.id}`);
 if(!q.point||!q.reason||!q.detail)errors.push(`explanation incomplete: ${q.id}`);
 if(!q.rightsStatus)errors.push(`rightsStatus missing: ${q.id}`);
 if(!Array.isArray(q.sourceRefs)||q.sourceRefs.length===0)errors.push(`sourceRefs missing: ${q.id}`);
 if(q.reviewStatus!=='expert_reviewed'&&q.releaseReady===true)errors.push(`releaseReady requires expert_reviewed: ${q.id}`);
 if(q.category==='状況設定'&&(!q.scenarioId||!q.scenario||!Number.isInteger(q.scenarioIndex)))errors.push(`scenario metadata missing: ${q.id}`);
 if(Array.isArray(q.choices)&&q.choices.some(x=>placeholder.test(String(x))))errors.push(`placeholder distractor: ${q.id}`);
}

// Basic near-duplicate guard: same first 28 normalized chars are suspicious across independent questions.
const prefixMap=new Map();
for(const q of all){
 const norm=String(q.question||'').replace(/\s+/g,'').replace(/[0-9０-９]/g,'#').replace(/[。、・,.!?！？「」『』（）()]/g,'');
 const prefix=norm.slice(0,28);
 if(prefix.length<16)continue;
 const prior=prefixMap.get(prefix);
 if(prior&&prior!==q.id)errors.push(`near-duplicate stem prefix: ${q.id} ~ ${prior}`);else prefixMap.set(prefix,q.id);
}

if(all.length===720){
 const ready=(manifest.sets||[]).every(s=>s.status==='ready');
 if(!ready)errors.push('720 questions present but not all sets marked ready');
}
if(errors.length){console.error(errors.join('\n'));process.exit(1)}
console.log(`OK: product manifest ${manifest.setCount}x${manifest.questionsPerSet}; loaded ${all.length}/${manifest.targetQuestions}; no duplicate violations in loaded sets`);
