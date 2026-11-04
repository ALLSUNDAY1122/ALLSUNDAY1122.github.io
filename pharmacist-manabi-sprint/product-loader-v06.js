(function(){'use strict';
function fatal(msg){var note=document.querySelector('.qaNote');if(note)note.textContent='問題データの読み込みに失敗しました：'+msg;document.body.classList.add('data-error')}
function asArray(a){return Array.isArray(a)?a:(Number.isInteger(a)?[a]:[])}
function mapQuestion(q){
  var media=q.displayMode==='officialQuestionImage';
  var choices=media?Array.from({length:Number(q.numberedChoiceCount)||5},function(_,i){return '選択肢 '+(i+1)}):(Array.isArray(q.choices)?q.choices.slice():[]);
  var answer=asArray(q.answer);
  var accepted=Array.isArray(q.accepted_answers)?q.accepted_answers.map(function(x){return asArray(x)}):null;
  var caseStem=q.sharedStem||'';
  if(Number(q.sourceExam)===111 && (Number(q.questionNo)===220 || Number(q.questionNo)===221)){
    // MHLW correction table 001677936.pdf: capsule count unit in the shared case.
    caseStem=caseStem.replace(/デュロキセチン塩酸塩カプセル\s*20\s*mg\s*1\s*回\s*1\s*錠\s*[（(]\s*1\s*日\s*2\s*錠\s*[）)]/,'デュロキセチン塩酸塩カプセル 20 mg 1 回 1 カプセル （ 1 日 2 カプセル）');
    if(caseStem.indexOf('デュロキセチン塩酸塩カプセル 20 mg 1 回 1 カプセル （ 1 日 2 カプセル）')<0){
      throw new Error('MHLW correction missing in '+q.id);
    }
  }
  return {
    id:q.id,exam:Number(q.sourceExam),sourceQuestionNo:Number(q.questionNo),f:q.subject,s:q.domain,
    q:q.question||'',caseStem:caseStem,c:choices,a:answer,accepted:accepted,
    pick:accepted&&accepted.length?accepted[0].length:Math.max(1,answer.length),
    p:q.memoryPoint||'',d:q.explanation||'',detail:(q.attributionDisplay||'')+'。'+(q.modificationDisclosureDisplay||''),
    scored:q.scoring_status!=='excluded',scoringStatus:q.scoring_status,rightsStatus:'cleared',sourceType:'mhlw_product',
    displayMode:q.displayMode,mediaAssets:Array.isArray(q.mediaAssets)?q.mediaAssets.slice():[],
    mediaAlt:'厚生労働省 第'+q.sourceExam+'回薬剤師国家試験 問'+q.questionNo+' 公式問題画像',
    canonicalId:q.dailySprintCanonicalId||q.id,corrections:q.correctionStatus||[],origin:q.origin_type||'licensed_official'
  };
}
function loadScript(src,onload){var s=document.createElement('script');s.src=src;s.defer=true;if(onload)s.onload=onload;document.body.appendChild(s)}
if('serviceWorker' in navigator){window.addEventListener('load',function(){navigator.serviceWorker.register('./sw.js').catch(function(e){console.warn('SW',e)})})}
fetch('./content/product/questions.json',{cache:'no-store'}).then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.json()}).then(function(data){
  if(!data||!Array.isArray(data.questions)||data.questions.length!==1035)throw new Error('問題数が1035問ではありません');
  var mapped=data.questions.map(mapQuestion),ids={},err=[];
  mapped.forEach(function(q){if(!q.id||ids[q.id])err.push('ID:'+q.id);ids[q.id]=1;if(q.scored&&(!q.c.length||!q.a.length)&&!(q.accepted&&q.accepted.length))err.push('正答:'+q.id)});
  if(err.length)throw new Error('QA '+err.slice(0,8).join(','));
  window.PHARM_QUESTIONS=mapped;
  window.PHARM_PRODUCT_META={version:data.contentVersion||'product-v1',total:mapped.length,active:mapped.filter(function(q){return q.scored}).length,excluded:mapped.filter(function(q){return !q.scored}).length};
  loadScript('./app-v06.js',function(){loadScript('./record-fix-v061.js')});
}).catch(function(e){console.error(e);fatal(e&&e.message?e.message:String(e))});
})();
