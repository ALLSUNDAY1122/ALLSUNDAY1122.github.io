(function(){
'use strict';
// C remaining 13: original-scenario redesign; hold from publication until independent review.
const patches=[
  {
    "id": "sm2-demo-014",
    "expected": {
      "question": "実効温度とWBGTについての記述のうち、誤っているものはどれか。",
      "answerText": "実効温度は放射熱だけを測定する指標であり、気温・湿度・気流を考慮しない。",
      "sourceUrl": "https://www.exam.or.jp/wp-content/uploads/2026/04/LC20260414.pdf"
    },
    "next": {
      "question": "日射がない屋内で自然湿球温度26℃、黒球温度34℃だった。WBGTに最も近い値はどれか。",
      "choices": [
        "26.0℃",
        "28.4℃",
        "30.0℃",
        "32.4℃",
        "34.0℃"
      ],
      "answer": 2,
      "explanation": "日射のない屋内のWBGT＝0.7×自然湿球温度＋0.3×黒球温度。26×0.7＋34×0.3＝28.4℃。",
      "quick": "日射のない屋内のWBGT＝0.7×自然湿球温度＋0.3×黒球温度。",
      "basis": "2026-11-22環境省『暑さ指数（WBGT）の詳しい説明』屋内算出式（0.7×自然湿球＋0.3×黒球）の計算問題。法令適用・施行日の判断は問わないためlawRelated=false。26×0.7+34×0.3=28.4。権利と出題再監査は未完了。",
      "sourceUrl": "https://www.wbgt.env.go.jp/doc_observation.php",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review",
      "lawRelated": false
    }
  },
  {
    "id": "sm2-demo-015",
    "expected": {
      "question": "2026年10月19日改正のTHP指針に関する記述として、正しいものはどれか。",
      "answerText": "健康診断等を通じた疾病の早期発見に加え、がん検診等の受診勧奨や治療と就業の両立支援も位置づけられた。",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html"
    },
    "next": {
      "question": "職場がTHPに基づく健康保持増進計画を見直している。従来の運動指導に加えて検討すべき取組はどれか。",
      "choices": [
        "二次予防に当たる受診勧奨を一律禁止する",
        "健康診断をすべて任意の運動教室へ置き換える",
        "医療保険者等との協力や、治療を続ける労働者の就業環境への配慮を検討する",
        "疾病がある労働者への支援を必ず中止する",
        "職場の実情にかかわらず全員を同一の医療行為へ参加させる"
      ],
      "answer": 3,
      "explanation": "2026年10月19日改正のTHP指針では二次予防や医療保険者との連携、治療と就業の両立支援も重視される。法定健診義務は別に存続する。",
      "quick": "2026年10月19日改正のTHP指針では二次予防や医療保険者との連携、治療と就業の両立支援も重視される。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-demo-028",
    "expected": {
      "question": "体温調節に関する次の記述のうち、誤っているものはどれか。",
      "answerText": "不感蒸泄とは呼気から失われる水分だけをいい、皮膚からの水分喪失は含まない。",
      "sourceUrl": "https://www.msdmanuals.com/ja-jp/professional/10-%E5%86%85%E5%88%86%E6%B3%8C%E7%96%BE%E6%82%A3%E3%81%A8%E4%BB%A3%E8%AC%9D%E6%80%A7%E7%96%BE%E6%82%A3/%E6%B0%B4%E4%BB%A3%E8%AC%9D/%E6%B0%B4%E3%81%A8%E3%83%8A%E3%83%88%E3%83%AA%E3%82%A6%E3%83%A0%E3%81%AE%E5%B9%B3%E8%A1%A1"
    },
    "next": {
      "question": "ある作業者は1時間に0.60Lの汗をかき、同じ時間に0.40Lの水分を補給した。他の水分移動を考慮しないとき、体内水分の収支はどうなるか。",
      "choices": [
        "0.20L減る",
        "1.00L増える",
        "変化しない",
        "0.20L増える",
        "1.00L減る"
      ],
      "answer": 1,
      "explanation": "補給0.40L−発汗0.60L＝−0.20L。実際の作業では尿や不感蒸泄もあり、水分管理は他の条件も踏まえて行う。",
      "quick": "補給0.40L−発汗0.60L＝−0.20L。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/koyou_roudou/roudoukijun/anzeneisei/heatstroke/index.html",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-demo-029",
    "expected": {
      "question": "抗体が中心となって病原体などに作用する獲得免疫はどれか。",
      "answerText": "体液性免疫",
      "sourceUrl": "https://www.msdmanuals.com/ja-jp/home/multimedia/table/%E4%B8%BB%E3%81%AA%E5%8E%9F%E7%99%BA%E6%80%A7%E5%85%8D%E7%96%AB%E4%B8%8D%E5%85%A8%E7%97%87"
    },
    "next": {
      "question": "あるワクチンの接種後、病原体に特異的な抗体の産生が増えた。この反応の中心となる細胞はどれか。",
      "choices": [
        "赤血球",
        "血小板",
        "脂肪細胞",
        "骨格筋細胞",
        "形質細胞"
      ],
      "answer": 5,
      "explanation": "B細胞が分化した形質細胞は抗体を分泌する。これは獲得免疫のうち体液性免疫の主要な仕組みである。",
      "quick": "B細胞が分化した形質細胞は抗体を分泌する。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.cancer.gov/publications/dictionaries/cancer-terms/def/plasma-cell",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review",
      "rightsBasis": "米国NIH国立がん研究所（NCI）の公式用語辞典が形質細胞は活性化B細胞から分化して特異的抗体を多量産生すると明記。科学的事実のみ参照し文章・図版の転載なし。"
    }
  },
  {
    "id": "sm2-r7a-030",
    "expected": {
      "question": "甲状腺ホルモンとその調節について、正しいものはどれか。",
      "answerText": "サイロキシン（T4）などの甲状腺ホルモンは代謝調節に関与し、その分泌は下垂体のTSHなどで調節される",
      "sourceUrl": "https://medlineplus.gov/lab-tests/tsh-thyroid-stimulating-hormone-test/"
    },
    "next": {
      "question": "甲状腺から分泌されるホルモンの量が減少した場合、通常の負のフィードバックが働くと下垂体からのTSH分泌はどの方向に変化しやすいか。",
      "choices": [
        "減少する",
        "変化しないことが必ず保証される",
        "増加する",
        "完全に停止する",
        "副腎髄質ホルモンに置き換わる"
      ],
      "answer": 3,
      "explanation": "甲状腺ホルモンが減少すると下垂体への負のフィードバックが弱まり、一般にTSHは増える方向に働く。疾患による例外には注意する。",
      "quick": "甲状腺ホルモンが減少すると下垂体への負のフィードバックが弱まり、一般にTSHは増える方向に働く。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://medlineplus.gov/lab-tests/tsh-thyroid-stimulating-hormone-test/",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-5y-r09-phy-01",
    "expected": {
      "question": "立ち上がる際に大腿四頭筋が収縮した。自分の意思で運動を起こし、横紋が見られる筋組織はどれか。",
      "answerText": "骨格筋",
      "sourceUrl": "https://medlineplus.gov/ency/imagepages/19841.htm"
    },
    "next": {
      "question": "自分の意思でペットボトルを持ち上げるとき、主に収縮して上肢の関節を動かす組織はどれか。",
      "choices": [
        "血管内皮",
        "心筋",
        "軟骨",
        "骨格筋",
        "腱そのもの"
      ],
      "answer": 4,
      "explanation": "随意運動で関節を動かす主な収縮組織は骨格筋。腱は筋の力を骨に伝えるが自ら能動的には収縮しない。",
      "quick": "随意運動で関節を動かす主な収縮組織は骨格筋。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.ncbi.nlm.nih.gov/books/NBK537140/",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-r7o-026",
    "expected": {
      "question": "血液の成分と機能について、正しいものはどれか。",
      "answerText": "赤血球中のヘモグロビンは酸素と可逆的に結合し、酸素運搬の中心的役割を担う",
      "sourceUrl": "https://www.msdmanuals.com/ja-jp/home/13-%E8%A1%80%E6%B6%B2%E3%81%AE%E7%97%85%E6%B0%97/%E8%B2%A7%E8%A1%80/%E3%83%98%E3%83%A2%E3%82%B0%E3%83%AD%E3%83%93%E3%83%B3c%E7%97%87-sc%E7%97%87-e%E7%97%87"
    },
    "next": {
      "question": "健診で酸素運搬能力の低下を疑われた人について、赤血球中のどの成分の不足が、酸素を運ぶ能力の低下に直接結びつきやすいか。",
      "choices": [
        "アルブミン",
        "ヘモグロビン",
        "フィブリノゲン",
        "トロンビン",
        "免疫グロブリン"
      ],
      "answer": 2,
      "explanation": "ヘモグロビンは赤血球内に存在し、酸素と可逆的に結合して運搬する。血漿タンパク質や凝固因子と区別する。",
      "quick": "ヘモグロビンは赤血球内に存在し、酸素と可逆的に結合して運搬する。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://medlineplus.gov/lab-tests/hemoglobin-test/",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-r7o-027",
    "expected": {
      "question": "自律神経系の作用について、一般的な組合せとして正しいものはどれか。",
      "answerText": "交感神経優位―心拍数増加・瞳孔散大・消化管運動抑制",
      "sourceUrl": "https://www.ncbi.nlm.nih.gov/books/NBK430888/table/article-18030.table1/"
    },
    "next": {
      "question": "強い緊張で心拍数が上がり瞳孔が広がった。この反応に関わる主な自律神経系はどれか。",
      "choices": [
        "副交感神経による心拍抑制",
        "脊髄運動神経の随意支配",
        "副交感神経による消化管運動促進",
        "交感神経系の活性化",
        "味覚受容体の刺激だけ"
      ],
      "answer": 4,
      "explanation": "交感神経優位では心拍が増え、瞳孔が散大する方向の反応がみられる。神経系の反応は臓器や条件に依存する。",
      "quick": "交感神経優位では心拍が増え、瞳孔が散大する方向の反応がみられる。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://pmc.ncbi.nlm.nih.gov/articles/PMC6380109/",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review",
      "rightsBasis": "査読レビュー（Frontiers in Neurology、PMC6380109）に交感神経系の活性化が心拍数増加・散瞳を生じるとの明記を確認。原著はCC BY、掲載文章・図表は転載せず、設問・5肢・解説を独自の日本語で保持。"
    }
  },
  {
    "id": "sm2-r7o-028",
    "expected": {
      "question": "骨格筋の収縮とエネルギー供給について、正しいものはどれか。",
      "answerText": "ミオシン頭部の運動にはATP加水分解のエネルギーが使われ、ATPはクレアチンリン酸や代謝によって再合成される",
      "sourceUrl": "https://www.ncbi.nlm.nih.gov/sites/books/NBK537140/"
    },
    "next": {
      "question": "短時間の強い筋活動でATPが急速に消費された。筋内でADPからATPを速やかに再生する反応にリン酸基を供給する物質はどれか。",
      "choices": [
        "クレアチンリン酸",
        "赤血球ヘモグロビン",
        "胆汁酸",
        "甲状腺刺激ホルモン",
        "血小板"
      ],
      "answer": 1,
      "explanation": "クレアチンリン酸はクレアチンキナーゼ反応を介してADPへのリン酸基供与に関わり、ATPを速やかに再生する。",
      "quick": "クレアチンリン酸はクレアチンキナーゼ反応を介してADPへのリン酸基供与に関わり、ATPを速やかに再生する。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://pmc.ncbi.nlm.nih.gov/articles/PMC4898252/",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-demo-022",
    "expected": {
      "question": "小腸が栄養素を効率よく吸収するための構造上の特徴として正しいものはどれか。",
      "answerText": "絨毛や微絨毛によって吸収面積が大きい",
      "sourceUrl": "https://www.msdmanuals.com/ja-jp/home/03-%E6%B6%88%E5%8C%96%E5%99%A8%E7%B3%BB%E3%81%AE%E7%97%85%E6%B0%97/%E6%B6%88%E5%8C%96%E5%99%A8%E7%B3%BB%E3%81%AE%E7%94%9F%E7%89%A9%E5%AD%A6/%E5%B0%8F%E8%85%B8"
    },
    "next": {
      "question": "食事後に小腸で吸収された水溶性のブドウ糖が、まず肝臓へ運ばれる主な血管経路はどれか。",
      "choices": [
        "肺動脈",
        "冠動脈",
        "胸管だけ",
        "尿管",
        "門脈"
      ],
      "answer": 5,
      "explanation": "小腸で吸収されたブドウ糖は主として腸管毛細血管から門脈を経て肝臓へ向かう。長鎖脂質のリンパ吸収と異なる。",
      "quick": "小腸で吸収されたブドウ糖は主として腸管毛細血管から門脈を経て肝臓へ向かう。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.niddk.nih.gov/health-information/digestive-diseases/digestive-system-how-it-works",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-demo-027",
    "expected": {
      "question": "明るい屋外から暗い室内へ入った直後は見えにくいが、しばらくすると見えるようになる。この現象は何か。",
      "answerText": "暗順応",
      "sourceUrl": "https://www.hql.jp/database/cat/senior/funcdb2000/%E8%A8%88%E6%B8%AC%E3%83%87%E3%83%BC%E3%82%BF/%E6%9A%97%E9%A0%86%E5%BF%9C"
    },
    "next": {
      "question": "照明を落とした作業室で、暗い環境で光を感じる役割が特に大きい網膜の視細胞はどれか。",
      "choices": [
        "錐体細胞だけ",
        "水晶体の上皮",
        "角膜上皮",
        "杆体細胞",
        "視神経乳頭"
      ],
      "answer": 4,
      "explanation": "杆体細胞は弱い光への感受性が高く、暗所での視覚に重要である。錐体細胞は主として明所の色覚・高解像視に関与する。",
      "quick": "杆体細胞は弱い光への感受性が高く、暗所での視覚に重要である。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.nei.nih.gov/research-and-training/research-news/researchers-uncover-critical-early-step-visual-process",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review",
      "rightsBasis": "米国NIH国立眼研究所（NEI）の公式解説が杆体は暗所視、錐体は日中・色覚に対応すると記載。米国政府機関の事実説明を参照し、記事の文章・画像・図は転載しない。"
    }
  },
  {
    "id": "sm2-r7o-015",
    "expected": {
      "question": "改正THP指針（2026年10月19日適用）に示された健康保持増進の取組として、適切でないものはどれか。",
      "answerText": "法定健康診断はTHPに置き換えられるため、実施を中止する。",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html"
    },
    "next": {
      "question": "事業場が健康保持増進計画を更新し、がん検診の案内と治療中の労働者の就業支援を追加した。法定定期健康診断について適切な扱いはどれか。",
      "choices": [
        "新計画を作れば法定健康診断は不要",
        "運動教室で法定健康診断を代替できる",
        "新しい支援と別に法定健康診断を継続する",
        "健康情報の本人同意を一切確認しない",
        "治療中の労働者は全員一律に退職させる"
      ],
      "answer": 3,
      "explanation": "THPの健康保持増進と労働安全衛生法上の定期健康診断義務は別に位置付けられる。改正指針は二次予防や両立支援も取り入れる。",
      "quick": "THPの健康保持増進と労働安全衛生法上の定期健康診断義務は別に位置付けられる。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  },
  {
    "id": "sm2-r7a-016",
    "expected": {
      "question": "2026年10月19日改正のTHP指針で、二次予防として受診勧奨の対象に明確に位置づけられた健康課題の組合せはどれか。",
      "answerText": "女性特有の健康課題、歯科疾患、骨粗しょう症、眼科疾患など",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html"
    },
    "next": {
      "question": "2026年改正後の職場の健康保持増進計画で、二次予防に該当する取組はどれか。",
      "choices": [
        "運動機会のみを提供し検診案内を全面廃止",
        "従業員の売上順位の公表",
        "生産設備の耐用年数調査",
        "工場の原材料在庫の棚卸し",
        "検診で要精密検査となった人への受診勧奨"
      ],
      "answer": 5,
      "explanation": "二次予防は疾病の早期発見と早期治療につなぐ取組であり、検診結果に応じた精密検査受診勧奨は2026年改正THP指針とも整合する。",
      "quick": "二次予防は疾病の早期発見と早期治療につなぐ取組であり、検診結果に応じた精密検査受診勧奨は2026年改正THP指針とも整合する。",
      "basis": "独自場面再設計・公開資料の事実のみ参照（原典逐肢・権利最終未承認）",
      "sourceUrl": "https://www.mhlw.go.jp/stf/newpage_76807.html",
      "legalChecked": null,
      "auditStatus": "再監査待ち",
      "publicationStatus": "非公開",
      "contentReviewStatus": "requires-independent-source-review"
    }
  }
];
const byId=new Map((window.Q_PARTS||[]).map(q=>[q.id,q]));
if(patches.length!==13||new Set(patches.map(p=>p.id)).size!==13)throw Error('HM2 C13 scope');
for(const f of patches){
 const q=byId.get(f.id);
 if(!q||q.question!==f.expected.question||!Array.isArray(q.choices)||q.choices[q.answer-1]!==f.expected.answerText||q.sourceUrl!==f.expected.sourceUrl)throw Error('HM2 C13 old state mismatch '+f.id);
 if(f.next.choices.length!==5||new Set(f.next.choices).size!==5||f.next.choices[f.next.answer-1]===undefined)throw Error('HM2 C13 choice/answer invalid '+f.id);
 Object.assign(q,f.next);
 if(q.publicationStatus!=='非公開'||q.auditStatus!=='再監査待ち'||q.legalChecked!==null)throw Error('HM2 C13 gate '+f.id);
}
window.HM2_C_REMAINING_REPLACED_IDS=patches.map(p=>p.id);
})();
