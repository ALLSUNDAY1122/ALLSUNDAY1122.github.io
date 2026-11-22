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


(function(){
'use strict';
// HM2 B 2026-11-22 three official-author source metadata corrections; fail-closed.
const fixes=[{"id":"sm2-5y-r04-phy-01","old":"https://www.ncbi.nlm.nih.gov/books/NBK539701/","url":"https://www.cdc.gov/yellow-book/hcp/environmental-hazards-risks/high-altitude-travel-and-altitude-illness.html","basis":"CDC Yellow Book High-Altitude Travel, Epidemiology: lower atmospheric pressure reduces inspired PO2; at 3050m inspired PO2 approximately 69% sea-level and acute exposure lowers arterial oxygen saturation to 88-91%. CDC MMWR anemia altitude reports consequent reduced saturation and compensatory gradual erythrocyte production. Existing question holds Hb constant immediately."},{"id":"sm2-5y-r05-phy-09","old":"https://www.ncbi.nlm.nih.gov/books/NBK9961/","url":"https://medlineplus.gov/genetics/gene/tnnt3/","basis":"NLM MedlinePlus Genetics TNNT3 Normal Function says skeletal-muscle troponin calcium-dependent change enables thick/thin filament interaction; MedlinePlus RYR1 Normal Function says increasing myocyte calcium triggers contraction; ACTA1 names actin thin and myosin thick filaments. Source-authored NLM, not NCBI-hosted third-party textbook."},{"id":"sm2-5y-r07-phy-02","old":"https://pubmed.ncbi.nlm.nih.gov/37248992/","url":"https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/mathematical-models/insulin-signaling-models","basis":"NIDDK Laboratory of Biological Modeling 'Metabolic Insulin Signaling Pathway Model' depicts insulin receptor -> PI3K -> GLUT4 translocation and discusses insulin resistance. Complementary NIDDK Insulin Resistance & Prediabetes states muscle cells have reduced insulin response; same-insulin-condition described in question is the constrained mechanism."}];
const qs=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){const q=qs.get(f.id);
 if(!q||q.sourceUrl!==f.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2 official physiology source stale '+f.id);
 q.sourceUrl=f.url;q.basis=String(q.basis||'')+' ／ 2026-11-22政府機関原著確認：'+f.basis;
}
window.HM2_B_LATE_OFFICIAL_PHYSIOLOGY_IDS=fixes.map(f=>f.id);
})();


(function(){
'use strict';
// HM2-B scoped rewrites with fail-closed old-state checks. Any rewrite invalidates release approvals.
const edits=[{"id":"sm2-5y-r10-hyg-04","oldQuestion":"定期健康診断で有所見者が増えた部署がある。個人情報への配慮を保ちながら集団の健康課題を把握する方法はどれか。","oldCorrect":"十分な人数を確保した匿名化・集計結果と職場の作業条件を併せて評価する。","newCorrect":"個人が特定されないよう適切に加工・集計した健診結果を、職場の作業条件と併せて評価する。","newExplanation":"第2肢が適切。厚労省『労働者の心身の状態に関する情報の適正な取扱い指針』2（1）～（5）は健康確保目的に必要な情報に限定し、取扱権限・管理・加工を定める。部署の健康指標を扱う場合、氏名を除いた集計だけでなく少人数・属性の組合せによる再識別リスクを確認し、個人が特定されないよう適切に加工して作業条件と併せて評価する。固定の人数閾値が法的に必須とは断定しない。肢1は氏名付き結果の無制限配布、肢3は勤務条件との関連評価を放棄、肢4は本人同意・取扱規程を無視、肢5は診断の推測と公表で不適切。なお健診集団分析とストレスチェック集団分析の法定人数要件を混同しない。","source":"https://www.mhlw.go.jp/content/000922318.pdf","basis":"厚労省2018年制定・2022年改正心身の状態に関する情報の適正取扱い指針2(1)-(5)：目的と権限制限・加工・適正管理を確認。ストレスチェック独自の集計人数ルールを一般健診へ流用しない。"},{"id":"sm2-5y-r05-phy-07","oldQuestion":"不整脈のある患者で1分間に心尖部で聴取した心拍数が96回、同時に触れた橈骨動脈の脈拍数が78回だった。このときの脈拍欠損（pulse deficit）は何回/分か。","oldCorrect":"18回/分","newQuestion":"脈拍欠損を『同時に測定した心尖部心拍数から橈骨動脈の脈拍数を引いた値』と定義する。不整脈のある患者で、心尖部で96回/分、橈骨動脈で78回/分を測定したとき、脈拍欠損はいくつか。","newExplanation":"設問に脈拍欠損の定義を明記したため、96−78＝18回/分と計算できる。肢1の0、肢2の78、肢4の96、肢5の174はいずれも定義式を満たさない。元出典『Clinical Methods: Pulse』は政府が執筆した教材ではないため、公式の診察定義による独立再確認まで公開しない。"}];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const e of edits){const q=byId.get(e.id);
 if(!q||q.question!==e.oldQuestion||!Array.isArray(q.choices)||q.choices.length!==5||q.choices[q.answer-1]!==e.oldCorrect||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2 B rewrite expected old state '+e.id);
 if(e.newQuestion)q.question=e.newQuestion;
 if(e.newCorrect){q.choices=[...q.choices];q.choices[q.answer-1]=e.newCorrect;q.quick=e.newCorrect;}
 q.explanation=e.newExplanation;
 if(e.basis)q.basis=String(q.basis||'')+' ／ '+e.basis;
 if(e.source)q.sourceUrl=e.source;
 q.contentReviewStatus='requires-independent-subject-expert-review';q.auditStatus='再監査待ち';q.publicationStatus='非公開';
 if(q.lawRelated)q.legalChecked=null;
 if(new Set(q.choices).size!==5)throw Error('HM2 B rewrite duplicate choices '+e.id);
}
window.HM2_B_SCOPED_REWRITES_20261122=edits.map(x=>x.id);
})();


