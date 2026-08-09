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
const cases=[
  {id:'CPA-R8-I-企業法-020',expectedCorrect:'ウエ',clickIndex:5,judge:'正解'},
  {id:'CPA-R8-II-企業法-020',expectedCorrect:'アウ',clickIndex:5,judge:'不正解'}
];
const results=[];
let failed=false;

for(const tc of cases){
  const context=await browser.newContext({viewport:{width:390,height:844}});
  await context.addInitScript(({id})=>{
    const state={
      schemaVersion:1,
      weak:{},seenIds:{},sessionCompletions:{},answerLog:[],
      stats:{totalAnswered:0,totalCorrect:0,totalPoints:0,earnedPoints:0,history:[]},
      settings:{fontSize:'normal',dailyGoal:8,examDate:''},
      inProgress:{key:'reported',title:'表示監査',mode:'practice',ids:[id],index:0,answers:{},correct:0,score:0,maxScore:5,startedAt:Date.now(),judged:false,selected:null}
    };
    localStorage.setItem('manabiSprint.cpaShortAnswer.v010',JSON.stringify(state));
  },{id:tc.id});
  const page=await context.newPage();
  try{
    await page.goto(base,{waitUntil:'networkidle',timeout:30000});
    await page.waitForFunction(()=>window.__CPA_READY__===true,{timeout:30000});
    await page.locator('[data-resume]').click();
    await page.locator('.question-card').waitFor({state:'visible'});
    const qtext=await page.locator('.qtext').innerText();
    const choices=await page.locator('.choice b').allInnerTexts();
    if(choices.length!==6)throw new Error(`${tc.id}: choices=${choices.length}`);
    if(choices[5]!=='ウエ')throw new Error(`${tc.id}: choice6=${choices[5]}`);
    if(choices.some(x=>/M\d+[―—−-]\d+/.test(x)))throw new Error(`${tc.id}: PDF footer remains in choices`);
    if(!qtext.includes('\n\nア．')||!qtext.includes('\n\nイ．')||!qtext.includes('\n\nウ．')||!qtext.includes('\n\nエ．')){
      throw new Error(`${tc.id}: statement spacing missing`);
    }
    await page.locator(`[data-choice="${tc.clickIndex}"]`).click();
    const judge=(await page.locator('.judge-text').innerText()).trim();
    if(judge!==tc.judge)throw new Error(`${tc.id}: judge=${judge}`);
    const correct=(await page.locator('.choice.correct b').innerText()).trim();
    if(correct!==tc.expectedCorrect)throw new Error(`${tc.id}: correct=${correct}`);
    const body=await page.locator('body').innerText();
    if(/M4―25M4―26M4―27M4―28/.test(body))throw new Error(`${tc.id}: footer artifact visible after answer`);
    const file=path.join(outDir,`${tc.id}.png`);
    await page.screenshot({path:file,fullPage:true});
    results.push({id:tc.id,status:'PASS',choice6:choices[5],correct,judge,file:path.relative(appRoot,file)});
    console.log(`PASS ${tc.id}: choice6=ウエ / correct=${correct} / judge=${judge}`);
  }catch(e){
    failed=true;
    results.push({id:tc.id,status:'FAIL',error:String(e)});
    console.error(`FAIL ${tc.id}:`,e);
  }finally{
    await context.close();
  }
}
await browser.close();
const summary={audit:'CPA user-reported readability/data-corruption regression',status:failed?'FAIL':'PASS',results};
fs.writeFileSync(path.join(appRoot,'audit','user-report-audit-result.json'),JSON.stringify(summary,null,2));
if(failed)process.exit(1);
console.log(JSON.stringify(summary,null,2));
