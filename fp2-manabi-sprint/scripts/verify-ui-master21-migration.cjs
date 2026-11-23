/* Run: node fp2-manabi-sprint/scripts/verify-ui-master21-migration.cjs
 * Static gate for FP2 UI four residual migration items.
 * This does not replace browser or iOS functional testing.
 */
'use strict';
function check(files){
 const errors=[],assert=(ok,message)=>{if(!ok)errors.push(message)};
 const html=files.html,manifest=JSON.parse(files.manifest),sw=files.sw;
 const css=html.match(/<style>([\s\S]*?)<\/style>/)?.[1]||'';
 const navRules=[...css.matchAll(/\.nav\s*\{([^}]*)\}/g)].map(x=>x[1]);
 assert(navRules.length>0,'NAV_MISSING');
 assert(navRules.every(rule=>!/grid-template-columns\s*:\s*repeat\(3\s*,/.test(rule)),'NAV_LEGACY_3_COLUMNS');
 assert(/grid-template-columns\s*:\s*repeat\(4\s*,/.test(navRules.join(';')),'NAV_4_COLUMNS_MISSING');
 assert((html.match(/<button data-screen="/g)||[]).length===4,'NAV_FOUR_TABS_REQUIRED');
 for(const n of [4,8,16])assert(html.includes('data-goal="'+n+'"'),'GOAL_'+n+'_MISSING');
 assert(html.includes("querySelectorAll('[data-goal]')"),'GOAL_HANDLER_MISSING');
 assert(html.includes("querySelectorAll('[data-size]')"),'FONT_AND_GOAL_HANDLER_COLLISION');
 assert(html.includes("return QUESTIONS.slice(0,n)"),'GOAL_SPRINT_LENGTH_MISSING');
 assert(html.includes('id="todayArc"')&&html.includes('function renderToday()'),'TODAY_RING_MISSING');
 assert(html.includes('id="achievementArc"')&&html.includes('id="achievementRate"')&&html.includes('function renderAchievement()'),'ACHIEVEMENT_DONUT_MISSING');
 assert(html.includes('id="domainBars"')&&html.includes('state.domainStats'),'DOMAIN_ACCURACY_MISSING');
 assert(html.includes('id="heatmap"')&&html.includes('offset=-34;offset<=0'),'FIVE_WEEK_HEATMAP_MISSING');
 assert(html.includes('rel="manifest"')&&html.includes("register('./sw.js')"),'PWA_LINK_OR_REGISTRATION_MISSING');
 assert(manifest.display==='standalone'&&manifest.orientation==='portrait'&&manifest.theme_color==='#f7f3ea','PWA_MANIFEST_INVALID');
 assert(Array.isArray(manifest.icons)&&manifest.icons.some(x=>x.src==='icon.svg'),'PWA_ICON_MISSING');
 for(const asset of ['index.html','fp2-approved-bank.js','approved-questions-20261123.json','manifest.json','icon.svg'])assert(sw.includes(asset),'SW_PRECACHED_ASSET_MISSING_'+asset);
 assert(sw.includes("addEventListener('install'")&&sw.includes("addEventListener('fetch'")&&sw.includes("addEventListener('activate'"),'SW_LIFECYCLE_MISSING');
 assert(files.icon.includes('<svg'),'PWA_ICON_INVALID');
 const bank=JSON.parse(files.bank);
 assert(bank.questions.length===310&&bank.release_candidate_questions===298&&bank.reserve_content_pass_questions===12,'CANONICAL_310_298_12_MISMATCH');
 assert(bank.questions.length===310&&bank.questions.every(q=>q.id)&&bank.questions.filter(q=>q.release_selected===true).length===298&&bank.questions.filter(q=>q.release_selected===false).length===12,'CANONICAL_SELECTION_INVALID');
 assert(bank.questions.filter(q=>q.release_selected===true).every(q=>q.independent_audit_status==='PASS'&&Number.isInteger(q.answer_index)&&q.answer_index>=0&&q.answer_index<q.choices.length),'SELECTED_ANSWER_AUDIT_INVALID');
 assert(new Set(bank.questions.map(q=>q.id)).size===bank.questions.length,'CANONICAL_DUPLICATE_ID');
 return {pass:errors.length===0,failures:errors,checks:25};
}
if(typeof module!=='undefined')module.exports={check};
if(typeof require==='function'&&require.main===module){
 const fs=require('node:fs'),path=require('node:path'),root=path.resolve(__dirname,'..');
 const read=x=>fs.readFileSync(path.join(root,x),'utf8');
 const result=check({html:read('index.html'),manifest:read('manifest.json'),sw:read('sw.js'),icon:read('icon.svg'),bank:read('questions/canonical/approved-questions-20261123.json')});
 console.log(JSON.stringify(result,null,2));process.exitCode=result.pass?0:1;
}