(function(){
'use strict';
// HM2 B2 2026-11-22: narrow an oxidative-phosphorylation claim to NLM-authored source.
// Deliberately invalidates publication approval; release JSON must be regenerated and re-audited.
const id='sm2-5y-r06-phy-08';
const qs=(window.Q_PARTS||[]).filter(q=>q.id===id);
if(qs.length!==1)throw Error('HM2 B2 ATP expected one question '+id);
const q=qs[0];
const oldCorrect='酸素を電子伝達系の最終電子受容体として利用し、酸化的リン酸化でATPを合成する。';
const newCorrect='ミトコンドリアで酸素を利用し、ATP合成酵素がプロトンの流れのエネルギーを使ってATPを生成する。';
const oldSource='https://www.ncbi.nlm.nih.gov/books/NBK553192/';
if(!Array.isArray(q.choices)||q.choices.length!==5||q.answer!==4||q.choices[3]!==oldCorrect||q.sourceUrl!==oldSource)
 throw Error('HM2 B2 ATP old state mismatch '+id);
q.choices=[...q.choices];q.choices[3]=newCorrect;
q.quick=newCorrect;
q.explanation='NLM MedlinePlus Genetics「MT-ATP6 gene」Normal Functionは、ミトコンドリアが酸素と糖を利用して酸化的リン酸化でATPを生成し、ATP合成酵素が内膜を通るプロトンの流れのエネルギーを利用してADPからATPを合成すると説明する。肢1は酸素消費を細胞質の解糖系に誤配置、肢2は酸素利用を否定し乳酸を最終受容体とする、肢3はATP合成酵素とプロトン流を無関係とする、肢5は十分な酸素下のATP産生停止を断定している点で不適切。元の正答肢の「最終電子受容体」は当該資料に直接明記されないため正答要件から外した。';
q.topic='ミトコンドリアの酸化的リン酸化とプロトン流によるATP合成';
q.sourceUrl='https://medlineplus.gov/genetics/gene/mt-atp6/';
q.basis=String(q.basis||'')+' ／ 2026-11-22 B2 NLM MedlinePlus Genetics MT-ATP6 Normal Function (US National Library of Medicine original editorial): oxygen use in oxidative phosphorylation and ATP synthase utilization of proton flux. No claim of terminal electron acceptor from this source.';
q.contentReviewStatus='requires-independent-subject-expert-review';
q.auditStatus='再監査待ち';
q.publicationStatus='非公開';
if(new Set(q.choices).size!==5||q.choices[3]!==newCorrect)throw Error('HM2 B2 ATP choice uniqueness failed');
window.HM2_B2_ATP_REDESIGN_ID=id;
})();


