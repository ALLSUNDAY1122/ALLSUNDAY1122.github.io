'use strict';
(()=>{
const OFFICIAL={
 '第59回':'https://www.customs.go.jp/tsukanshi/59_shiken/59shikenkaito.html',
 '第58回':'https://www.customs.go.jp/tsukanshi/58_shiken/58shikenkaito.html',
 '第57回':'https://www.customs.go.jp/tsukanshi/57_shiken/57shikenkaito.html'
};
function openExternal(url){
 const h=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.openExternal;
 if(h){h.postMessage({url});return;}
 const w=window.open(url,'_blank','noopener,noreferrer');
 if(!w)window.location.href=url;
}
function enhance(){
 const app=document.getElementById('app');if(!app)return;
 app.querySelectorAll('.mock-round').forEach(section=>{
   const title=section.querySelector('.mocktitle b')?.textContent?.trim();
   const url=OFFICIAL[title];if(!url||section.querySelector('[data-official-exam]'))return;
   const b=document.createElement('button');
   b.type='button';b.className='mock-card';b.dataset.officialExam=title;
   b.innerHTML='<span><b>税関公式問題を開く</b><small>税関ホームページ・外部サイト</small></span><svg class="svg-ic" viewBox="0 0 24 24" aria-hidden="true"><path d="M5 12h14 M13 6l6 6-6 6"/></svg>';
   b.addEventListener('click',()=>openExternal(url));
   section.appendChild(b);
 });
 const notice=app.querySelector('.notice');
 if(notice&&notice.textContent.includes('権利監査完了後'))notice.textContent='アプリ内の模試は監査済み独自問題です。実際の第59〜57回問題は、各回の「税関公式問題を開く」から税関ホームページで確認できます。';
}
const app=document.getElementById('app');
if(app)new MutationObserver(enhance).observe(app,{childList:true,subtree:true});
enhance();
window.__TSUKANSHI_OFFICIAL_EXAM_LINKS=Object.freeze({...OFFICIAL});
})();
