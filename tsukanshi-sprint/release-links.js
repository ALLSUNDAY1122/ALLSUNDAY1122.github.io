'use strict';
(()=>{
const URLS={
  support:'https://allsunday1122.github.io/tsukanshi-sprint/support.html',
  privacy:'https://allsunday1122.github.io/tsukanshi-sprint/privacy.html'
};
function openExternal(url){
  const h=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.openExternal;
  if(h){h.postMessage({url});return;}
  const w=window.open(url,'_blank','noopener,noreferrer');
  if(!w)window.location.href=url;
}
function enhance(){
  const app=document.getElementById('app');
  if(!app||app.querySelector('[data-release-links]'))return;
  const danger=app.querySelector('.setting-card.danger');
  if(!danger)return;
  const section=document.createElement('section');
  section.className='setting-card';
  section.dataset.releaseLinks='true';
  section.innerHTML='<label>サポート・プライバシー</label><div class="stack"><button class="sub-btn" data-support-link>サポートページ</button><button class="sub-btn" data-privacy-link>プライバシーポリシー</button></div><small>外部ブラウザで公開ページを開きます。</small>';
  danger.parentNode.insertBefore(section,danger);
  section.querySelector('[data-support-link]').addEventListener('click',()=>openExternal(URLS.support));
  section.querySelector('[data-privacy-link]').addEventListener('click',()=>openExternal(URLS.privacy));
}
const app=document.getElementById('app');
if(app)new MutationObserver(enhance).observe(app,{childList:true,subtree:true});
enhance();
window.__TSUKANSHI_RELEASE_URLS=Object.freeze({...URLS});
})();
