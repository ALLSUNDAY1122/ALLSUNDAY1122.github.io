(()=>{
  const app=document.getElementById('app');
  const Q=window.KANGOSHI_QUESTIONS||[];
  const KEY='kangoshiSprintStateV02';
  const esc=s=>String(s??'').replace(/[&<>"']/g,m=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[m]));

  const GROUPS=[
    ['人体の構造と機能','体','人体の基本構造・生理機能'],
    ['疾病の成り立ちと回復の促進','病','病態・検査・治療・薬理'],
    ['健康支援と社会保障制度','制','公衆衛生・制度・社会保障'],
    ['基礎看護学','基','看護技術・安全・日常生活援助'],
    ['地域・在宅看護論','在','地域・在宅・退院支援'],
    ['成人看護学','成','成人期の主要疾患と看護'],
    ['老年看護学','老','高齢者・老化・認知症'],
    ['小児看護学','小','成長発達・小児疾患・家族支援'],
    ['母性看護学','母','妊娠・分娩・産褥・新生児'],
    ['精神看護学','精','精神疾患・こころの看護'],
    ['看護の統合と実践','統','倫理・災害・管理・横断実践'],
    ['その他・横断','他','複数領域にまたがるテーマ']
  ];

  const EXACT={
    '生命維持':'人体の構造と機能',
    '感染予防':'基礎看護学','安全':'基礎看護学','酸素療法':'基礎看護学','与薬':'基礎看護学','清潔':'基礎看護学','観察':'基礎看護学','褥瘡予防':'基礎看護学','コミュニケーション':'基礎看護学','排泄':'基礎看護学','栄養':'基礎看護学','呼吸':'基礎看護学','循環':'基礎看護学','体温':'基礎看護学','疼痛':'基礎看護学','輸液':'基礎看護学','患者安全':'基礎看護学','安楽':'基礎看護学','記録':'基礎看護学',
    '災害':'看護の統合と実践','倫理':'看護の統合と実践','個人情報':'看護の統合と実践'
  };

  const RULES=[
    ['小児看護学',/(小児|乳児|幼児|学童|思春期|成長発達)/],
    ['母性看護学',/(母性|妊娠|妊婦|分娩|産褥|胎児|新生児|授乳|産婦)/],
    ['精神看護学',/(精神|統合失調|うつ|躁|不安障害|依存|自殺|こころ)/],
    ['老年看護学',/(老年|高齢|老化|認知症|フレイル|サルコペニア)/],
    ['地域・在宅看護論',/(地域|在宅|訪問|退院支援|在宅療養|介護|地域包括|家族支援)/],
    ['健康支援と社会保障制度',/(社会保障|公衆衛生|保健統計|保健医療|制度|法律|法規|医療保険|介護保険|人口|疫学|労働衛生)/],
    ['看護の統合と実践',/(災害|倫理|個人情報|看護管理|医療安全|チーム|多職種|国際|救急|トリアージ)/],
    ['基礎看護学',/(感染予防|安全|酸素療法|与薬|清潔|観察|褥瘡|コミュニケーション|排泄|栄養|体温|疼痛|輸液|患者安全|安楽|記録|看護技術|バイタル|環境整備)/],
    ['成人看護学',/(循環器|呼吸器|消化器|腎|泌尿|内分泌|代謝|血液|脳神経|神経|運動器|感覚器|周術期|がん|癌|急性期|慢性期|心不全|COPD|糖尿病|脳卒中)/],
    ['疾病の成り立ちと回復の促進',/(疾病|病態|薬理|薬物|感染症|免疫|腫瘍|検査|治療|病理|炎症)/],
    ['人体の構造と機能',/(人体|解剖|生理|生命維持|細胞|組織|恒常性|ホメオスタシス)/]
  ];

  function majorOf(q){
    if(q.majorSubject && GROUPS.some(g=>g[0]===q.majorSubject)) return q.majorSubject;
    const s=String(q.subject||'');
    if(EXACT[s]) return EXACT[s];
    for(const [major,re] of RULES) if(re.test(s)) return major;
    return 'その他・横断';
  }

  function loadState(){
    try{return JSON.parse(localStorage.getItem(KEY)||'{}')||{}}catch{return{}}
  }

  function tabs(){
    return `<nav class="tabbar"><button data-tab="home" class="active"><span class="ic">⌂</span>ホーム</button><button data-tab="history"><span class="ic">▤</span>学習記録</button><button data-tab="settings"><span class="ic">⚙</span>設定</button></nav>`;
  }

  function header(title){
    return `<div class="header"><button data-action="home">ホーム</button><h1>${esc(title)}</h1></div>`;
  }

  function build(){
    const state=loadState();
    const seen=new Set(state.seen||[]);
    const weak=state.weak||{};
    const byMajor=new Map(GROUPS.map(g=>[g[0],new Map()]));
    Q.forEach(q=>{
      const major=majorOf(q);
      if(!byMajor.has(major))byMajor.set(major,new Map());
      const small=String(q.subject||'未分類');
      const m=byMajor.get(major);
      if(!m.has(small))m.set(small,{questions:[],seen:0,weak:0});
      const row=m.get(small);
      row.questions.push(q);
      if(seen.has(q.id))row.seen++;
      if(weak[q.id])row.weak++;
    });
    return byMajor;
  }

  function renderMajors(){
    const byMajor=build();
    const cards=GROUPS.map(([name,icon,desc])=>{
      const smalls=byMajor.get(name)||new Map();
      const values=[...smalls.values()];
      const qCount=values.reduce((n,v)=>n+v.questions.length,0);
      if(!qCount)return'';
      const seen=values.reduce((n,v)=>n+v.seen,0);
      const weak=values.reduce((n,v)=>n+v.weak,0);
      return `<button class="major-card" data-major="${esc(name)}">
        <span class="major-icon">${esc(icon)}</span>
        <span class="major-body"><strong>${esc(name)}</strong><span class="major-desc">${esc(desc)}</span><span class="major-meta">小分類 ${smalls.size} ・ ${qCount}問 ・ ${seen}問解答${weak?` ・ 苦手${weak}`:''}</span></span>
        <span class="major-arrow">›</span>
      </button>`;
    }).join('');
    app.innerHTML=`${header('科目・領域から学ぶ')}<section class="section hierarchy-section"><div class="hierarchy-guide"><b>大分類を選ぶ</b><span>選択すると、その中の小分類だけを表示します。</span></div><div class="major-list">${cards}</div></section>${tabs()}`;
    window.scrollTo(0,0);
  }

  function renderSmalls(major){
    const byMajor=build();
    const smalls=byMajor.get(major)||new Map();
    const group=GROUPS.find(g=>g[0]===major);
    const rows=[...smalls.entries()].sort((a,b)=>a[0].localeCompare(b[0],'ja')).map(([name,v])=>{
      const pct=v.questions.length?Math.round(v.seen/v.questions.length*100):0;
      return `<button class="small-subject-card" data-subject="${esc(name)}">
        <span class="small-subject-main"><strong>${esc(name)}</strong><span>${v.questions.length}問 ・ ${v.seen}問解答${v.weak?` ・ 苦手${v.weak}`:''}</span></span>
        <span class="small-progress" aria-label="解答進捗${pct}%"><i style="width:${pct}%"></i></span>
        <span class="small-arrow">›</span>
      </button>`;
    }).join('');
    app.innerHTML=`${header('科目・領域から学ぶ')}<section class="section hierarchy-section"><button class="hierarchy-back" data-subject-back>‹ 大分類に戻る</button><div class="selected-major"><span class="major-icon">${esc(group?.[1]||'科')}</span><span><span class="crumb">大分類</span><strong>${esc(major)}</strong><small>${esc(group?.[2]||'')}</small></span></div><div class="hierarchy-guide small-guide"><b>小分類を選ぶ</b><span>この大分類に含まれる項目だけを表示しています。</span></div><div class="small-subject-list">${rows}</div></section>${tabs()}`;
    window.scrollTo(0,0);
  }

  document.addEventListener('click',e=>{
    const open=e.target.closest('[data-action="subjects"]');
    if(open){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();renderMajors();return}
    const major=e.target.closest('[data-major]');
    if(major){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();renderSmalls(major.dataset.major);return}
    const back=e.target.closest('[data-subject-back]');
    if(back){e.preventDefault();e.stopPropagation();e.stopImmediatePropagation();renderMajors();}
  },true);
})();
