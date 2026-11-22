(function(){
'use strict';
// Reconcile 10 official-source citation refinements into canonical generator;
// wording, five choices, answers, and release/audit approval status are unchanged.
const patches=[
  {
    "id": "sm2-5y-r04-phy-03",
    "expected": {
      "question": "安静時の心拍数が70回/分、一回拍出量が70mLの成人について、心拍出量をL/分で求めるとどれか。",
      "answerText": "約4.9L/分。"
    },
    "next": {
      "sourceUrl": "https://evs.nci.nih.gov/ftp1/CDISC/SDTM/Archive/SDTM%20Terminology%202015-09-25.pdf",
      "basis": "循環生理：心拍出量＝心拍数×一回拍出量 ／ 2026-11-22出典照合：NHLBI BioLINCC HFN-RELAX research protocol, section 14.2.5 p23 (PDF p28): cardiac output = stroke volume x heart rate. Example 70 mL x 70/min = 4.9 L/min. Note this is a hosted study protocol, not NIH clinical guidance. ／ 2026-11-22 HM2-B追加根拠：NCI EVS公開のCDISC統制用語C119246ではCardiac OutputをCO=HR×SVと定義。70回/分×70mL/回=4900mL/分=4.9L/分。CDISC標準が原出典でありNIHが独自執筆した解説とは区別する。"
    }
  },
  {
    "id": "sm2-5y-r04-phy-10",
    "expected": {
      "question": "安静時に呼吸が浅くなり、動脈血の二酸化炭素分圧が上昇した。一般に呼吸中枢への影響として適切なのはどれか。",
      "answerText": "二酸化炭素の増加に伴う化学受容器からの刺激が換気を増やす方向に働く。"
    },
    "next": {
      "sourceUrl": "https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf",
      "basis": "呼吸生理・中枢と末梢の化学受容器と換気応答 ／ 2026-11-22出典照合：NIOSH official 1976 Criteria for a Recommended Standard, Occupational Exposure to Carbon Dioxide, pp23-24 (PDF indices 31-32): CO2 increases hydrogen ion chemoreceptor response and ventilation; high toxic levels may suppress respiration."
    }
  },
  {
    "id": "sm2-5y-r05-phy-03",
    "expected": {
      "question": "運動中に筋肉が大量の酸素を消費して二酸化炭素を生じた。肺で二酸化炭素が血液から肺胞へ移動する主な駆動力はどれか。",
      "answerText": "肺毛細血管血と肺胞気との二酸化炭素分圧差。"
    },
    "next": {
      "sourceUrl": "https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf",
      "basis": "呼吸生理・肺胞ガス交換の分圧勾配 ／ 2026-11-22出典照合：NIOSH 1976 government report printed p22 PDF index30: pulmonary blood 46 mmHg CO2 versus alveolar 40 mmHg, transfer via partial-pressure gradient."
    }
  },
  {
    "id": "sm2-5y-r05-phy-10",
    "expected": {
      "question": "脂質を含む食物が小腸に入り、膵液による消化が進んでいる。中性脂肪の加水分解を主に担う膵由来の消化酵素はどれか。",
      "answerText": "膵リパーゼ"
    },
    "next": {
      "sourceUrl": "https://medlineplus.gov/lab-tests/lipase-tests/",
      "basis": "消化器生理・膵外分泌と脂質消化 ／ 出典精密化2026-11-22：NLM MedlinePlus Lipase Tests: lipase is pancreatic digestive enzyme for fats; pancreatic lipase / fat digestion."
    }
  },
  {
    "id": "sm2-5y-r06-phy-02",
    "expected": {
      "question": "安静呼吸で息を吸う際、横隔膜が収縮することで胸腔内の容積と圧に生じる変化はどれか。",
      "answerText": "胸腔容積が増え、肺内圧が低下して空気が流入する。"
    },
    "next": {
      "sourceUrl": "https://www.nhlbi.nih.gov/health/lungs/body-controls-breathing",
      "basis": "呼吸運動の力学・陰圧吸気 ／ 出典精密化2026-11-22：NHLBI breathing mechanics: contraction produces lower pressure and inflow."
    }
  },
  {
    "id": "sm2-5y-r07-phy-01",
    "expected": {
      "question": "副腎皮質ホルモンの一つが増加した。腎でのナトリウム再吸収を促進し、カリウム排泄にも影響するホルモンはどれか。",
      "answerText": "アルドステロン"
    },
    "next": {
      "sourceUrl": "https://medlineplus.gov/lab-tests/aldosterone-test/",
      "basis": "内分泌・体液の生理 ／ 2026-11-22出典照合：NLM MedlinePlus official Aldosterone Test section What is an aldosterone test: adrenal aldosterone restores kidney sodium and potassium balances, sodium retention and potassium excretion."
    }
  },
  {
    "id": "sm2-5y-r07-phy-06",
    "expected": {
      "question": "健康な成人が食後しばらくして血糖が低下し始めた。肝臓にはまだグリコーゲンの蓄えがある。このとき血糖維持に向けて比較的速やかに働くホルモンと肝臓の反応の組合せとして、適切なものはどれか。",
      "answerText": "グルカゴンの分泌増加により肝グリコーゲン分解が促進される。"
    },
    "next": {
      "sourceUrl": "https://dailymed.nlm.nih.gov/dailymed/getFile.cfm?setid=8cc40354-b5ac-45b6-a211-93b44444f2a3&type=pdf",
      "basis": "内分泌・糖代謝の生理／短時間空腹時のグルカゴンによる肝グリコーゲン分解 ／ 出典精密化2026-11-22：NLM DailyMed approved glucagon label sec 12.1: glycogenolysis and liver glycogen stores condition."
    }
  },
  {
    "id": "sm2-5y-r07-phy-09",
    "expected": {
      "question": "遠くの標識から近くの文字へ視線を移したとき、ピント調節に加えて起こる正常な両眼の反応として最も適切な組合せはどれか。",
      "answerText": "両眼は内側へ輻輳し、瞳孔は縮小する。"
    },
    "next": {
      "sourceUrl": "https://www.nei.nih.gov/research-and-training/research-news/novel-population-neurons-identified-control-binocular-eye-movements-3d-space",
      "basis": "NCBI StatPearls『Physiology, Accommodation』近見反射の輻輳・縮瞳 ／ 出典精密化2026-11-22：NEI 2020 near triad: accommodation, pupillary constriction, vergence; combined with NEI convergence insufficiency near vision."
    }
  },
  {
    "id": "sm2-5y-r10-phy-04",
    "expected": {
      "question": "成人の腎臓で、原尿中に含まれたブドウ糖が通常ほぼ再吸収される主な部位はどれか。",
      "answerText": "近位尿細管。"
    },
    "next": {
      "sourceUrl": "https://www.niddk.nih.gov/news/archive/2016/story-discovery-sglt2-inhibitors-harnessing-kidneys-help-treat-diabetes",
      "basis": "腎生理・近位尿細管のブドウ糖再吸収 ／ 出典精密化2026-11-22：NIDDK 2016 SGLT2 discovery report: glucose reclamation along earlier proximal tubule; governmental own editorial."
    }
  },
  {
    "id": "sm2-5y-r10-phy-09",
    "expected": {
      "question": "安静時に血液中の二酸化炭素が増加した。血液の酸塩基平衡における直接の変化として適切なのはどれか。",
      "answerText": "炭酸系の平衡により水素イオンが増え、pHが低下する方向に働く。"
    },
    "next": {
      "sourceUrl": "https://stacks.cdc.gov/view/cdc/19367/cdc_19367_DS1.pdf",
      "basis": "呼吸生理・重炭酸緩衝系と酸塩基平衡 ／ 2026-11-22出典照合：NIOSH 1976 government report printed pp22-23 PDF indices30-31: CO2 + H2O <=> H2CO3 <=> H+ + HCO3, Henderson-Hasselbalch acidification."
    }
  }
];
if(patches.length!==10||new Set(patches.map(p=>p.id)).size!==10)throw Error('HM2 EVIDENCE_V2_SCOPE');
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of patches){
 const q=byId.get(f.id);
 if(!q||q.question!==f.expected.question||!Array.isArray(q.choices)||q.choices[q.answer-1]!==f.expected.answerText||!/^https:\/\//.test(String(q.sourceUrl)))throw Error('HM2 EVIDENCE_V2_OLD_STATE '+f.id);
 q.sourceUrl=f.next.sourceUrl;
 q.basis=f.next.basis;
}
window.HM2_EVIDENCE_V2_UPDATED_IDS=patches.map(p=>p.id);
})();


