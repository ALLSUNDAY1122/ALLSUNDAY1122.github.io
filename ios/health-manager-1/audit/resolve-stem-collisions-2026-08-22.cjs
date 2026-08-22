'use strict';
const fs=require('fs');
const path=require('path');
const p=path.join(__dirname,'..','Resources','questions.json');
const qs=JSON.parse(fs.readFileSync(p,'utf8'));
const byId=new Map(qs.map(q=>[q.id,q]));
const q40=byId.get('2025-10-Q40');
if(q40) q40.stem='ABO式血液型を決定する抗原の所在に関する次の記述のうち、正しいものはどれか。';
const clean=s=>String(s||'').normalize('NFKC').replace(/次の記述のうち/g,'').replace(/次のうち/g,'').replace(/法令上/g,'').replace(/正しいものはどれか/g,'').replace(/誤っているものはどれか/g,'').replace(/[\s\p{P}\p{S}]/gu,'').toLowerCase();
const seen=new Map(),dups=[];
for(const q of qs){const k=clean(q.stem);if(seen.has(k))dups.push([seen.get(k),q.id,q.stem]);else seen.set(k,q.id)}
if(dups.length) throw new Error('remaining duplicate hardened stems: '+JSON.stringify(dups));
fs.writeFileSync(p,JSON.stringify(qs,null,2)+'\n');
console.log('PASS: hardened canonical stems are unique.');
