(()=>{
const q=window.KANGOSHI_QUESTIONS||[];
const replace=(id,data)=>{const i=q.findIndex(x=>x.id===id);if(i>=0)q[i]={...q[i],...data};};
replace('G23',{
  subject:'看護管理',
  answerType:'numeric',
  question:'40床の病棟に34人が入院している。この時点の病床利用率を求めよ。小数点以下は四捨五入し、整数で答える。',
  choices:[],
  answer:85,
  unit:'%',
  tolerance:0,
  point:'病床利用率は「入院患者数 ÷ 病床数 × 100」で求める。',
  detail:'34 ÷ 40 × 100 ＝ 85。したがって85％。',
  rightsStatus:'original-mvp',
  sourceStatus:'official-format-checked-2026-08-08'
});
replace('G24',{
  subject:'栄養・代謝',
  answerType:'numeric',
  question:'体重54kg、身長1.5mの成人のBMIを求めよ。小数第1位まで答える。',
  choices:[],
  answer:24.0,
  unit:'kg/m²',
  tolerance:0.05,
  point:'BMIは「体重kg ÷ 身長mの2乗」で求める。',
  detail:'54 ÷ (1.5 × 1.5) ＝ 24.0。',
  rightsStatus:'original-mvp',
  sourceStatus:'official-format-checked-2026-08-08'
});
if(window.KANGOSHI_CONTENT_META){
  Object.assign(window.KANGOSHI_CONTENT_META,{
    version:'mvp-0.2.0',
    frameworkCheckedAt:'2026-08-08',
    verifiedFramework:true,
    notice:'独自作成MVP。試験構成・回答形式は第115回厚生労働省公式資料で確認済み。各問題の医学・看護学内容は製品版投入前に専門監査する。'
  });
}
})();
