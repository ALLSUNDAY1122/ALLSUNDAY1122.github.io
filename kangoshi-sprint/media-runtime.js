(()=>{
'use strict';
const app=document.getElementById('app');
if(!app)return;
const style=document.createElement('style');
style.textContent=`
.question-media{margin:18px 0 20px;padding:12px;border:1px solid #e1ddd4;border-radius:16px;background:#fff;overflow:hidden}
.question-media img{display:block;width:100%;height:auto;max-height:460px;object-fit:contain;border-radius:10px;background:#fff}
.question-media figcaption{margin-top:8px;font-size:12px;line-height:1.55;color:#6e6b64}
@media(max-width:520px){.question-media{margin:14px 0 18px;padding:8px}.question-media img{max-height:390px}}
`;
document.head.appendChild(style);
function norm(s){return String(s||'').replace(/\s+/g,' ').trim()}
function apply(){
  const card=app.querySelector('.qcard');
  const text=card?.querySelector('.qtext');
  if(!card||!text||card.querySelector('.question-media'))return;
  const needle=norm(text.textContent);
  const matches=(window.KANGOSHI_QUESTIONS||[]).filter(q=>norm(q.question)===needle);
  if(matches.length!==1)return;
  const q=matches[0],assets=Array.isArray(q.mediaAssets)?q.mediaAssets:[];
  if(!assets.length||q.mediaReleaseStatus!=='resolved')return;
  const fig=document.createElement('figure');fig.className='question-media';fig.dataset.questionId=q.id;
  for(const asset of assets){
    const img=document.createElement('img');
    img.src='./'+String(asset).replace(/^\.\//,'');img.alt=`${q.id} の問題図版`;img.loading='eager';img.decoding='async';
    fig.appendChild(img);
  }
  if(q.mediaAttribution){const cap=document.createElement('figcaption');cap.textContent=q.mediaAttribution;fig.appendChild(cap)}
  text.insertAdjacentElement('afterend',fig);
}
new MutationObserver(apply).observe(app,{childList:true,subtree:true});
apply();
})();
