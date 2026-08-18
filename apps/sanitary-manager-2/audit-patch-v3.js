(function(){
'use strict';
const VERSION='2026-08-18-v3';
const BASELINE='2026-08-18';
const RIGHTS='公式資料・公表問題は論点と根拠の確認に限定。問題文・選択肢・解説は独自作成し、原文の無断転載や単純言い換えによる水増しを行わない。';
window.Q_PARTS=(window.Q_PARTS||[]).map(q=>{
  if(q.primarySourceUrl) q.sourceUrl=q.primarySourceUrl;
  if(q.fiveYearExpansion){
    q.baselineDate=BASELINE;
    q.originType='original_from_primary_source';
    q.rightsBasis=RIGHTS;
    q.contentChecked=BASELINE;
    q.auditStatus=q.auditStatus||'監査済';
    q.publicationStatus=q.publicationStatus||'公開候補';
    if(q.lawRelated) q.legalChecked=BASELINE;
  }
  return q;
});
window.SM2_AUDIT_VERSION=VERSION;
window.SM2_LEGAL_BASELINE=BASELINE;
try{
  const key='sm2_manabi_sprint_v110';
  const raw=localStorage.getItem(key);
  if(raw){const s=JSON.parse(raw);if(s.contentVersion!==VERSION){s.resume=null;s.contentVersion=VERSION;localStorage.setItem(key,JSON.stringify(s));}}
}catch(e){}
})();
