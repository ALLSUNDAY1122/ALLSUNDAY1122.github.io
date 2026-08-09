(function(){'use strict';
function fatal(msg){var note=document.querySelector('.qaNote');if(note)note.textContent='問題データの読み込みに失敗しました：'+msg;document.body.classList.add('data-error')}
function asArray(a){return Array.isArray(a)?a:(Number.isInteger(a)?[a]:[])}
function mapQuestion(q){
  var media=q.displayMode==='officialQuestionImage';
  var choices=media?Array.from({length:Number(q.numberedChoiceCount)||5},function(_,i){return '選択肢 '+(i+1)}):(Array.isArray(q.choices)?q.choices.slice():[]);
  var answer=asArray(q.answer);
  var accepted=Array.isArray(q.accepted_answers)?q.accepted_answers.map(function(x){return asArray(x)}):null;
  return {
    id:q.id,exam:Number(q.sourceExam),sourceQuestionNo:Number(q.questionNo),f:q.subject,s:q.domain,
    q:q.question||'',caseStem:q.sharedStem||'',c:choices,a:answer,accepted:accepted,
    pick:accepted&&accepted.length?accepted[0].length:Math.max(1,answer.length),
    p:q.memoryPoint||'',d:q.explanation||'',detail:(q.attributionDisplay||'')+'。'+(q.modificationDisclosureDisplay||''),
    scored:q.scoring_status!=='excluded',scoringStatus:q.scoring_status,rightsStatus:'cleared',sourceType:'mhlw_product',
    displayMode:q.displayMode,mediaAssets:Array.isArray(q.mediaAssets)?q.mediaAssets.slice():[],
    mediaAlt:'厚生労働省 第'+q.sourceExam+'回薬剤師国家試験 問'+q.questionNo+' 公式問題画像',
    canonicalId:q.dailySprintCanonicalId||q.id,corrections:q.correctionStatus||[],origin:q.origin_type||'licensed_official'
  };
}
fetch('./content/product/questions.json',{cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.json()}).then(function(data){
  if(!data||!Array.isArray(data.questions)||data.questions.length!==1035)throw new Error('問題数が1035問ではありません');
  var mapped=data.questions.map(mapQuestion),ids={},err=[];
  mapped.forEach(function(q){if(!q.id||ids[q.id])err.push('ID:'+q.id);ids[q.id]=1;if(q.scored&&(!q.c.length||!q.a.length)&&!(q.accepted&&q.accepted.length))err.push('正答:'+q.id)});
  if(err.length)throw new Error('QA '+err.slice(0,8).join(','));
  window.PHARM_QUESTIONS=mapped;
  window.PHARM_PRODUCT_META={version:data.contentVersion||'product-v1',total:mapped.length,active:mapped.filter(function(q){return q.scored}).length,excluded:mapped.filter(function(q){return !q.scored}).length};
  var s=document.createElement('script');s.src='./app-v06.js';s.defer=true;document.body.appendChild(s);
}).catch(function(e){console.error(e);fatal(e&&e.message?e.message:String(e))});
})();