// Q1 difficulty-format repair: a display-only paired-judgment label for the
// already reviewed 2026-08-01 industrial-physician resignation question.
// The five original proposition sentences, correct answer and explanations
// remain unchanged; this prefix must not confer any new legal review approval.
(function () {
  'use strict';
  const q=(window.Q_PARTS||[]).find(x=>x.id==='sm2-5y-r05-law-10');
  const expectedTopic='産業医の辞任等の報告';
  const expectedCorrect='辞任の旨と理由を遅滞なく衛生委員会等に報告し、産業医の氏名・辞任年月日等を遅滞なく所轄労働基準監督署長に報告する。';
  if (!q || q.topic!==expectedTopic || q.answer!==3 ||
      q.difficultyModel!=='exam-paired-judgment-v1' || q.stemRedesignBatch ||
      !Array.isArray(q.choices) || q.choices.length!==5 ||
      q.choices[2]!==expectedCorrect ||
      q.choices.some(c=>typeof c!=='string'||c.includes(' ― '))) {
    throw new Error('HM2 R05 LAW10 Q1 format patch stale input');
  }
  // Exactly the same statements, with the topic printed as a common label.
  q.choices=q.choices.map(c=>expectedTopic+' ― '+c);
  if(q.choices.length!==5 || new Set(q.choices).size!==5 ||
     !q.choices.every(c=>c.includes(' ― ')) ||
     !q.choices[q.answer-1].startsWith(q.topic+' ― ')) {
    throw new Error('HM2 R05 LAW10 Q1 paired-judgment format mismatch');
  }
  window.HM2_R05_LAW10_Q1_FORMAT_FIX=true;
})();
