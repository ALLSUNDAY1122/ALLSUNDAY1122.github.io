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

(function(){
'use strict';
// 2026-11-22 official-source-only corrections, fail closed.
// Do not alter question text, choices, answer or any law/publication approval.
const fixes=[{"id":"sm2-5y-r05-phy-10","old":"https://www.ncbi.nlm.nih.gov/books/NBK554545/","url":"https://medlineplus.gov/lab-tests/lipase-tests/","basis":"NLM MedlinePlus Lipase Tests: lipase is pancreatic digestive enzyme for fats; pancreatic lipase / fat digestion."},{"id":"sm2-5y-r06-phy-02","old":"https://www.ncbi.nlm.nih.gov/books/NBK482502/","url":"https://www.nhlbi.nih.gov/health/lungs/body-controls-breathing","basis":"NHLBI breathing mechanics: contraction produces lower pressure and inflow."},{"id":"sm2-5y-r07-phy-06","old":"https://www.ncbi.nlm.nih.gov/sites/books/NBK279127/","url":"https://dailymed.nlm.nih.gov/dailymed/getFile.cfm?setid=8cc40354-b5ac-45b6-a211-93b44444f2a3&type=pdf","basis":"NLM DailyMed approved glucagon label sec 12.1: glycogenolysis and liver glycogen stores condition."},{"id":"sm2-5y-r10-phy-04","old":"https://pmc.ncbi.nlm.nih.gov/articles/PMC3889318/","url":"https://www.niddk.nih.gov/news/archive/2016/story-discovery-sglt2-inhibitors-harnessing-kidneys-help-treat-diabetes","basis":"NIDDK 2016 SGLT2 discovery report: glucose reclamation along earlier proximal tubule; governmental own editorial."},{"id":"sm2-5y-r07-phy-09","old":"https://www.ncbi.nlm.nih.gov/books/NBK542189/","url":"https://www.nei.nih.gov/research-and-training/research-news/novel-population-neurons-identified-control-binocular-eye-movements-3d-space","basis":"NEI 2020 near triad: accommodation, pupillary constriction, vergence; combined with NEI convergence insufficiency near vision."}];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const fix of fixes){
 const q=byId.get(fix.id);
 if(!q||q.sourceUrl!==fix.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)
  throw Error('HM2 official-source-v2 stale state '+fix.id);
 q.sourceUrl=fix.url;
 q.basis=String(q.basis||'')+' ／ 出典精密化2026-11-22：'+fix.basis;
}
window.HM2_OFFICIAL_SOURCE_V2_IDS=fixes.map(f=>f.id);
})();
