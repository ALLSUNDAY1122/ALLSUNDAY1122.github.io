(function(){
'use strict';
// C high-risk original-text redesign; not approved for publication.
// Fail closed on stale source and clear prior legal/audit approval.
const fixes=[
  {
    "id": "sm2-demo-001",
    "expected": {
      "question": "衛生管理者の選任人数に関する次の記述のうち、法令上、正しいものはどれか。",
      "correctText": "常時1,500人の労働者を使用する事業場では、衛生管理者を4人以上選任する。",
      "sourceUrl": "https://www.mhlw.go.jp/web/t_doc?dataId=74003000&dataType=0"
    },
    "next": {
      "question": "常時120人が働く情報サービス業の事業場で、衛生管理者の業務を行う者を選任する。適切な考え方はどれか。",
      "choices": [
        "人数が50人未満でない限り衛生管理者制度は適用されない",
        "必要な資格を有する者を選任し、事業場の衛生管理業務を担わせる",
        "安全管理者の資格があれば衛生管理者の資格要件を確認する必要はない",
        "選任は同一企業の全国従業員数だけを基準にする",
        "衛生委員会を設ければ衛生管理者の選任義務は消える"
      ],
      "answer": 2,
      "explanation": "衛生管理者は事業場単位の衛生管理体制の一員。業種に応じた免許・資格要件と選任義務を個別に確認する。",
      "quick": "衛生管理者は事業場単位の衛生管理体制の一員。",
      "basis": "2026-11-22一次照合：厚労省『衛生管理者について教えて下さい』、安衛法12条・安衛則7条。常時50人以上で事業場ごとに衛生管理者選任、情報サービス業では業種に応じた資格確認が必要。選択肢4肢の無条件免除/全国人数/資格代替は不適切。",
      "sourceUrl": "https://www.mhlw.go.jp/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/5.html",
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "legalChecked": "2026-11-22"
    }
  },
  {
    "id": "sm2-demo-002",
    "expected": {
      "question": "産業医に関する次の記述のうち、法令上、正しいものはどれか。",
      "correctText": "産業医が辞任したとき、事業者は遅滞なく、その旨と理由を衛生委員会等に報告する。",
      "sourceUrl": "https://www.mhlw.go.jp/web/t_doc?dataId=00td0095&dataType=1&pageNo=1"
    },
    "next": {
      "question": "産業医が職場巡視で健康障害の危険を見つけ、改善の必要性を事業者に伝えた。事業者の対応として適切なのはどれか。",
      "choices": [
        "産業医の指摘はすべて非公開として扱い、職場改善には使わない",
        "産業医への情報提供は法律上常に禁止される",
        "産業医は職場環境に関する事項を扱えない",
        "産業医の勧告を受けたら衛生委員会を解散する",
        "衛生管理体制と連携して必要な改善を検討する"
      ],
      "answer": 5,
      "explanation": "産業医は労働者の健康管理等について専門的立場から助言する。事業者は必要な衛生管理・健康障害防止対策を検討する。",
      "quick": "産業医は労働者の健康管理等について専門的立場から助言する。",
      "basis": "2026-11-22一次照合：労働安全衛生法13条3〜6項（厚労省法令本文）。産業医の誠実な職務・事業者の情報提供・勧告尊重と委員会報告が定められ、改善検討と反対の4肢は不適切。",
      "sourceUrl": "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/faq/newpage_50446.html",
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "legalChecked": "2026-11-22"
    }
  },
  {
    "id": "sm2-demo-003",
    "expected": {
      "question": "労働衛生コンサルタントに関する次の記述のうち、正しいものはどれか。",
      "correctText": "他人の求めに応じ報酬を得て、事業場の衛生について診断し、これに基づく指導を行うことを業とする。",
      "sourceUrl": "https://www.mhlw.go.jp/web/t_doc?dataId=74001000&dataType=0"
    },
    "next": {
      "question": "工場の換気改善について外部の労働衛生コンサルタントに診断を依頼した。診断後の行動として適切なのはどれか。",
      "choices": [
        "改善案を事業場の条件に照らして検討し、必要な措置に結び付ける",
        "診断は行政の立入検査と同じなので改善検討は不要",
        "コンサルタントの助言があれば衛生管理者の選任義務はなくなる",
        "診断依頼後は労働者に対する健康障害防止義務がなくなる",
        "診断結果は労働衛生と無関係な営業目標としてのみ扱う"
      ],
      "answer": 1,
      "explanation": "専門家の診断は作業環境や衛生管理の改善判断に役立てるものであり、事業者の法令上の義務を代替しない。",
      "quick": "専門家の診断は作業環境や衛生管理の改善判断に役立てるものであり、事業者の法令上の義務を代替しない。",
      "basis": "2026-11-22一次照合：労働安全衛生法81条2項（厚労省法令本文）、事業者の安全衛生確保義務。同コンサルタントの業務は診断とこれに基づく指導で、事業者の義務消滅や行政検査と同一とはならない。",
      "sourceUrl": "https://www.mhlw.go.jp/web/t_doc?dataId=74001000&dataType=0",
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "legalChecked": "2026-11-22"
    }
  }
];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
for(const f of fixes){
 const q=byId.get(f.id);
 if(!q||q.question!==f.expected.question||!Array.isArray(q.choices)||q.choices[q.answer-1]!==f.expected.correctText||q.sourceUrl!==f.expected.sourceUrl)throw Error('HM2 C replacement stale source '+f.id);
 Object.assign(q,f.next);
 if(q.lawRelated&&(!q.legalChecked||q.publicationStatus==='公開候補'))throw Error('HM2 C legal gate bypass '+f.id);
}
window.HM2_C_REPLACEMENT_IDS=fixes.map(f=>f.id);
})();
