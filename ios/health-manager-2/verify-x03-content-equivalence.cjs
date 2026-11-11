'use strict';
// Usage: node verify-x03-content-equivalence.cjs <baseline-snapshot.json> <regenerated.json> [--promote]
// Save the baseline snapshot BEFORE running the exporter, which overwrites release-questions.json.
const fs=require('fs'),path=require('path');
const [baselineFile,generatedFile,flag]=process.argv.slice(2);
if(!baselineFile||!generatedFile||!['',undefined,'--promote'].includes(flag)){
  console.error('Usage: node verify-x03-content-equivalence.cjs baseline.json regenerated.json [--promote]');
  process.exit(2);
}
const old=JSON.parse(fs.readFileSync(baselineFile,'utf8'));
const fresh=JSON.parse(fs.readFileSync(generatedFile,'utf8'));
function index(rows,label){
  if(!Array.isArray(rows)||rows.length!==300)throw Error(label+': expected exactly 300 records');
  const m=new Map();for(const q of rows){if(!q.id||m.has(q.id))throw Error(label+': missing/duplicate ID '+q.id);m.set(q.id,q);}return m;
}
const left=index(old,'baseline'),right=index(fresh,'regenerated');
const differences=[], answerPositionOnly=[], positionExplanations=[];
function multiset(xs){return xs.slice().sort((a,b)=>a.localeCompare(b,'ja'));}
for(const id of [...new Set([...left.keys(),...right.keys()])].sort()){
  const a=left.get(id),b=right.get(id),fields=[];
  if(!a||!b){differences.push({id,fields:['missing record']});continue;}
  for(const k of ['question','explanation'])if(a[k]!==b[k])fields.push(k);
  for(const [q,side] of [[a,'baseline'],[b,'regenerated']]){
    if(!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.correct_index)
      ||q.correct_index<0||q.correct_index>=5||new Set(q.choices).size!==5)
      fields.push(side+' invalid choices/correct_index');
  }
  if(fields.some(x=>x.includes('invalid'))){differences.push({id,fields});continue;}
  if(JSON.stringify(multiset(a.choices))!==JSON.stringify(multiset(b.choices)))fields.push('choice multiset');
  if(a.choices[a.correct_index]!==b.choices[b.correct_index])fields.push('correct choice text');
  const sameOrder=JSON.stringify(a.choices)===JSON.stringify(b.choices);
  if(!sameOrder||a.correct_index!==b.correct_index)
    answerPositionOnly.push({id,baselinePosition:a.correct_index+1,regeneratedPosition:b.correct_index+1,
      orderChanged:!sameOrder,contentEquivalent:fields.length===0});
  // A positional explanation that names the wrong answer slot is a semantic defect, even if texts match.
  for(const [q,side] of [[a,'baseline'],[b,'regenerated']]){
    const m=/^第([1-5])肢(?:が|は|「)/.exec(q.explanation||'');
    if(m&&Number(m[1])!==q.correct_index+1)
      positionExplanations.push({id,side,explanationSays:Number(m[1]),answerPosition:q.correct_index+1});
  }
  if(fields.length)differences.push({id,fields});
}
const summary={baselineCount:left.size,regeneratedCount:right.size,semanticDifferences:differences,
  orderOrPositionDifferences:answerPositionOnly,explanationPositionConflicts:positionExplanations,
  equivalent:differences.length===0&&positionExplanations.length===0};
console.log(JSON.stringify(summary,null,2));
if(!summary.equivalent)process.exitCode=1;
else if(flag==='--promote'){
  const dest=path.join(__dirname,'release-questions.json');
  fs.writeFileSync(dest,JSON.stringify(fresh,null,2)+'\n');
  console.log('PASS: semantic equivalence confirmed; regenerated JSON promoted to '+dest);
}
