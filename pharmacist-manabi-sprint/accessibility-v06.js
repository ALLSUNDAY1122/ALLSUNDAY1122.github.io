(function(){'use strict';
function ensure(){var qText=document.getElementById('qText');if(!qText)return null;var e=document.getElementById('qAccessible');if(!e){e=document.createElement('div');e.id='qAccessible';e.className='srOnly';qText.insertAdjacentElement('afterend',e)}return e}
function current(){var tag=document.getElementById('qTag');if(!tag||!window.PHARM_QUESTIONS)return null;var m=tag.textContent.match(/第(\d+)回.*問(\d+)/);if(!m)return null;var ex=Number(m[1]),n=Number(m[2]);return window.PHARM_QUESTIONS.find(function(q){return q.exam===ex&&q.sourceQuestionNo===n})||null}
function update(){var e=ensure(),q=current();if(!e)return;if(q&&q.displayMode==='officialQuestionImage'){e.textContent='画像問題の読み上げ用テキスト。'+(q.accessibleText||q.mediaAlt||'');e.setAttribute('aria-live','polite')}else{e.textContent='';e.removeAttribute('aria-live')}}
function start(){ensure();var tag=document.getElementById('qTag'),media=document.getElementById('qMedia')||document.getElementById('qText');if(tag)new MutationObserver(update).observe(tag,{childList:true,characterData:true,subtree:true});if(media)new MutationObserver(update).observe(media,{childList:true,subtree:true});setTimeout(update,0)}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
})();
