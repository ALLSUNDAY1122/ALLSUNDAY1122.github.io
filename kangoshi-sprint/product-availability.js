(()=>{
'use strict';
const app=document.getElementById('app');
if(!app)return;
let manifest=null,scheduled=false;
const targets={必修:50,一般:130,状況設定:60};
function schedule(){if(scheduled)return;scheduled=true;queueMicrotask(()=>{scheduled=false;apply()})}
function setText(el,text){if(el&&el.textContent!==text)el.textContent=text}
function readySet(s){return s?.status==='ready'&&s?.questionCount===240&&s?.releaseEligibleCount===240}
function progressText(s){
 if(!s)return'準備中 0/240問';
 if(readySet(s))return'監査済み 240/240問';
 const imported=Number(s.importedCount||0),eligible=Number(s.releaseEligibleCount||0);
 if(imported>0)return`取込 ${imported}/240 ・ リリース可能 ${eligible}/240`;
 return'取込準備中 0/240問';
}
function applyHome(){
 const btn=app.querySelector('button[data-action="mock"]');
 if(!btn)return;
 const sets=manifest?.sets||[],ready=sets.filter(readySet).length;
 const small=btn.querySelector('small'),pill=btn.querySelector('.pill');
 if(ready===3){setText(small,'第115・114・113回／各240問');setText(pill,'3回');return}
 const imported=sets.reduce((n,s)=>n+Number(s.importedCount||0),0);
 setText(small,`公式3回分を監査中${imported?`・取込${imported}/720問`:''}`);
 setText(pill,ready?`${ready}/3解放`:'準備中');
}
function applyMock(){
 const brand=app.querySelector('.page-brand'),title=app.querySelector('.page-title');
 if(!brand||!title||brand.textContent.trim()!=='模擬試験'||title.textContent.trim()!=='本番形式')return;
 const sets=manifest?.sets||[],ready=sets.filter(readySet).length;
 const tagline=app.querySelector('.page-tagline');
 setText(tagline,ready===3?'第115・114・113回を、午前・午後240問の本番構成で解けます。':'厚生労働省公開の第115・114・113回を取込・監査中です。未監査問題を水増しして解放しません。');
 const groups=[...app.querySelectorAll('.mockgroup')];
 groups.forEach((group,i)=>{
   const set=sets[i];
   const head=group.querySelector('.mocktitle');
   const b=head?.querySelector('b'),span=head?.querySelector('span');
   setText(b,set?.label||`セット${i+1}`);
   setText(span,progressText(set));
   const cards=[...group.querySelectorAll('.mockcard')];
   cards.forEach(card=>{
     const cat=card.dataset.mockCat;
     const canOpen=readySet(set);
     card.disabled=!canOpen;
     card.setAttribute('aria-disabled',String(!canOpen));
     const ring=card.querySelector('.mini-ring'),name=card.querySelector('b'),small=card.querySelector('small'),pill=card.querySelector('.result-pill');
     if(!canOpen){setText(ring,'—');setText(name,cat||'');setText(small,`${targets[cat]||0}問`);setText(pill,'監査中');pill?.classList.remove('ok','ng')}
   });
 });
}
function apply(){applyHome();applyMock()}
new MutationObserver(schedule).observe(app,{childList:true,subtree:true});
fetch('./product-content/manifest.json',{cache:'no-store'}).then(r=>r.ok?r.json():null).then(m=>{manifest=m;schedule()}).catch(()=>schedule());
schedule();
})();
