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


(function(){
'use strict';
// HM2 2026-11-22 official-source batch: strictly source metadata only; fail closed.
const fixes=[{"id":"sm2-5y-r04-phy-03","old":"https://www.ncbi.nlm.nih.gov/books/NBK470455/","url":"https://biolincc.nhlbi.nih.gov/media/studies/hfn_relax/Protocol.pdf?link_time=2026-01-19_21%3A02%3A46.453754","basis":"NHLBI BioLINCC HFN-RELAX research protocol, section 14.2.5 p23 (PDF p28): cardiac output = stroke volume x heart rate. Example 70 mL x 70/min = 4.9 L/min. Note this is a hosted study protocol, not NIH clinical guidance."},{"id":"sm2-5y-r04-phy-10","old":"https://www.ncbi.nlm.nih.gov/books/NBK482456/","url":"https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf","basis":"NIOSH official 1976 Criteria for a Recommended Standard, Occupational Exposure to Carbon Dioxide, pp23-24 (PDF indices 31-32): CO2 increases hydrogen ion chemoreceptor response and ventilation; high toxic levels may suppress respiration."},{"id":"sm2-5y-r05-phy-03","old":"https://www.ncbi.nlm.nih.gov/books/NBK539907/","url":"https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf","basis":"NIOSH 1976 government report printed p22 PDF index30: pulmonary blood 46 mmHg CO2 versus alveolar 40 mmHg, transfer via partial-pressure gradient."},{"id":"sm2-5y-r07-phy-01","old":"https://www.ncbi.nlm.nih.gov/books/NBK470339/","url":"https://medlineplus.gov/lab-tests/aldosterone-test/","basis":"NLM MedlinePlus official Aldosterone Test section What is an aldosterone test: adrenal aldosterone restores kidney sodium and potassium balances, sodium retention and potassium excretion."},{"id":"sm2-5y-r10-phy-09","old":"https://www.ncbi.nlm.nih.gov/sites/books/NBK482430/","url":"https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf","basis":"NIOSH 1976 government report printed pp22-23 PDF indices30-31: CO2 + H2O <=> H2CO3 <=> H+ + HCO3, Henderson-Hasselbalch acidification."}];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
 const q=byId.get(f.id);
 if(!q||q.sourceUrl!==f.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2 source-batch-20261122 stale state '+f.id);
 q.sourceUrl=f.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22出典照合：'+f.basis;
}
window.HM2_OFFICIAL_SOURCE_BATCH3_IDS=fixes.map(f=>f.id);
})();


(function(){
'use strict';
// HM2-B 2026-11-22 authoritative-source corrections; metadata only, fail closed.
const fixes=[{"id":"sm2-5y-r04-phy-03","old":"https://biolincc.nhlbi.nih.gov/media/studies/hfn_relax/Protocol.pdf?link_time=2026-01-19_21%3A02%3A46.453754","url":"https://evs.nci.nih.gov/ftp1/CDISC/SDTM/Archive/SDTM%20Terminology%202015-09-25.pdf","basis":"NCI EVS公開のCDISC統制用語C119246ではCardiac OutputをCO=HR×SVと定義。70回/分×70mL/回=4900mL/分=4.9L/分。CDISC標準が原出典でありNIHが独自執筆した解説とは区別する。"},{"id":"sm2-5y-r04-phy-06","old":"https://www.ncbi.nlm.nih.gov/books/NBK531504/","url":"https://cdn-test-cms.who.int/media-tes/docs/default-source/blood-transfusion-safety/guidelines-and-principles-for-safe-blood-transfusion-practice-module-3-.pdf?download=true","basis":"WHO Guidelines and Principles for Safe Blood Transfusion Practice, Module 3 Section 2.6 printed p13, PDF page22: serum after clot and plasma with anticoagulant; soluble fibrinogen converts to fibrin."},{"id":"sm2-5y-r04-phy-07","old":"https://www.ncbi.nlm.nih.gov/books/NBK544269/","url":"https://stacks.cdc.gov/view/cdc/41566/cdc_41566_DS1.pdf","basis":"WHO Guidelines on Drawing Blood: Best Practices in Phlebotomy, Table 2.3: coagulation tube uses sodium citrate for PT/protime; source is WHO publication preserved at CDC Stacks. Plasma centrifugation and PT testing principles corroborated in existing explanation."},{"id":"sm2-5y-r10-phy-08","old":"https://www.ncbi.nlm.nih.gov/books/NBK597379/","url":"https://www.niddk.nih.gov/health-information/liver-disease/biliary-atresia/definition-facts","basis":"NIDDK Definition & Facts of Biliary Atresia section Complications/Portal hypertension: portal vein directly carries blood from intestines to liver. NIDDK digestion article separately shows simple sugars enter bloodstream."}];
const qById=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
 const q=qById.get(f.id);
 if(!q||q.sourceUrl!==f.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2-B authoritative-source stale '+f.id);
 q.sourceUrl=f.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 HM2-B追加根拠：'+f.basis;
}
window.HM2_B_NEW_OFFICIAL_SOURCES=fixes.map(x=>x.id);
})();
