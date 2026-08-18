(function(){
'use strict';
const BASELINE='2026-08-18';
const VERIFIED_RIGHTS='追加210問は公式公表問題の転載ではなく、試験範囲・法令・厚労省資料の論点を根拠に独自作問・独自解説として監査した。';
const questions=window.Q_PARTS||[];
for(const q of questions){
  if(!q.fiveYearExpansion) continue;
  q.baselineDate=BASELINE;
  q.contentChecked=BASELINE;
  q.rightsBasis=VERIFIED_RIGHTS;
  q.publicationStatus='公開候補';
  if(q.lawRelated){
    q.legalChecked=BASELINE;
    q.auditStatus='一次資料照合済';
  }else{
    q.auditStatus='内容監査済';
  }
}

// 2026-08-01施行改正の表現を厳密化する。
// 衛生委員会等への報告義務は辞任・解任時、所轄労基署長への新しい報告義務は
// 辞任・解任・退任（辞任等）を対象とするため、両者を混同しない。
const industrialPhysician=questions.find(q=>q.fiveYearExpansion&&q.topic==='産業医の辞任等の報告');
if(industrialPhysician){
  const clue='産業医が辞任・解任したときは遅滞なく衛生委員会等へその旨と理由を報告する。さらに2026年8月1日以降、選任義務のある事業場で産業医の辞任・解任・退任があったときは、原則として電子申請により所轄労働基準監督署長へ遅滞なく報告する。';
  industrialPhysician.question=`次の説明に最も当てはまる項目はどれか。「${clue}」`;
  industrialPhysician.quick=`産業医の辞任等の報告：${clue}`;
  industrialPhysician.explanation=`正解は「産業医の辞任等の報告」。${clue} 根拠：労働安全衛生規則13条4項・5項、令和8年厚生労働省令第86号。`;
  industrialPhysician.basis='労働安全衛生規則13条4項・5項／令和8年厚生労働省令第86号（2026年8月1日施行）';
  industrialPhysician.primarySourceUrl='https://www.mhlw.go.jp/web/t_doc?dataId=00td0095&dataType=1&pageNo=1';
  industrialPhysician.sourceUrl=industrialPhysician.primarySourceUrl;
}

window.SM2_AUDIT_VERSION='2026-08-18-v4';
window.SM2_LEGAL_BASELINE=BASELINE;
})();
