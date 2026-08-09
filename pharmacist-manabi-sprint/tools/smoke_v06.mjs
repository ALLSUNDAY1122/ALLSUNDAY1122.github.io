import { chromium } from 'playwright';

const base = process.env.SMOKE_URL || 'http://127.0.0.1:4173/pharmacist-manabi-sprint/';
const key = 'pharmacist_manabi_sprint_v060';
function assert(x,msg){ if(!x) throw new Error(msg); }
function blankState(inProgress=null){return {totalAnswered:0,totalCorrect:0,weak:{},history:[],inProgress,fontSize:'normal',goal:8,shuffleQuestions:false,shuffleChoices:false,daily:{},mock:{},fields:{},examDate:'',seen:{}}}
const browser = await chromium.launch({headless:true});
const page = await browser.newPage({viewport:{width:390,height:844}});
const pageErrors=[];
page.on('console',m=>console.log('BROWSER',m.type(),m.text()));
page.on('pageerror',e=>{ pageErrors.push(e.message); console.log('PAGEERROR',e.message); });
async function noOverflow(label){
  const m=await page.evaluate(()=>({scrollWidth:document.documentElement.scrollWidth,innerWidth:window.innerWidth,bodyWidth:document.body.scrollWidth}));
  assert(m.scrollWidth<=m.innerWidth+1 && m.bodyWidth<=m.innerWidth+1,label+' horizontal overflow '+JSON.stringify(m));
}
try{
  await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
  await page.waitForFunction(()=>window.PHARM_PRODUCT_META && window.PHARM_PRODUCT_META.total===1035,{timeout:60000});
  await page.waitForFunction(()=>document.querySelector('.qaNote')?.textContent.includes('v0.6'),{timeout:30000});
  const meta=await page.evaluate(()=>({meta:window.PHARM_PRODUCT_META,media:window.PHARM_QUESTIONS.filter(q=>q.displayMode==='officialQuestionImage').length,flex:window.PHARM_QUESTIONS.filter(q=>q.accepted&&q.accepted.length).length}));
  assert(meta.meta.total===1035,'total!=1035'); assert(meta.meta.active===1031,'active!=1031'); assert(meta.meta.excluded===4,'excluded!=4'); assert(meta.media===154,'media!=154'); assert(meta.flex===3,'flex!=3');
  assert(await page.locator('#fieldList .fieldCard').count()>=7,'field cards missing');
  await noOverflow('home');

  await page.click('#startBtn');
  await page.waitForSelector('#quiz.active');
  assert((await page.locator('#qTag').innerText()).startsWith('第'),'question tag invalid');
  assert(await page.locator('#choices .choice').count()>=2,'choices missing');
  await noOverflow('text quiz');
  await page.click('#unknownBtn');
  await page.waitForSelector('#feedback:not(.hidden)');
  assert((await page.locator('#memory').innerText()).trim().length>5,'memoryPoint empty');
  assert((await page.locator('#reason').innerText()).trim().length>10,'explanation empty');
  assert((await page.locator('#detail').textContent()).includes('厚生労働省'),'attribution missing');
  await noOverflow('text feedback');
  await page.click('#quitBtn');

  await page.click('.nav button[data-view="mock"]');
  assert(await page.locator('#mockGroups .mockgroup').count()===3,'mock exam groups !=3');
  assert(await page.locator('#mockGroups .mockCard').count()===9,'mock cards !=9');
  await noOverflow('mock');
  await page.click('.nav button[data-view="history"]');
  assert(await page.locator('#heatmap i').count()===35,'heatmap cells !=35');
  await noOverflow('history heatmap');
  await page.click('.nav button[data-view="settings"]');
  assert(await page.locator('#goalSeg button').count()===3,'goal segment missing');
  await noOverflow('settings');

  const mediaId=await page.evaluate(()=>window.PHARM_QUESTIONS.find(q=>q.displayMode==='officialQuestionImage'&&q.scored)?.id);
  assert(mediaId,'no media question');
  const mediaState=blankState({title:'媒体確認',field:'媒体',ids:[mediaId],index:0,results:[],orders:{},isMock:false});
  await page.evaluate(({key,st})=>localStorage.setItem(key,JSON.stringify(st)),{key,st:mediaState});
  await page.reload({waitUntil:'domcontentloaded'}); await page.waitForFunction(()=>window.PHARM_PRODUCT_META?.total===1035); await page.waitForSelector('#resumeBtn.show'); await page.click('#resumeBtn');
  await page.waitForSelector('#qMedia img');
  await page.waitForFunction(()=>document.querySelector('#qMedia img')?.complete && document.querySelector('#qMedia img')?.naturalWidth>100,{timeout:30000});
  assert(await page.locator('#choices .choice').count()>=2,'media numbered choices missing');
  await page.waitForFunction(()=>document.querySelector('#qAccessible')?.textContent.length>20,{timeout:10000});
  assert((await page.locator('#qAccessible').textContent()).includes('画像問題'),'media accessibility fallback missing');
  await noOverflow('media quiz');

  const flex=await page.evaluate(()=>{const q=window.PHARM_QUESTIONS.find(x=>x.id==='P111-287');return {id:q.id,combo:q.accepted[0]}});
  const flexState=blankState({title:'複数正答確認',field:'実践',ids:[flex.id],index:0,results:[],orders:{},isMock:false});
  await page.evaluate(({key,st})=>localStorage.setItem(key,JSON.stringify(st)),{key,st:flexState});
  await page.reload({waitUntil:'domcontentloaded'}); await page.waitForFunction(()=>window.PHARM_PRODUCT_META?.total===1035); await page.waitForSelector('#resumeBtn.show'); await page.click('#resumeBtn');
  for(const i of flex.combo) await page.click(`#choices .choice[data-orig="${i}"]`);
  await page.waitForSelector('#feedback:not(.hidden)');
  assert((await page.locator('#fbHead').innerText()).includes('正解'),'flexible accepted pair not graded correct');
  await noOverflow('flexible answer feedback');
  assert(pageErrors.length===0,'page errors: '+JSON.stringify(pageErrors));

  console.log(JSON.stringify({pass:true,total:meta.meta.total,active:meta.meta.active,media:meta.media,flex:meta.flex,mockCards:9,heatmap:35,mediaAccessibility:true,horizontalOverflow:false,pageErrors:0}));
} finally { await browser.close(); }
