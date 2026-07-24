import fs from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const site = path.join(root, 'yorugatari');
const shareVersion = '20260724-002';
const startVersion = '20260724-001';
const files = ['5min-horror.html', 'bedtime-horror.html'];
const shareSection = `    <section class="section landing-share" aria-labelledby="landing-share-title"><div class="wrap"><div class="section-head"><div><div class="eyebrow">Share</div><h2 id="landing-share-title">この特集を共有する</h2></div></div><p class="landing-intro">共有用リンクには作品名や個人情報を含めません。特集から作品を開いた回数は、特集単位の合計だけを匿名で集計します。</p><div class="hero-actions"><button class="btn btn-primary" id="landingShareButton" type="button">共有する</button><button class="btn" id="landingCopyButton" type="button">リンクをコピー</button></div><p class="share-status" id="landingShareStatus" role="status" aria-live="polite"></p></div></section>\n\n`;
const startScript = `  <script data-runtime="landing-start-${startVersion}">\n  (function(){'use strict';const API='https://page-views-api.ratneshc.com/api/v1/track';const SITE='allsunday1122.github.io';const ids={'/yorugatari/5min-horror.html':'five-minute','/yorugatari/bedtime-horror.html':'bedtime'};const p=location.pathname.replace(/\\/{2,}/g,'/').replace(/\\/$/,'');const id=ids[p];if(!id)return;const target='/yorugatari/__landing-start/'+id;const key='yorugatari-landing-start:'+id;const state={version:'${startVersion}',path:target,attempted:false,inFlight:false,tracked:false,error:null};window.YORUGATARI_LANDING_START=state;if(navigator.webdriver&&!window.__YORUGATARI_ALLOW_TRACKING_TEST__)return;function send(){let done=false;try{done=sessionStorage.getItem(key)==='1'}catch(error){}if(done||state.inFlight)return;state.attempted=true;state.inFlight=true;fetch(API+'?site='+encodeURIComponent(SITE)+'&path='+encodeURIComponent(target),{method:'GET',credentials:'omit',cache:'no-store',keepalive:true,referrerPolicy:'no-referrer'}).then(function(response){if(!response.ok)throw new Error('HTTP '+response.status);try{sessionStorage.setItem(key,'1')}catch(error){}state.tracked=true;state.error=null}).catch(function(error){state.error=error&&error.message?error.message:String(error)}).finally(function(){state.inFlight=false})}document.querySelectorAll('a[href^="stories/"]').forEach(function(link){link.addEventListener('click',send)})})();\n  </script>\n`;

function ensureShareSection(html) {
  if (html.includes('id="landingShareButton"')) {
    return html.replace(/<section class="section landing-share"[\s\S]*?<\/section>\n\n/, shareSection);
  }
  const faq = '    <section class="section"><div class="wrap"><div class="section-head"><div><div class="eyebrow">FAQ</div>';
  if (!html.includes(faq)) throw new Error('FAQ insertion point was not found');
  return html.replace(faq, shareSection + faq);
}

function ensureRuntimeScripts(html) {
  html = html.replace(/\s*<script\s+src=["']assets\/landing-share\.js(?:\?v=[^"']*)?["']\s*><\/script>\s*/gi, '\n');
  html = html.replace(/\s*<script\s+data-runtime=["']landing-start-[^"']+["'][\s\S]*?<\/script>\s*/gi, '\n');
  const analytics = /  <script src="assets\/analytics\.js\?v=[^"]+"><\/script>/;
  if (!analytics.test(html)) throw new Error('Analytics script insertion point was not found');
  return html.replace(analytics, `  <script src="assets/landing-share.js?v=${shareVersion}"></script>\n${startScript}$&`);
}

let changed = 0;
for (const filename of files) {
  const filePath = path.join(site, filename);
  const before = fs.readFileSync(filePath, 'utf8');
  let after = ensureShareSection(before);
  after = ensureRuntimeScripts(after);
  if (after !== before) {
    fs.writeFileSync(filePath, after, 'utf8');
    changed += 1;
  }
}

console.log(`Ensured curated landing sharing and inline start tracking on ${files.length} pages; changed ${changed}.`);
