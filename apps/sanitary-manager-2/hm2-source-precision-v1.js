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


(function(){
'use strict';
// HM2-B dead-space calculation formula from CDC/NCHS text. Guard old-state, preserve answer/choices.
const fixes=[{"id":"sm2-5y-r04-phy-08","old":"https://www.ncbi.nlm.nih.gov/books/NBK493219/","url":"https://www.cdc.gov/nchs/data/misc/assessphacc.pdf","basis":"CDC/NCHS 1989 Assessing Physical Fitness and Physical Activity in Population-Based Surveys, ventilation section: minute ventilated air is partitioned by VD/VT and alveolar ventilation; VA=VE(1−VD/VT)=respiratory rate×(VT−VD). 12×(500−150)=4200mL/min. PDF large; parsed official text confirmed, visual screenshot could not be retrieved."},{"id":"sm2-5y-r09-phy-04","old":"https://www.ncbi.nlm.nih.gov/books/NBK482501/","url":"https://www.cdc.gov/nchs/data/misc/assessphacc.pdf","basis":"CDC/NCHS 1989 population physical-activity report: physiological dead space fraction of tidal volume and expired minute volume; VA=respiratory rate×(VT−VD). A=12×(500−150)=4.2L/min, B=20×(300−150)=3.0L/min. PDF large; parsed official text confirmed, visual screenshot unavailable."}];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
 const q=byId.get(f.id);
 if(!q||q.sourceUrl!==f.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2-B CDC formula old-state mismatch '+f.id);
 q.sourceUrl=f.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 CDC換気式照合：'+f.basis;
}
window.HM2_B_CDC_ALVEOLAR_FORMULA_IDS=fixes.map(f=>f.id);
})();


(function(){
'use strict';
// HM2-B muscular sliding theory: official NLM MedlinePlus Genetics citation only.
const q=(window.Q_PARTS||[]).find(x=>x.id==='sm2-5y-r09-phy-02');
if(!q||q.sourceUrl!=='https://www.ncbi.nlm.nih.gov/books/NBK26888/'||!Array.isArray(q.choices)||q.choices.length!==5||q.choices[q.answer-1]!=='アクチンとミオシン')throw Error('HM2-B actin source stale state');
q.sourceUrl='https://medlineplus.gov/genetics/condition/actin-accumulation-myopathy/';
q.basis=String(q.basis||'')+' ／ 2026-11-22 NLM MedlinePlus Genetics：Actin-accumulation myopathy節に筋の細いactin線維と太いmyosin線維が収縮に不可欠と明記。筋線維滑り説は原記載の関係に一致。他選択肢は筋収縮に用いる両線維ではない。';
window.HM2_B_ACTIN_SOURCE_UPDATED='sm2-5y-r09-phy-02';
})();


(function(){
'use strict';
// HM2-B 2026-11-22: exactly three source-only fixes, never set audit/release approval.
const fixes=[{"id":"sm2-5y-r06-phy-07","old":"https://www.ncbi.nlm.nih.gov/books/NBK526069/","url":"https://medlineplus.gov/genetics/gene/aqp2/","basis":"NLM MedlinePlus Genetics AQP2 Normal Function: ADH releases AQP2-containing vesicles into collecting-duct cell membrane and increases water reabsorption; NLM AVPR2 Normal Function directly locates V2 receptor in collecting ducts. Primary government authored explanations."},{"id":"sm2-5y-r06-phy-09","old":"https://www.ncbi.nlm.nih.gov/books/NBK544365/","url":"https://medlineplus.gov/genetics/gene/aqp2/","basis":"NLM MedlinePlus Genetics AQP2 Normal Function: when fluid intake is adequate, AVP/ADH secretion falls, AQP2 channels leave collecting-duct membrane, water reabsorption falls and urine becomes dilute; original question explicitly rules out other ADH stimuli."},{"id":"sm2-5y-r07-phy-08","old":"https://www.ncbi.nlm.nih.gov/books/NBK1177/","url":"https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=e507a317-0acc-4415-f6ec-3ec757565f31","basis":"NLM DailyMed Tolvaptan 12.1 Mechanism of Action: V2 antagonist reduces cAMP; AQP2 vesicles cannot fuse with collecting duct cell membrane; water excretion rises and urine osmolality falls; approval drug label rather than government-authored physiology."}];
const map=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const x of fixes){const q=map.get(x.id);
 if(!q||q.sourceUrl!==x.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2 B AQP2 source stale '+x.id);
 q.sourceUrl=x.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 B AQP2公式出典：'+x.basis;
}
window.HM2_B_AQP2_SOURCE_IDS=fixes.map(x=>x.id);
})();


