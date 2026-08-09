import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here=path.dirname(fileURLToPath(import.meta.url));
const appRoot=path.resolve(here,'..');
const manifest=JSON.parse(fs.readFileSync(path.join(appRoot,'audit/ui-30-state-manifest.json'),'utf8'));
const outDir=path.join(appRoot,'audit/screenshots');
fs.mkdirSync(outDir,{recursive:true});
const base=(process.env.BASE_URL||'http://127.0.0.1:4173/cpa-short-answer-sprint/').replace(/\?$/,'');
const browser=await chromium.launch({headless:true});
const results=[];
let failed=false;

for(const st of manifest.states){
  const viewport=st.viewport||manifest.standard_viewport;
  const page=await browser.newPage({viewportSize:viewport});
  const url=`${base}?audit=${encodeURIComponent(st.preset)}`;
  try{
    await page.goto(url,{waitUntil:'networkidle',timeout:30000});
    await page.waitForFunction(()=>window.__CPA_READY__===true,{timeout:30000});
    const data=await page.evaluate(()=>({
      audit:document.body.dataset.auditState,
      view:document.body.dataset.view,
      paper:getComputedStyle(document.documentElement).getPropertyValue('--paper').trim(),
      ai:getComputedStyle(document.documentElement).getPropertyValue('--ai').trim(),
      shu:getComputedStyle(document.documentElement).getPropertyValue('--shu').trim(),
      midori:getComputedStyle(document.documentElement).getPropertyValue('--midori').trim(),
      kin:getComputedStyle(document.documentElement).getPropertyValue('--kin').trim(),
      appWidth:getComputedStyle(document.querySelector('.app')).maxWidth,
      navCount:document.querySelectorAll('.nav button').length,
      slots:window.__CPA_AUDIT__.OCC.length,
      unique:window.__CPA_AUDIT__.BANK.length
    }));
    if(data.audit!==st.preset)throw new Error(`audit preset mismatch ${data.audit}`);
    if(data.paper!=='#f7f3ea'||data.ai!=='#2f4a6d'||data.shu!=='#d8452c'||data.midori!=='#2f7d5c'||data.kin!=='#b5872b')throw new Error(`design token mismatch ${JSON.stringify(data)}`);
    if(data.appWidth!=='520px')throw new Error(`max-width ${data.appWidth}`);
    if(data.slots!==279||data.unique!==278)throw new Error(`data slots/unique ${data.slots}/${data.unique}`);
    for(const sel of st.selectors){
      const loc=page.locator(sel).first();
      if(await loc.count()===0)throw new Error(`missing ${sel}`);
      if(!await loc.isVisible())throw new Error(`not visible ${sel}`);
    }
    if(await page.locator('.nav').count()){
      if(data.navCount!==4)throw new Error(`navCount ${data.navCount}`);
    }
    const file=path.join(outDir,`${st.name}.png`);
    await page.screenshot({path:file,fullPage:true});
    results.push({name:st.name,preset:st.preset,viewport,status:'PASS',view:data.view,file:path.relative(appRoot,file)});
    console.log(`PASS ${st.name}`);
  }catch(e){
    failed=true;
    results.push({name:st.name,preset:st.preset,viewport,status:'FAIL',error:String(e)});
    console.error(`FAIL ${st.name}:`,e);
  }finally{await page.close()}
}
await browser.close();
const summary={audit:'CPA Golden Master v2.1 30-state screenshot audit',status:failed?'FAIL':'PASS',count:results.length,passed:results.filter(x=>x.status==='PASS').length,failed:results.filter(x=>x.status==='FAIL').length,results};
fs.writeFileSync(path.join(appRoot,'audit/screenshot-audit-result.json'),JSON.stringify(summary,null,2));
if(results.length!==30||failed)process.exit(1);
console.log(JSON.stringify({status:'PASS',states:30},null,2));
