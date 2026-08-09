// UI/interaction patch 2026-08-09 21:12 JST
function mockPartLabel(part){return Number(part)===1?'前半':'後半'}

function startMock(round,part){
  const all=Q.filter(q=>q.official&&q.round===Number(round))
    .sort((a,b)=>Number(a.questionNo)-Number(b.questionNo));
  if(all.length!==25){
    alert(`この試験回は${all.length}/25問のため開始できません`);
    return;
  }
  const p=Number(part)===2?2:1;
  const ids=(p===1?all.slice(0,13):all.slice(13)).map(q=>q.id);
  state.active={mode:'mock',round:Number(round),part:p,ids,i:0,correct:0,answers:[],revealed:false,startedAt:new Date().toISOString()};
  state.tab='quiz';
  save();
  render();
}

function finishSession(){
  const a=state.active;
  if(!a)return;
  const result={date:new Date().toISOString(),mode:a.mode,round:a.round||0,part:a.part||0,correct:a.correct,total:a.ids.length,ids:a.ids,answers:a.answers};
  state.sessions=state.sessions||[];
  state.sessions.unshift(result);
  state.sessions=state.sessions.slice(0,100);
  if(a.mode==='mock'&&a.round&&a.part){
    state.mockCompletions=state.mockCompletions||{};
    const k=`${a.round}-${a.part}`;
    state.mockCompletions[k]=(state.mockCompletions[k]||0)+1;
  }
  state.lastResult=result;
  state.active=null;
  state.tab='result';
  save();
  render();
}

function home(){
  const done=Object.keys(state.done||{}).filter(id=>BYID[id]).length;
  const p=Q.length?Math.round(done/Q.length*100):0;
  const weak=Object.keys(state.weak||{}).filter(id=>BYID[id]).length;
  const action=state.active?"state.tab='quiz';save();render()":"startDaily()";
  const aria=state.active?'学習を再開':`今日の${state.goal}問を開始`;
  const copy=state.active?'途中の学習があります。タップして再開。':'苦手を優先しながら、短問を毎日回します。タップして開始。';
  return `<header><div><div class="kicker">科目A-2｜製品化候補</div><div class="title">情報処理安全確保支援士<br>学びスプリント</div></div><div class="pill">Safari版</div></header>
${bankBanner()}${countdown()}
<div class="card signature" role="button" tabindex="0" aria-label="${aria}" onclick="${action}" onkeydown="if(event.key==='Enter'||event.key===' '){event.preventDefault();this.click()}" style="cursor:pointer;-webkit-tap-highlight-color:transparent">
  <div class="ring" style="--p:${p}%"><b>${p}%</b></div>
  <div><div class="muted">今日の学習</div><h2>${state.goal}問スプリント</h2><p class="muted">${copy}</p></div>
</div>
${state.active?`<button class="btn gold" onclick="state.tab='quiz';save();render()">続きから再開（${state.active.i+1}/${state.active.ids.length}）</button>`:`<button class="btn" onclick="startDaily()">今日の${state.goal}問を始める</button>`}
${weak?`<button class="btn alt" onclick="startWeak()">苦手 ${weak}問を復習</button>`:''}
<div class="grid2"><div class="mini"><b>学習済み</b><div style="font-size:28px;font-family:serif">${done}</div><span class="muted">/ ${Q.length}問</span></div><div class="mini"><b>苦手</b><div style="font-size:28px;font-family:serif">${weak}</div><span class="muted">3連続正解で解除</span></div></div>`;
}

function mock(){
  const cards=[1,2,3].map(r=>{
    const n=Q.filter(q=>q.official&&q.round===r).length;
    const c1=(state.mockCompletions||{})[`${r}-1`]||0;
    const c2=(state.mockCompletions||{})[`${r}-2`]||0;
    const disabled=n!==25?'disabled style="opacity:.45"':'';
    return `<div class="card mock-card">
      <div class="kicker">IPA公開過去問｜科目A-2相当</div>
      <h2>${roundLabel(r)}</h2>
      <div class="row"><span class="mock-count">${n}/25</span><span class="muted">前半＋後半</span></div>
      <div class="grid2">
        <div class="mini"><b>前半</b><p class="muted">問1〜13｜13問<br>完答 ${c1}回</p><button class="btn" ${disabled} onclick="startMock(${r},1)">13問を解く</button></div>
        <div class="mini"><b>後半</b><p class="muted">問14〜25｜12問<br>完答 ${c2}回</p><button class="btn" ${disabled} onclick="startMock(${r},2)">12問を解く</button></div>
      </div>
    </div>`;
  }).join('');
  return `<header><div><div class="kicker">公開過去問を試験回別に</div><div class="title">模試</div></div></header>
  <div class="notice"><b>25問を2分割</b><br>各試験回を前半13問・後半12問に分けました。どちらも完答回数を個別に記録します。</div>
  ${BANK_STATUS==='full'?cards:bankBanner()}`;
}

function result(){
  const r=state.lastResult;
  if(!r)return home();
  const rate=Math.round(r.correct/r.total*100),wrong=r.total-r.correct;
  const title=r.mode==='mock'?`${roundLabel(r.round)} ${mockPartLabel(r.part)}`:r.mode==='weak'?'苦手復習':'今日のスプリント';
  return `<header><div><div class="kicker">学習結果</div><div class="title">${title}</div></div></header>
  <div class="card" style="text-align:center"><div class="ring" style="--p:${rate}%;margin:0 auto 16px"><b>${rate}%</b></div><h2>${r.correct} / ${r.total}問 正解</h2><p class="muted">不正解 ${wrong}問。間違えた問題は苦手へ戻ります。</p></div>
  ${Object.keys(state.weak||{}).length?'<button class="btn" onclick="startWeak()">苦手を復習する</button>':''}
  <button class="btn alt" onclick="nav('home')">ホームへ</button>`;
}

try{render()}catch(_){}
