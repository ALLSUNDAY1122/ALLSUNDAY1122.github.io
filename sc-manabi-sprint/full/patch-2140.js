// UI/interaction patch 2026-08-09 21:40 JST
function mockPartLabel(part){return Number(part)===1?'前半':'後半'}

function mockStart(round,part){
  const r=Number(round),p=Number(part)===2?2:1;
  const all=Q.filter(q=>q.official&&q.round===r).sort((a,b)=>Number(a.no)-Number(b.no));
  if(all.length!==25){alert(`この試験回は${all.length}/25問のため開始できません`);return;}
  const ids=(p===1?all.slice(0,13):all.slice(13)).map(q=>q.id);
  S.active={mode:'mock',ids,round:r,part:p,i:0,correct:0,answers:[],revealed:false};
  S.tab='quiz';save();render();
}

function finish(){
  const a=S.active;if(!a)return;
  const r={date:new Date().toISOString(),mode:a.mode,round:a.round||0,part:a.part||0,correct:a.correct,total:a.ids.length};
  S.sessions=S.sessions||[];S.sessions.unshift(r);S.sessions=S.sessions.slice(0,100);
  if(a.mode==='mock'&&a.round&&a.part){S.mockCompletions=S.mockCompletions||{};const k=`${a.round}-${a.part}`;S.mockCompletions[k]=(S.mockCompletions[k]||0)+1;}
  S.lastResult=r;S.active=null;S.tab='result';save();render();
}

function home(){
  const done=Object.keys(S.done||{}).filter(id=>BYID[id]).length;
  const p=Q.length?Math.round(done/Q.length*100):0;
  const w=Object.keys(S.weak||{}).filter(id=>BYID[id]).length;
  const action=S.active?"S.tab='quiz';save();render()":"daily()";
  const aria=S.active?'学習を再開':`今日の${S.goal}問を開始`;
  const copy=S.active?'途中の学習があります。タップして再開。':'苦手を優先しながら、短問を毎日回します。タップして開始。';
  return `<header><div><div class="kicker">科目A-2｜製品候補版</div><div class="title">情報処理安全確保支援士<br>学びスプリント</div></div><div class="pill">Safari</div></header>${banner()}${countdown()}<div class="card signature" role="button" tabindex="0" aria-label="${aria}" onclick="${action}" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();this.click()}" style="cursor:pointer;-webkit-tap-highlight-color:transparent"><div class="ring" style="--p:${p}%"><b>${p}%</b></div><div><div class="muted">今日の学習</div><h2>${S.goal}問スプリント</h2><p class="muted">${copy}</p></div></div>${status==='full'?(S.active?`<button class="btn gold" onclick="S.tab='quiz';save();render()">続きから再開（${S.active.i+1}/${S.active.ids.length}）</button>`:`<button class="btn" onclick="daily()">今日の${S.goal}問を始める</button>`):''}${w?`<button class="btn alt" onclick="weak()">苦手 ${w}問を復習</button>`:''}<div class="grid2"><div class="mini"><b>学習済み</b><div style="font:28px serif">${done}</div><span class="muted">/ ${Q.length||325}問</span></div><div class="mini"><b>苦手</b><div style="font:28px serif">${w}</div><span class="muted">3連続正解で解除</span></div></div>`;
}

