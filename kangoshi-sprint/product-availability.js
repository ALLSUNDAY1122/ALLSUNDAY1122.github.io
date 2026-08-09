(()=>{
'use strict';
const app=document.getElementById('app');
if(!app)return;
let manifest=null,scheduled=false;
const targets={必修:50,一般:130,状況設定:60};
function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;apply()})}
function setText(el,text){if(el&&el.textContent!==text)el.textContent=text}
function applyHome(){
 const btn=app.querySelector('button[data-action="mock"]');
 if(!btn)return;
 const ready=(manifest?.sets||[]).filter(s=>s.status==='ready'&&s.questionCount===240).length;
 const small=btn.querySelector('small'),pill=btn.querySelector('.pill');
 if(ready===3){setText(small,'240問×3回・本番形式');setText(pill,'3回');return}
 setText(small,'製品版 240問×3回を準備中');
 setText(pill,'準備中');
}
function applyMock(){
 const brand=app.querySelector('.page-brand'),title=app.querySelector('.page-title');
 if(!brand||!title||brand.textContent.trim()!=='模擬試験'||title.textContent.trim()!=='本番形式')return;
 const ready=(manifest?.sets||[]).filter(s=>s.status==='ready'&&s.questionCount===240).length;
 if(ready===3)return;
 const tagline=app.querySelector('.page-tagline');
 setText(tagline,'製品版は240問×3回を作成中です。現在の60問MVPを3回分として水増し表示しません。');
 const groups=[...app.querySelectorAll('.mockgroup')];
 groups.forEach((group,i)=>{
   const set=manifest?.sets?.[i];
   const head=group.querySelector('.mocktitle');
   const b=head?.querySelector('b'),span=head?.querySelector('span');
   setText(b,`第${i+1}回`);
   setText(span,set?.status==='ready'&&set?.questionCount===240?'準備完了':'準備中 0/240問');
   const cards=[...group.querySelectorAll('.mockcard')];
   cards.forEach(card=>{
     const cat=card.dataset.mockCat;
     card.disabled=true;
     card.setAttribute('aria-disabled','true');
     const ring=card.querySelector('.mini-ring'),name=card.querySelector('b'),small=card.querySelector('small'),pill=card.querySelector('.result-pill');
     setText(ring,'—');setText(name,cat||'');setText(small,`${targets[cat]||0}問`);setText(pill,'準備中');
     pill?.classList.remove('ok','ng');
   });
 });
}
function apply(){applyHome();applyMock()}
new MutationObserver(schedule).observe(app,{childList:true,subtree:true});
fetch('./product-content/manifest.json',{cache:'no-store'}).then(r=>r.ok?r.json():null).then(m=>{manifest=m;schedule()}).catch(()=>schedule());
schedule();
})();