(function(){
'use strict';
// B2 source-only corrections backed by the original issuing public bodies.
// This does NOT grant publication clearance or prove a deterministic rebuild.
const fixes=[
 {id:'sm2-5y-r06-phy-10',old:'https://www.ncbi.nlm.nih.gov/books/NBK594995/',url:'https://www.gesundheitsinformation.de/wie-wird-der-herzrhythmus-gesteuert.html',basis:'IQWiG original public-body authored health information (German): sinus node, atrial conduction, AV node, His bundle, bundle branches and Purkinje fibers; original 5 alternatives distinguish conduction from vessels.'},
 {id:'sm2-5y-r07-phy-10',old:'https://www.ncbi.nlm.nih.gov/books/NBK556043/',url:'https://ntp.niehs.nih.gov/sites/default/files/ntp/ohat/lead/final/monographhealtheffectslowlevellead_newissn_508.pdf',basis:'US National Toxicology Program/NIEHS own monograph section 5.2.1 explicitly identifies phagocytic activity of neutrophils and macrophages; not a third-party StatPearls chapter.'}
];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
 const q=byId.get(f.id);
 if(!q||q.sourceUrl!==f.old||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)throw Error('HM2 B2 public source old-state mismatch '+f.id);
 q.sourceUrl=f.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 B2出典確認：'+f.basis;
}
window.HM2_B2_AUTHORITATIVE_SOURCE_IDS=fixes.map(x=>x.id);
})();


(function(){
'use strict';
// B2 original government-authored primary source improvements; source metadata only.
// Neither this patch nor an audit PASS is a release authorization.
const fixes=[
 {id:'sm2-5y-r05-phy-07',old:'https://www.ncbi.nlm.nih.gov/books/NBK278/',url:'https://files.eric.ed.gov/fulltext/ED227275.pdf',answer:3,
  basis:'US Air Force Training Command original Medical Service Specialist curriculum 1975, ERIC ED227275, APICAL/RADIAL PULSE unit: apical and radial beats counted simultaneously for one minute, pulse deficit defined as absent radial pulses relative to heart beats. The question itself explicitly defines deficit as apical minus radial: 96-78=18. ERIC is a repository, but the named actual author is the US Air Force.'},
 {id:'sm2-5y-r05-phy-04',old:'https://www.ncbi.nlm.nih.gov/sites/books/NBK30/',url:'https://www.niddk.nih.gov/news/archive/2013/new-mechanism-proposed-glucose-lowering-effect-metformin-drug-type-2-diabetes',answer:4,
  basis:'NIDDK own 2013 editorial: glucagon increases liver glucose output and insulin secreted after meals works in opposition. NLM independently edited MedlinePlus Genetics GCK gene Normal Function https://medlineplus.gov/genetics/gene/gck/ states liver glucokinase permits excess glucose uptake and glycogen storage; considered together they support liver reduced glucose output and increased glycogen storage under fed-insulin conditions. No third-party NCBI textbook is claimed to be government authored.'}
];
const map=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
const q=map.get(f.id);
if(!q||q.sourceUrl!==f.old||q.answer!==f.answer||!Array.isArray(q.choices)||q.choices.length!==5||q.choices.length!==new Set(q.choices).size)throw Error('HM2 B2 original government source old-state mismatch '+f.id);
q.sourceUrl=f.url;
q.basis=String(q.basis||'')+' ／ 2026-11-22 B2一次出典検証：'+f.basis;
}
window.HM2_B2_GOVERNMENT_SOURCE_FIX_IDS=fixes.map(x=>x.id);
})();


