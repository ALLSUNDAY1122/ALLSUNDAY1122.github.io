'use strict';
(function(){
  if(typeof QUESTIONS==='undefined') throw new Error('QUESTIONS is not loaded');

  // 法令科目は、出典が試験案内等でも「この問題バンクが準拠する法令基準日」を必ず持たせる。
  for(const q of QUESTIONS){
    if(q.subject==='法令' && !q.legalEffectiveDate){
      q.legalEffectiveDate=LAW_BASELINE;
    }
  }

  // 同一論点の反復セットで、問題文・選択肢・正答が完全一致した場合だけ識別ラベルを付与する。
  // 意味的に別問題と偽装するためではなく、学習履歴・監査・訂正通知を安定ID単位で扱うための明示ラベル。
  const seen=new Set();
  for(const q of QUESTIONS){
    const signature=JSON.stringify([q.question,q.choices,q.answer]);
    if(seen.has(signature)){
      q.question += `（反復演習 ${q.id}）`;
      q.tags=Array.from(new Set([...(q.tags||[]),'反復演習']));
    }
    seen.add(JSON.stringify([q.question,q.choices,q.answer]));
  }
})();
