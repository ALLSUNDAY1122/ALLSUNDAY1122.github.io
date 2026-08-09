import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const appRoot=path.resolve(here,'..');
const outDir=path.join(appRoot,'audit','user-report');
fs.mkdirSync(outDir,{recursive:true});
const base=(process.env.BASE_URL||'http://127.0.0.1:4173/cpa-short-answer-sprint/').replace(/\?$/,'');
const browser=await chromium.launch({headless:true});
const ids=[
  'CPA-R8-I-企業法-020','CPA-R8-I-管理会計論-018','CPA-R8-I-監査論-020','CPA-R8-I-財務会計論-035',
  'CPA-R8-II-企業法-020','CPA-R8-II-管理会計論-018','CPA-R8-II-監査論-020','CPA-R8-II-財務会計論-035',
  'CPA-R8-I-財務会計論-019','CPA-R8-I-財務会計論-020','CPA-R8-II-財務会計論-020'
];
const exact={
  'CPA-R8-I-企業法-020':{choice6:'ウエ',correct:'ウエ',wrongClick:null},
  'CPA-R8-II-企業法-020':{choice6:'ウエ',correct:'アウ',wrongClick:5},
  'CPA-R8-I-財務会計論-019':{correct:'ア：〇　イ：×　ウ：〇'},
  'CPA-R8-I-財務会計論-020':{correct:'① 622, 300 円／② 623, 252 円'},
  'CPA-R8-II-財務会計論-020':{correct:'① 71, 731 千円／② 23, 210 千円'}
};
const results=[];
let failed=false;

for(const id of ids){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript(({id})=>{
    const state={
      schemaVersion:1,weak:{},seenIds:{},sessionCompletions:{},answerLog:[],
      stats:{totalAnswered:0,totalCorrect:0,totalPoints:0,earnedPoints:0,history:[]},
      settings:{fontSize:'normal',dailyGoal:8,examDate:''},
      inProgress:{key:'reported',title:'表示監査',mode:'practice',ids:[id],index:0,answers:{},correct:0,score:0,maxScore:6,startedAt:Date.now(),judged:false,selected:null}
    };
    localStorage.setItem('manabiSprint.cpaShortAnswer.v010',JSON.stringify(state));
  },{id});
  const page=await context.newPage();
  try{
    await page.goto(base,{waitUntil:'networkidle',timeout:30000});
    await page.waitForFunction(()=>window.__CPA_READY__===true,{timeout:30000});
    const q=await page.evaluate(id=>{
      const x=window.__CPA_AUDIT__.OCC.find(v=>v.id===id);
      return x?{id:x.id,choices:x.choices,correct_index:x.correct_index,question:x.question}:null;
    },id);
    if(!q)throw new Error(`${id}: normalized question missing`);
    if(!Array.isArray(q.choices)||q.choices.length!==6)throw new Error(`${id}: choices=${q.choices?.length}`);
    if(q.choices.some(x=>!String(x).trim()))throw new Error(`${id}: empty choice`);
    if(new Set(q.choices).size!==q.choices.length)throw new Error(`${id}: duplicate choice`);
    if(q.choices.some(x=>/M\d+[―—−-]\d+/.test(x)))throw new Error(`${id}: PDF footer remains`);
    if(exact[id]?.choice6&&q.choices[5]!==exact[id].choice6)throw new Error(`${id}: choice6=${q.choices[5]}`);
    if(exact[id]?.correct&&q.choices[q.correct_index]!==exact[id].correct)throw new Error(`${id}: normalized correct=${q.choices[q.correct_index]}`);

    await page.locator('[data-resume]').click();
    await page.locator('.question-card').waitFor({state:'visible'});
    const qtext=await page.locator('.qtext').innerText();
    const labels=['ア．','イ．','ウ．','エ．'].filter(x=>qtext.includes(x));
    if(labels.length>=2){
      for(const label of labels){
        if(!qtext.includes(`\n\n${label}`))throw new Error(`${id}: statement spacing missing ${label}`);
      }
    }

    const clickIndex=exact[id]?.wrongClick??q.correct_index;
    await page.locator(`[data-choice="${clickIndex}"]`).click();
    const judge=(await page.locator('.judge-text').innerText()).trim();
    const expectedJudge=clickIndex===q.correct_index?'正解':'不正解';
    if(judge!==expectedJudge)throw new Error(`${id}: judge=${judge}`);
    const correct=(await page.locator('.choice.correct b').innerText()).trim();
    if(correct!==q.choices[q.correct_index])throw new Error(`${id}: correct display=${correct}`);
    const body=await page.locator('body').innerText();
    if(/M\d+[―—−-]\d+/.test(body))throw new Error(`${id}: footer artifact visible after answer`);

    const file=path.join(outDir,`${id}.png`);
    await page.screenshot({path:file,fullPage:true});
    results.push({id,status:'PASS',choices:q.choices,correct_index:q.correct_index,correct,judge,file:path.relative(appRoot,file)});
    console.log(`PASS ${id}: correct=${q.correct_index+1} ${correct} / judge=${judge}`);
  }catch(e){
    failed=true;
    results.push({id,status:'FAIL',error:String(e)});
    console.error(`FAIL ${id}:`,e);
  }finally{
    await context.close();
  }
}
await browser.close();
const summary={audit:'CPA 11-question display/data-corruption browser regression',status:failed?'FAIL':'PASS',count:results.length,results};
fs.writeFileSync(path.join(appRoot,'audit','user-report-audit-result.json'),JSON.stringify(summary,null,2));
if(failed)process.exit(1);
console.log(JSON.stringify({status:'PASS',questions:results.length},null,2));