(function(){
'use strict';
// B2 government-original source scope revision: avoid asserting a causal insulin-to-glycogen
// link that the cited NIDDK/NLM public explanations do not state in the same clause.
const id='sm2-5y-r05-phy-04';
const qs=(window.Q_PARTS||[]).filter(x=>x.id===id);
if(qs.length!==1)throw Error('HM2 B2 liver expected one question');
const q=qs[0];
const prev='インスリンの作用により肝糖産生が抑制され、グリコーゲン合成が促される。';
const next='食後には肝臓からの糖放出が抑制される方向に働き、肝臓に取り込まれた余剰の糖はグリコーゲンとして貯蔵され得る。';
const official='https://www.niddk.nih.gov/news/archive/2013/new-mechanism-proposed-glucose-lowering-effect-metformin-drug-type-2-diabetes';
if(!Array.isArray(q.choices)||q.choices.length!==5||q.answer!==4||q.choices[3]!==prev||q.sourceUrl!==official)throw Error('HM2 B2 liver expected old-state mismatch');
q.choices=[...q.choices];q.choices[3]=next;q.quick=next;
q.explanation='NIDDK公式2013年解説は、空腹時にグルカゴンが肝臓から糖を放出させ、食後に分泌されるインスリンがそれと対抗する作用を持つと説明する。NLM MedlinePlus Genetics GCK gene Normal Function は、肝臓のグルコキナーゼが過剰な糖を取り込みグリコーゲンへ変換する際に働くと明記。よって肢4の条件付き記載が適切。肢1は食後のグルカゴン促進を必然視し、肢2は肝糖放出増加、肢3は肝臓の調節不能、肢5は食後にインスリンが肝糖放出を増やすと逆転させているため不適切。インスリンだけがグリコーゲン合成を直接決定するとの単因果は断定しない。';
q.topic='食後の肝糖放出調節とグリコーゲン貯蔵';
q.basis=String(q.basis||'')+' ／ B2正答命題限定：NIDDK postmeal glucagon-insulin opposition and NLM GCK normal function, https://medlineplus.gov/genetics/gene/gck/';
q.contentReviewStatus='requires-independent-subject-expert-review';q.auditStatus='再監査待ち';q.publicationStatus='非公開';
if(new Set(q.choices).size!==5)throw Error('HM2 B2 liver duplicate choice');
window.HM2_B2_LIVER_FOCUSED_REVISION=id;
})();


(function(){
'use strict';
// 2026-11-22 B2 official Japan MHLW-based workplace health information source precision.
// No assumption that individual health exams obey stress-test group size law.
const changes=[
 {id:'sm2-5y-r10-hyg-04',old:'https://www.mhlw.go.jp/content/000922318.pdf',url:'https://www.mhlw.go.jp/content/000922318.pdf',answer:2,
 basis:'厚生労働省2022年改正「労働者の心身の状態に関する情報の適正な取扱い指針」第2項の取扱権限、必要範囲、情報の加工・管理。群馬労働局公式健康診断解説 https://jsite.mhlw.go.jp/gunma-roudoukyoku/hourei_seido_tetsuzuki/anzen_eisei/anzen17/kenkoushindan.html は健診結果の経時的総合把握と作業管理へのフィードバックを説明。ストレスチェック集団分析の法定要件とは区別する。'},
 {id:'sm2-5y-r10-hyg-08',old:'https://laws.e-gov.go.jp/law/347AC0000000057',url:'https://www.mhlw.go.jp/web/t_doc?dataId=00tc2624&dataType=1&pageNo=1',answer:4,
 basis:'厚生労働省2017年4月14日基発0414第2号、健康診断結果に基づく措置指針：作業環境、労働時間、深夜業回数、作業負荷、過去の健診結果を総合して医師に提供。群馬労働局公式健康診断解説は健康指標の経時的変化と作業管理・環境管理へのフィードバック。集団分析の特定手法を法定義務と誤記しない。'}
];
const map=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const c of changes){
 const q=map.get(c.id);
 if(!q||q.sourceUrl!==c.old||q.answer!==c.answer||!Array.isArray(q.choices)||q.choices.length!==5||new Set(q.choices).size!==5)throw Error('HM2 B2 hygiene source old-state mismatch '+c.id);
 q.sourceUrl=c.url;
 q.basis=String(q.basis||'')+' ／ 2026-11-22 B2厚労省原典照合：'+c.basis;
}
window.HM2_B2_MHLW_HYGIENE_SOURCE_IDS=changes.map(x=>x.id);
})();


(function(){
'use strict';
// HM2 B2 original NLM editorial on reflexes: source-only, no publication approval.
const id='sm2-5y-r08-phy-01';
const q=(window.Q_PARTS||[]).find(x=>x.id===id);
const old='https://www.ncbi.nlm.nih.gov/books/NBK544292/';
if(!q||q.sourceUrl!==old||q.answer!==2||!Array.isArray(q.choices)||q.choices.length!==5)throw Error('HM2 B2 reflex source stale');
q.sourceUrl='https://medlineplus.gov/lab-tests/neurological-exam/';
q.basis=String(q.basis||'')+' ／ NLM自身が編集したMedlinePlus Medical Test Neurological Exam: reflexes are automatic body movements in response to triggers, spinal cord and peripheral nerves control reflex and motor responses; heat is a sensory trigger. This is not a third-party MedlinePlus Medical Encyclopedia page.';
window.HM2_B2_REFLEX_SOURCE_ID=id;
})();


