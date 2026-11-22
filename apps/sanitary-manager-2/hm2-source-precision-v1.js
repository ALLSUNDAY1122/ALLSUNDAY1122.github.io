(function(){
'use strict';
// HM2 source-precision patch. Source citations only; no question, answer or choice changes.
const target=["sm2-5y-r05-hyg-05","sm2-5y-r07-hyg-08"];
const previous="https://www.aist.go.jp/aist_j/new_research/2020/nr20201224/nr20201224.html";
const replacement="https://www.aist.go.jp/aist_j/new_research/2020/nr20201203/nr20201203.html";
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for (const id of target) {
  const q=byId.get(id);
  if (!q || q.sourceUrl!==previous || !Array.isArray(q.choices) || q.choices.length!==5)
    throw new Error('HM2 source precision old state mismatch '+id);
  q.sourceUrl=replacement;
  q.basis=String(q.basis||'')+'／産総研2020-12-03公表「地下鉄車両の窓開けなどの換気の効果」用語の説明「換気回数」：N=Q/V（回/h）。この設問の数値は独自の仮定条件であり、換気回数4回/hを一律の法定義務としない。';
}
window.HM2_SOURCE_PRECISION_UPDATED_IDS=target;
})();
