(function(){'use strict';
var all=(window.PHARM_QUESTIONS||[]).filter(function(q){return q&&q.rightsStatus==='cleared'&&q.scored!==false});
all.forEach(function(q){var fixed=q.exam;Object.defineProperty(q,'exam',{configurable:true,enumerable:true,get:function(){return fixed},set:function(){}})});
window.PHARM_QUESTIONS=all;
try{
  var key='pharmacist_manabi_sprint_v040';
  var raw=localStorage.getItem(key),s=raw?JSON.parse(raw):null;
  if(s){
    var ids={};all.forEach(function(q){ids[q.id]=1});
    if(s.inProgress&&Array.isArray(s.inProgress.ids)&&s.inProgress.ids.some(function(id){return !ids[id]}))s.inProgress=null;
    if(s.weak){Object.keys(s.weak).forEach(function(id){if(!ids[id])delete s.weak[id]})}
    if(s.seen){Object.keys(s.seen).forEach(function(id){if(!ids[id])delete s.seen[id]})}
    localStorage.setItem(key,JSON.stringify(s));
  }
}catch(e){}
function ready(){
  document.title='薬剤師国家試験｜学びスプリント v0.5';
  var note=document.querySelector('.qaNote');if(note)note.textContent='価値検証版 v0.5｜UI正本 v2.1準拠。権利確認済みの公式問題を加工した問題＋UI検証用オリジナル問題を収録。';
  var infos=document.querySelectorAll('.infoBlock');if(infos[1])infos[1].textContent='薬剤師国家試験｜学びスプリント。厚生労働省の公式問題をもとに加工した監査済みサンプルと、本アプリ作成のUI検証問題で動作確認中です。';
  var tag=document.getElementById('qTag'),detail=document.getElementById('detail'),qText=document.getElementById('qText');
  function patchTag(){if(tag&&tag.textContent.indexOf('第null回・')===0)tag.textContent=tag.textContent.replace('第null回・','オリジナル・')}
  function patchDetail(){
    if(!detail||!qText)return;
    var q=all.find(function(x){return x.q===qText.textContent});if(!q)return;
    var t=q.sourceType==='mhlw_adapted'?'出典：厚生労働省 第'+q.exam+'回薬剤師国家試験 問'+q.sourceQuestionNo+'をもとに加工して作成。解説は本アプリで作成。':'本アプリ作成のオリジナル検証問題。';
    if(detail.textContent!==t)detail.textContent=t;
  }
  if(tag)new MutationObserver(patchTag).observe(tag,{childList:true,subtree:true,characterData:true});
  if(detail)new MutationObserver(patchDetail).observe(detail,{childList:true,subtree:true,characterData:true});
  patchTag();
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',ready);else ready();
})();