(function(){
'use strict';
// B2 pulse question narrowing to NHLBI authored wording, preserve position, fail closed.
const id='sm2-5y-r05-phy-06';
const q=(window.Q_PARTS||[]).find(x=>x.id===id);
const prev='心拍に伴う動脈壁の圧力変動が末梢へ伝わったもの';
const next='心臓が血液を送り出すときに生じる動脈の拍動を、手首で触知しているもの';
if(!q||q.sourceUrl!=='https://www.ncbi.nlm.nih.gov/books/NBK542175/'||q.answer!==1||!Array.isArray(q.choices)||q.choices.length!==5||q.choices[0]!==prev)throw Error('HM2 B2 pulse mechanism stale state');
q.choices=[...q.choices];q.choices[0]=next;
q.quick=next;
q.explanation='米国NHLBI公式「How the Heart Beats」では、心拍は心臓の収縮により血液を送り出す働きであり、手首の動脈で触れた拍動を数えて脈拍数を把握すると記載する。肢1が適切。肢2は肺胞のガス交換、肢3は静脈の流速測定、肢4は消化管運動、肢5は毛細血管凝固であり脈拍の触知ではない。原典が直接記述しない脈波の物理伝播機序はこの設問の正答から除外した。';
q.sourceUrl='https://www.nhlbi.nih.gov/health/heart/heart-beats';
q.topic='心拍と手首動脈で触知する脈拍';
q.basis=String(q.basis||'')+' ／ 2026-11-22 B2 NHLBI original clinical health page, What is a normal pulse / Blood pressure sections; heart pumping causes palpable pulse at wrist; propagation dynamics excluded.';
q.contentReviewStatus='requires-independent-subject-expert-review';q.auditStatus='再監査待ち';q.publicationStatus='非公開';
if(new Set(q.choices).size!==5)throw Error('HM2 B2 pulse duplicate choices');
window.HM2_B2_PULSE_NARROWED_ID=id;
})();


(function(){
'use strict';
// UK public NHS hospital authored clinical skills source (2022-23), no third-party NCBI inference.
const id='sm2-5y-r08-phy-10',old='https://www.ncbi.nlm.nih.gov/books/NBK553169/';
const q=(window.Q_PARTS||[]).find(x=>x.id===id);
if(!q||q.sourceUrl!==old||q.answer!==4||!Array.isArray(q.choices)||q.choices.length!==5)throw Error('HM2 B2 pupil source stale');
q.sourceUrl='https://uhmeded.uhcw.nhs.uk/Portals/0/AssetUploads/CHESS%20Book%20Clinical%20Skills%20Workbook%202022-23.pdf?ver=ELcRsPPRSWHk3baBgJ2INQ%3D%3D';
q.basis=String(q.basis||'')+' ／ 2026-11-22 University Hospitals Coventry and Warwickshire NHS Trust clinical skills workbook pp57-58 (Cranial Nerve 2), Check pupillary light reflexes: illumination of one eye causes directly stimulated pupil to constrict and the other pupil to constrict consensually. Published directly by NHS clinical education provider; PDF text confirmed, screenshot retrieval unsuccessful.';
window.HM2_B2_PUPIL_NHS_SOURCE_ID=id;
})();


(function(){
'use strict';
// B2 anaerobic muscle ATP: use government-authored 1996 Surgeon General CDC report.
const id='sm2-5y-r09-phy-06',old='https://www.ncbi.nlm.nih.gov/books/NBK546695/';
const q=(window.Q_PARTS||[]).find(v=>v.id===id);
if(!q||q.sourceUrl!==old||q.answer!==5||!Array.isArray(q.choices)||q.choices.length!==5)throw Error('HM2 B2 anaerobic source mismatch');
q.sourceUrl='https://stacks.cdc.gov/view/cdc/11223/cdc_11223_DS1.pdf';
q.basis=String(q.basis||'')+' ／ U.S. HHS CDC original 1996 Physical Activity and Health: A Report of the Surgeon General, Chapter 3 Skeletal Muscle Energy Metabolism, printed pp65–66: muscle oxygen demand may exceed supply during all-out exercise; anaerobic glycolytic system produces ATP without oxygen for approx 30 s–2 min; lactate buildup contributes duration limitation; oxidative system requires oxygen. Source itself is government-authored (not third-party stored on CDC).';
window.HM2_B2_GOVERNMENT_ANAEROBIC_SOURCE_ID=id;
})();
