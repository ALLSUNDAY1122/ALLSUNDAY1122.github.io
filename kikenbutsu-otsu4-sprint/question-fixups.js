'use strict';
(function(){
  if(typeof QUESTIONS==='undefined') throw new Error('QUESTIONS is not loaded');

  // 監査日(sourceCheckedAt)と法令の施行日(legalEffectiveDate)を混同しない。
  // 2026-08-08監査時点の現行施行日:
  // - 消防法: 2025-06-01
  // - 危険物の規制に関する政令: 2026-04-04
  for(const q of QUESTIONS){
    if(q.subject==='法令'){
      q.legalEffectiveDate = q.sourceTitle.includes('危険物の規制に関する政令')
        ? '2026-04-04'
        : '2025-06-01';
    }else if(q.subject==='性質・消火' && (q.topic==='分類' || q.topic==='石油類区分')){
      q.legalEffectiveDate='2025-06-01';
    }else{
      q.legalEffectiveDate=null;
    }
  }

  // 重複問題をIDラベル付加で別問題に見せない。
  // 完全重複・近接重複は監査CI側で検出し、問題自体を作り直す。
})();