(function(){
'use strict';
// HM2-B 2026-11-22 3 restricted official-source redesigns. Clear release approval; fail on stale input.
const changes=[{"id":"sm2-5y-r07-phy-04","oldSource":"https://www.ncbi.nlm.nih.gov/books/NBK545157/","oldQuestion":"食事由来の脂肪が小腸で消化・吸収される。長鎖脂肪酸由来の脂質が小腸上皮細胞から移動する主要な経路として適切なのはどれか。","oldCorrect":"カイロミクロンとなって小腸のリンパ管に入り、その後血液循環に合流する。","newQuestion":"食事由来の脂肪が小腸で分解されて脂肪酸が吸収された。脂肪酸の吸収後の主な移送経路について正しい説明はどれか。","newCorrect":"小腸から吸収された脂肪酸はリンパ系に取り込まれ、体内へ運ばれる。","newExplanation":"NIDDK公式消化器解説は脂肪の分解で脂肪酸が生じ、その吸収にリンパ系が関与することを明記している。肢2の『一切吸収されない』、肢3の『腎糸球体で生成』、肢4の『すべての長鎖脂肪酸が遊離したまま門脈へ』、肢5の『胆汁酸が赤血球へ変換』はいずれも不適切。カイロミクロン形成という詳細命題は本問の正答要件から除外した。","newTopic":"食事由来脂肪酸のリンパ系への吸収","source":"https://www.niddk.nih.gov/health-information/digestive-diseases/digestive-system-how-it-works"},{"id":"sm2-5y-r10-phy-02","oldSource":"https://www.ncbi.nlm.nih.gov/books/NBK470209/","oldQuestion":"脂肪を含む食事の後、肝臓で作られた胆汁が十二指腸に流入する。胆汁について正しい説明はどれか。","oldCorrect":"胆汁酸などによって脂質の乳化を助けるが、胆汁自体は消化酵素を主成分としない。","newQuestion":"脂肪を含む食事の後、肝臓で作られた胆汁が十二指腸に流入する。胆汁と膵液の消化への役割について正しい説明はどれか。","newCorrect":"肝臓で作られる胆汁は脂肪の消化を助け、膵液には消化酵素が含まれる。","newExplanation":"NIDDK公式消化器解説『How does my digestive system break food into small parts my body can use?』に、肝臓が胆汁を作り脂肪の消化を助けること、膵臓が脂質・糖質・タンパク質に働く酵素を含む膵液を作ることが明記されている。肢1は胃由来ペプシンの混同、肢2は生成部位・経路の誤り、肢3は胆汁とインスリンの混同、肢4はアミラーゼの対象基質の誤り。乳化という語は原典本文で直接確認できないため正答から除外した。","newTopic":"胆汁による脂肪消化補助と膵液の酵素","source":"https://www.niddk.nih.gov/health-information/digestive-diseases/digestive-system-how-it-works"},{"id":"sm2-5y-r10-phy-10","oldSource":"https://www.niddk.nih.gov/health-information/digestive-diseases/digestive-system-how-it-works","oldQuestion":"昼食でブドウ糖と長鎖脂肪酸を摂取した。小腸で吸収された後の主な輸送経路の組合せとして適切なのはどれか。","oldCorrect":"ブドウ糖は腸管毛細血管から門脈へ、長鎖脂肪酸由来脂質はカイロミクロンとして乳び管へ入る。","newQuestion":"昼食で糖質と脂肪を摂取し、小腸で消化・吸収された。単糖と脂肪酸の吸収後の主な輸送経路の組合せとして適切なのはどれか。","newCorrect":"吸収された単糖は血液に入り肝臓へ運ばれ、脂肪酸の吸収にはリンパ系が関与する。","newExplanation":"NIDDK公式消化器解説『What happens to the digested food?』に、単糖は腸管から血液に吸収され肝臓に運ばれ、脂肪酸はリンパ系で吸収されることが直接記載されている。肢1は糖と脂肪の経路を逆転、肢2は肺静脈への直接移送、肢4は胆管・腎動脈への直接移送、肢5は単糖までリンパのみで移送するとする点が不適切。カイロミクロン・乳び管など原典に明記のない詳細は正答要件から除外した。","newTopic":"小腸で吸収される単糖の血液輸送と脂肪酸のリンパ輸送","source":"https://www.niddk.nih.gov/health-information/digestive-diseases/digestive-system-how-it-works"}];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of changes){const q=byId.get(f.id);
 if(!q||q.sourceUrl!==f.oldSource||q.question!==f.oldQuestion||!Array.isArray(q.choices)||q.choices.length!==5||q.choices[q.answer-1]!==f.oldCorrect)throw Error('HM2 B focused redesign stale '+f.id);
 q.question=f.newQuestion;
 q.choices=[...q.choices];q.choices[q.answer-1]=f.newCorrect;
 q.quick=f.newCorrect;q.explanation=f.newExplanation;q.topic=f.newTopic;q.sourceUrl=f.source;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 NIDDK直接本文の射程に合わせて改稿。NIDDK Digestive System, break down food / digested food sections.';
 q.contentReviewStatus='requires-independent-subject-expert-review';
 q.auditStatus='再監査待ち';q.publicationStatus='非公開';
 if(new Set(q.choices).size!==5||q.choices[q.answer-1]!==f.newCorrect)throw Error('HM2 B redesign choice mapping '+f.id);
}
window.HM2_B_FOCUSED_REDESIGN_IDS=changes.map(x=>x.id);
})();
