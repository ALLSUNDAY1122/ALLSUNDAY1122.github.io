(function(){'use strict';
function fatal(msg){var note=document.querySelector('.qaNote');if(note)note.textContent='問題データの読み込みに失敗しました：'+msg;document.body.classList.add('data-error')}
function asArray(a){return Array.isArray(a)?a:(Number.isInteger(a)?[a]:[])}
function mapQuestion(q){
  var media=q.displayMode==='officialQuestionImage';
  var choices=media?Array.from({length:Number(q.numberedChoiceCount)||5},function(_,i){return '選択肢 '+(i+1)}):(Array.isArray(q.choices)?q.choices.slice():[]);
  var answer=asArray(q.answer);
  var accepted=Array.isArray(q.accepted_answers)?q.accepted_answers.map(function(x){return asArray(x)}):null;
  // P110-140 HISTORICAL EXAM: preserve the 2025 official answer; display the 2026-04-01 standard change.
  var questionText=q.question||'';
  var memoryText=q.memoryPoint||'';
  var explanationText=q.explanation||'';
  if(q.id==='P110-140'){
    questionText='【2025年2月23日の試験日当時の基準で解答】'+questionText;
    memoryText='試験時点では中性ヨウ化カリウム法を光化学オキシダント測定に使用できた。2026年4月1日以降の環境基準は紫外線吸収法又はエチレン化学発光法。';
    explanationText=(explanationText?explanationText+'\n\n':'')+'【制度改正の注意】2025年2月23日の試験当時は中性ヨウ化カリウム法が測定法の一つであり、正答は変更しない。2026年1月30日の環境省告示改正（同年4月1日施行）後、光化学オキシダントの環境基準の指定測定法は紫外線吸収法又はエチレンを用いる化学発光法となり、中性ヨウ化カリウム法は含まれない。出典：環境省「大気汚染に係る環境基準」https://www.env.go.jp/kijun/taiki.html';
  }
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
    q:questionText,caseStem:caseStem,c:choices,a:answer,accepted:accepted,
    pick:accepted&&accepted.length?accepted[0].length:Math.max(1,answer.length),
    p:memoryText,d:explanationText,detail:(q.attributionDisplay||'')+'。'+(q.modificationDisclosureDisplay||'')+(q.originalDataSourceURL?'。元資料：'+(q.originalDataSourceTitle||'原典')+'　'+q.originalDataSourceURL+'　加工：学びスプリント開発者（公表データを基に独自設問へ加工）':''),
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