function mock(){
  if(status!=='full')return `<header><div class="title">模試</div></header>${banner()}`;
  const cards=[1,2,3].map(r=>{
    const n=Q.filter(q=>q.official&&q.round===r).length;
    const c1=(S.mockCompletions||{})[`${r}-1`]||0,c2=(S.mockCompletions||{})[`${r}-2`]||0;
    const dis=n!==25?'disabled':'';
    return `<div class="card"><div class="kicker">IPA公開過去問｜科目A-2相当</div><h2>${rl(r)}</h2><div class="row"><b style="font:28px serif">${n}/25</b><span class="muted">前半＋後半</span></div><div class="grid2"><div class="mini"><b>前半</b><p class="muted">問1〜13｜13問<br>完答 ${c1}回</p><button class="btn" ${dis} onclick="mockStart(${r},1)">13問を解く</button></div><div class="mini"><b>後半</b><p class="muted">問14〜25｜12問<br>完答 ${c2}回</p><button class="btn" ${dis} onclick="mockStart(${r},2)">12問を解く</button></div></div></div>`;
  }).join('');
  return `<header><div><div class="kicker">公開過去問を試験回別に</div><div class="title">模試</div></div></header><div class="notice"><b>25問を2分割</b><br>各試験回を前半13問・後半12問に分け、完答回数も別々に記録します。</div>${cards}`;
}

function result(){
  const r=S.lastResult;if(!r)return home();
  const p=Math.round(r.correct/r.total*100),title=r.mode==='mock'?`${rl(r.round)} ${mockPartLabel(r.part)}`:r.mode==='weak'?'苦手復習':'今日のスプリント';
  return `<header><div><div class="kicker">学習結果</div><div class="title">${title}</div></div></header><div class="card" style="text-align:center"><div class="ring" style="--p:${p}%;margin:0 auto 16px"><b>${p}%</b></div><h2>${r.correct} / ${r.total}問 正解</h2><p class="muted">不正解 ${r.total-r.correct}問。誤答は苦手へ戻ります。</p></div>${Object.keys(S.weak||{}).length?'<button class="btn" onclick="weak()">苦手を復習</button>':''}<button class="btn alt" onclick="nav('home')">ホームへ</button>`;
}

function resetLearningData(){
  if(!confirm('学習履歴・苦手・設定をすべて初期化します。元に戻せません。よろしいですか？'))return;
  localStorage.removeItem(KEY);
  location.reload();
}

function settings(){
  return `<header><div><div class="kicker">学習設定</div><div class="title">設定</div></div></header>
  <div class="card"><h3>試験日</h3><input type="date" value="${esc(S.examDate||'')}" onchange="S.examDate=this.value;save();render()"></div>
  <div class="card"><h3>1日の問題数</h3><select onchange="S.goal=Number(this.value);save();render()"><option value="4" ${S.goal==4?'selected':''}>4問</option><option value="8" ${S.goal==8?'selected':''}>8問</option><option value="16" ${S.goal==16?'selected':''}>16問</option></select></div>
  <div class="card"><h3>文字サイズ</h3><select onchange="S.font=this.value;applyFont();save();render()"><option value="small" ${S.font==='small'?'selected':''}>小</option><option value="normal" ${S.font==='normal'?'selected':''}>標準</option><option value="large" ${S.font==='large'?'selected':''}>大</option></select></div>
  <div class="card"><h3>学習データ</h3><button class="btn alt" onclick="exportData()">JSONを書き出す</button><label class="btn alt" style="display:block;text-align:center">JSONを読み込む<input type="file" accept=".json,application/json" style="display:none" onchange="importData(this.files[0])"></label><button class="btn alt" onclick="resetLearningData()" style="color:#8b2d2d;border-color:#8b2d2d">学習データを初期化</button></div>
  <div class="card"><h3>サポート・プライバシー</h3><a class="btn alt" style="display:block;text-align:center;text-decoration:none" href="https://allsunday1122.github.io/sc-manabi-sprint/privacy.html" target="_blank" rel="noopener">プライバシーポリシー</a><a class="btn alt" style="display:block;text-align:center;text-decoration:none" href="https://allsunday1122.github.io/sc-manabi-sprint/support.html" target="_blank" rel="noopener">サポート</a><p class="muted">本アプリはIPAの公式アプリではありません。バージョン 1.0.0</p></div>
  <div class="notice"><b>問題の扱い</b><br>IPA公表過去問は出典・改変表示を付けます。非公開となった2026年度以降の本試験問題は受験者の記憶等から復元しません。</div>`;
}
