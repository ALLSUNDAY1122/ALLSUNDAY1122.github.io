import { chromium } from 'playwright';

const base=process.env.SMOKE_URL||'http://127.0.0.1:4173/pharmacist-manabi-sprint/';
const key='pharmacist_manabi_sprint_v060';
function assert(x,msg){if(!x)throw new Error(msg)}
function dayKey(d=new Date()){return d.getFullYear()+'-'+String(d.getMonth()+1).padStart(2,'0')+'-'+String(d.getDate()).padStart(2,'0')}
const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:390,height:844}});
const errors=[];page.on('pageerror',e=>errors.push(e.message));
try{
  await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForFunction(()=>window.PHARM_PRODUCT_META?.active===1031,{timeout:60000});
  await page.waitForFunction(()=>document.querySelector('script[src="./record-fix-v061.js"]'),{timeout:30000});
  const ids=await page.evaluate(()=>window.PHARM_QUESTIONS.filter(q=>q.scored!==false).slice(0,8).map(q=>q.id));
  const today=dayKey();
  const state={totalAnswered:8,totalCorrect:0,weak:{},history:[],inProgress:null,fontSize:'normal',goal:8,shuffleQuestions:true,shuffleChoices:false,daily:{[today]:{a:8,c:0}},mock:{},fields:{},examDate:'',seen:Object.fromEntries(ids.map(id=>[id,1]))};
  await page.evaluate(({key,state})=>localStorage.setItem(key,JSON.stringify(state)),{key,state});
  await page.click('.nav button[data-view="history"]');
  await page.waitForFunction(()=>document.querySelector('#achText')?.textContent.includes('8 / 1031問'),{timeout:10000});
  assert((await page.locator('#donutText').innerText())==='1%','achievement should be 1% after 8/1031 unique questions');
  assert((await page.locator('#achText').innerText()).includes('全体正答率 0%'),'accuracy should remain separately visible as 0%');
  assert(await page.locator('#heatmap .heatCell').count()===35,'heatmap must contain 35 cells');
  assert(await page.locator('#heatmap .heatCell.heatToday.lv3').count()===1,'today must be filled at goal level after 8 answers');
  const widths=await page.evaluate(()=>({doc:document.documentElement.scrollWidth,body:document.body.scrollWidth,inner:innerWidth}));
  assert(widths.doc<=widths.inner+1&&widths.body<=widths.inner+1,'record screen horizontal overflow '+JSON.stringify(widths));
  assert(errors.length===0,'page errors '+errors.join('|'));
  console.log(JSON.stringify({pass:true,answered:8,correct:0,achievement:'1%',heatCells:35,todayLevel:'lv3',pageErrors:0}));
}finally{await browser.close()}
