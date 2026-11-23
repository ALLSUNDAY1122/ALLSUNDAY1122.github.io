/* Browser E2E for FP2 preview; does not claim iPhone/TestFlight acceptance. */
const {chromium}=require('playwright');
const fs=require('node:fs');
const assert=require('node:assert/strict');
const URL='http://127.0.0.1:8765/';
(async()=>{
 const browser=await chromium.launch({headless:true});
 const context=await browser.newContext({serviceWorkers:'allow',acceptDownloads:true});
 const page=await context.newPage();
 page.setDefaultTimeout(15000);page.setDefaultNavigationTimeout(15000);
 page.on('dialog',d=>d.accept());
 const errors=[];page.on('pageerror',e=>errors.push(e.message));
 try{
  console.log('E2E START load');
  await page.goto(URL,{waitUntil:'networkidle'});
  await page.waitForFunction(()=>document.querySelector('#bankStatus')?.textContent.includes('298問'),null,{timeout:20000});
  assert.equal(await page.locator('.chapter').count(),6,'six subject chapters');
  const loaded=await page.evaluate(()=>({n:QUESTIONS.length,domains:[...new Set(QUESTIONS.map(x=>x.domain))].length,meta:QUESTIONS.filter(x=>x.source_url&&x.source_section&&x.modification_note&&x.legal_cutoff).length}));
  assert.deepEqual(loaded,{n:298,domains:6,meta:298});
  console.log('E2E checkpoint loaded selected 298');
  // Daily goal and guided sprint: wrong answer, source provenance, rest of session.
  await page.locator('[data-screen="settings"]').click();
  await page.locator('[data-goal="4"]').click();
  await page.locator('[data-screen="home"]').click();
  await page.locator('#startAll').click();
  assert.equal(await page.locator('#counter').innerText(),'1/4');
  const first=await page.evaluate(()=>session[0].id);
  await page.locator('#unknown').click();
  assert.match(await page.locator('#feedback').innerText(),/出典|改変/);
  assert.equal(await page.locator('#sourceInfo a').count(),1);
  await page.locator('#next').click();
  for(let i=1;i<4;i++){
   await page.locator('#choices .choice').first().click();
   await page.locator('#next').click();
  }
  assert.match(await page.locator('#resultScore').innerText(),/^\d\/4$/);
  await page.locator('#resultHome').click();
  assert.match(await page.locator('#todayCount').innerText(),/^4 \/ 4問$/);
  console.log('E2E checkpoint four-answer learning loop');
  // Sprint must advance to unseen item, not repeatedly start the same first question.
  await page.locator('#startAll').click();
  const second=await page.evaluate(()=>session[0].id);
  assert.notEqual(second,first,'unseen question priority');
  await page.locator('#quizHome').click();
  await page.locator('[data-screen="history"]').click();
  assert.equal(await page.locator('#heatmap .heatcell').count(),35);
  assert.equal(await page.locator('#hAnswered').innerText(),'4');
  console.log('E2E checkpoint unseen-priority and 35-day heatmap');
  // JSON backup: round-trip through reset with native file selection.
  await page.locator('[data-screen="settings"]').click();
  const [download]=await Promise.all([page.waitForEvent('download'),page.locator('#exportData').click()]);
  const saved=await download.path();assert(saved&&fs.existsSync(saved),'export file produced');
  const exported=JSON.parse(fs.readFileSync(saved,'utf8'));
  assert.equal(exported.app,'fp2-manabi-sprint');
  assert.equal(exported.state.answered,4);
  await page.locator('#reset').click();
  await page.waitForFunction(()=>document.querySelector('#bankStatus')?.textContent.includes('298問'));
  await page.locator('[data-screen="settings"]').click();
  await page.locator('#importData').setInputFiles(saved);
  await page.waitForFunction(()=>JSON.parse(localStorage.getItem('fp2_manabi_sprint_v21_approved')||'{}').answered===4);
  await page.locator('[data-screen="history"]').click();
  assert.equal(await page.locator('#hAnswered').innerText(),'4');
  console.log('E2E checkpoint backup export/import');
  // Wait for cache install & service worker to control client before offline reload.
  await page.evaluate(async()=>{await Promise.race([navigator.serviceWorker.ready,new Promise((_,reject)=>setTimeout(()=>reject(new Error('service-worker ready timeout')),12000))]);});
  await page.reload({waitUntil:'networkidle'});
  await page.waitForFunction(()=>document.querySelector('#bankStatus')?.textContent.includes('298問'));
  console.log('E2E checkpoint service worker ready');
  await context.setOffline(true);
  await page.reload({waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>document.querySelector('#bankStatus')?.textContent.includes('298問'),null,{timeout:15000});
  await page.locator('[data-screen="home"]').click();
  await page.locator('#startAll').click();
  assert.equal(await page.locator('#counter').innerText(),'1/4');
  await page.locator('#choices .choice').first().click();
  assert.match(await page.locator('#sourceInfo').innerText(),/出典箇所|改変/);
  if(errors.length)throw Error('Browser JavaScript errors: '+errors.join(' ; '));
  console.log(JSON.stringify({status:'PASS',bank:loaded.n,chapters:loaded.domains,sourceMetadata:loaded.meta,goal:4,backupRoundtrip:true,offlineReload:true,unseenPriority:true,pageErrors:0}));
 }finally{await browser.close();}
})().catch(err=>{console.error(err.stack||err);process.exitCode=1});
