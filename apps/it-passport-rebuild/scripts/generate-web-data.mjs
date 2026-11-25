#!/usr/bin/env node
// Generate development-only data; never edit generated JSON.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dirname} from 'node:path';
const root=new URL('../',import.meta.url);
const source=new URL('questions/official-verbatim.json',root);
const output=new URL('generated/questions.json',root);
const raw=readFileSync(source,'utf8');
const bank=JSON.parse(raw);
const fail=m=>{throw new Error(m)};
if(!Array.isArray(bank)||bank.length!==500)fail('Expected 500 questions');
const domains={'ストラテジ系':'strategy','マネジメント系':'management','テクノロジ系':'technology'};
const categories=new Map();
for(let y=2022;y<=2026;y++){
 const entries=Object.entries(JSON.parse(readFileSync(new URL(`questions/categories-${y}.json`,root),'utf8')));
 if(entries.length!==100)fail('Invalid category count '+y);
 for(const [id,v] of entries){
  if(!id.startsWith(`itp-${y}-`)||categories.has(id)||!Object.hasOwn(domains,v.category)||typeof v.subcategory!=='string'||!v.subcategory.trim())fail('Invalid category '+id);
  categories.set(id,v);
 }
}
const explanations=new Map();
for(let y=2022;y<=2026;y++){
 const entries=Object.entries(JSON.parse(readFileSync(new URL(`questions/explanations-${y}.json`,root),'utf8')));
 if(entries.length!==100)fail('Invalid explanation count '+y);
 for(const [id,v] of entries){
  if(!id.startsWith(`itp-${y}-`)||explanations.has(id)||typeof v.short!=='string'||!v.short.trim()||typeof v.detail!=='string'||!v.detail.trim())fail('Invalid explanation '+id);
  explanations.set(id,v);
 }
}
const ids=new Set(),content=new Set();
const normalize=s=>s.replace(/\s/g,'');
const questions=bank.map(q=>{
 if(!Number.isInteger(q.year)||q.year<2022||q.year>2026||!Number.isInteger(q.question_number)||q.question_number<1||q.question_number>100||q.id!==`itp-${q.year}-q${String(q.question_number).padStart(3,'0')}`)fail('Invalid identity '+q.id);
 if(ids.has(q.id))fail('Duplicate ID '+q.id);ids.add(q.id);
 if(typeof q.question!=='string'||!q.question.trim()||!Array.isArray(q.choices)||q.choices.length!==4||q.choices.some(c=>typeof c!=='string'||!c.trim())||!Number.isInteger(q.correct_index)||'アイウエ'[q.correct_index]!==q.correct_label)fail('Invalid question '+q.id);
 const key=JSON.stringify([normalize(q.question),q.choices.map(normalize)]);if(content.has(key))fail('Duplicate content '+q.id);content.add(key);
 if(!q.source_label||!q.source_url||typeof q.modified!=='boolean'||(q.modified&&!q.modification_note))fail('Missing attribution '+q.id);
 const classification=categories.get(q.id);if(!classification)fail('Missing category '+q.id);
 const explanation=explanations.get(q.id);if(!explanation)fail('Missing explanation '+q.id);
 return {id:q.id,year:q.year,question_number:q.question_number,question:q.question,choices:q.choices,correct_index:q.correct_index,correct_label:q.correct_label,source_label:q.source_label,source_url:q.source_url,modified:q.modified,modification_note:q.modification_note,representation_format:q.representation_format??null,representation_changed:q.representation_changed??false,ruby_annotations:q.ruby_annotations??null,presentation_note:q.presentation_note??null,domain:domains[classification.category],category:classification.category,subcategory:classification.subcategory,short:explanation.short,detail:explanation.detail,publishable:q.publishable===true,release_eligible:q.release_eligible===true};
}).sort((a,b)=>a.year-b.year||a.question_number-b.question_number);
for(let y=2022;y<=2026;y++)if(questions.filter(q=>q.year===y).length!==100)fail('Invalid year '+y);
const data={schema_version:1,source:'questions/official-verbatim.json',source_sha256:createHash('sha256').update(raw).digest('hex'),questions};
const serialized=JSON.stringify(data,null,2)+'\n';
if(process.argv.includes('--check')){if(readFileSync(output,'utf8')!==serialized)fail('Generated data stale');}
else{mkdirSync(dirname(fileURLToPath(output)),{recursive:true});writeFileSync(output,serialized);}
console.log(JSON.stringify({count:questions.length,duplicate_ids:questions.length-ids.size,duplicate_content:questions.length-content.size,unclassified:questions.filter(q=>!q.domain).length,explained:questions.filter(q=>q.short&&q.detail).length,category_counts:Object.fromEntries(Object.keys(domains).map(c=>[c,questions.filter(q=>q.category===c).length])),release_eligible:questions.filter(q=>q.release_eligible).length}));
