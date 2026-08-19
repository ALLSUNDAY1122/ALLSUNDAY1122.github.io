function donutHTML(rate){
  const r=40,c=2*Math.PI*r,off=c*(1-rate/100);
  return `<div class="donut"><svg viewBox="0 0 96 96"><circle class="track" cx="48" cy="48" r="${r}"/><circle class="fill" cx="48" cy="48" r="${r}" style="stroke-dasharray:${c};stroke-dashoffset:${off}"/></svg><b>${rate}%</b></div>`;
}
function fieldBars(){
  return SUBJECTS.map(s=>{const x=S.subjectStats[s]||{a:0,c:0},rate=x.a?Math.round(x.c/x.a*100):0,col=x.a===0?'#d8d1c4':rate>=70?'var(--midori)':rate>=50?'var(--kin)':'var(--shu)';
  return `<div class="fieldrow"><span>${s}</span><div class="bar"><i style="width:${rate}%;background:${col}"></i></div><em>${x.a?rate+'%':'—'}</em></div>`}).join('');
}
function heatmapHTML(){
  const days=['日','月','火','水','木','金','土'];let cells=[],d=new Date();d.setHours(0,0,0,0);d.setDate(d.getDate()-34);
  for(let i=0;i<35;i++){let k=todayKey(d),a=S.daily[k]?.a||0,l=a===0?0:a<=3?1:a<=7?2:a<=15?3:4,cur=k===todayKey();cells.push(`<i class="heat l${l} ${cur?'todaycell':''}" title="${k} ${a}問"></i>`);d.setDate(d.getDate()+1)}
  return `<div class="heatdays">${days.map(x=>`<span>${x}</span>`).join('')}</div><div class="heatmap">${cells.join('')}</div>`;
}
function weakListHTML(){
  const ids=Object.keys(S.weak).filter(id=>QMAP[id]).slice(0,8);
  if(!ids.length)return `<div class="card empty">苦手はまだありません。</div>`;
  return `<div class="weaklist">${ids.map(id=>{let q=QMAP[id],st=S.weak[id].streak||0;return `<div class="card weakitem"><div class="weakq">${esc(q.question)}</div><div class="dots">${[1,2,3].map(n=>`<i class="${st>=n?'on':''}"></i>`).join('')}</div></div>`}).join('')}</div><button class="primarycta" style="margin-top:10px" onclick="startWeak()"><span><strong>苦手だけ解く（${ids.length}問）</strong><small>3連続正解で卒業</small></span><span class="arr">→</span></button>`;
}
function recentHTML(){
  if(!S.history.length)return `<div class="card empty">まだ学習記録はありません。</div>`;
  return `<div class="card recent">${S.history.slice(0,20).map(h=>{let d=new Date(h.date);return `<div class="recentrow"><span>${d.getMonth()+1}/${d.getDate()} ${String(d.getHours()).padStart(2,'0')}:${String(d.getMinutes()).padStart(2,'0')}</span><b>${esc(h.title)}</b><em>${h.score}/${h.total}</em></div>`}).join('')}</div>`;
}
function historyScreen(){
  const rate=S.total?Math.round(S.correct/S.total*100):0;
  setApp(topBlock('学習記録','積み上げ','短い反復が、そのまま形になります。')+
  `<div class="sec"><div class="recordstats"><div class="card recordstat"><b>${S.total}</b><small>のべ回答</small></div><div class="card recordstat"><b>${S.correct}</b><small>正解</small></div><div class="card recordstat"><b>${streakDays()}</b><small>連続日数</small></div></div></div>
  <div class="sec"><div class="sectitle"><h2>達成度</h2></div><div class="card achieve"><div class="achievegrid">${donutHTML(rate)}<div class="achievecopy"><b>全体正答率 ${rate}%</b><p>正答率だけでなく、分野ごとの偏りも確認できます。</p></div></div><div class="fieldbars">${fieldBars()}</div></div></div>
  <div class="sec"><div class="sectitle"><h2>5週間</h2><span>回答数</span></div><div class="card heatcard">${heatmapHTML()}</div></div>
  <div class="sec"><div class="sectitle"><h2>苦手一覧</h2><span>${Object.keys(S.weak).length}問</span></div>${weakListHTML()}</div>
  <div class="sec"><div class="sectitle"><h2>直近のスプリント</h2></div>${recentHTML()}</div>`+nav('history'));
}
function setFont(v){S.fontSize=v;save();applyFont();settingsScreen();toast('文字サイズを変更しました')}
function setGoal(v){S.dailyGoal=+v;save();settingsScreen();toast('1日の目標を変更しました')}
function toggleSetting(k){S[k]=!S[k];save();settingsScreen()}
function saveExamDate(v){S.examDate=v;save();toast('試験日を保存しました')}
function exportData(){
  const payload={app:'第二種衛生管理者-manabi-sprint',version:VERSION,exportedAt:new Date().toISOString(),state:S};
  const blob=new Blob([JSON.stringify(payload,null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download=`第二種衛生管理者_学びスプリント_${todayKey()}.json`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function importData(){document.querySelector('#importFile').click()}
document.querySelector('#importFile').addEventListener('change',e=>{
  const f=e.target.files[0];if(!f)return;const rd=new FileReader();rd.onload=()=>{
    try{const p=JSON.parse(rd.result);if(!p.state)throw 0;if(!confirm('現在の学習データを読み込みデータで置き換えますか？'))return;S=Object.assign(defaults(),p.state);save();applyFont();settingsScreen();toast('学習データを読み込みました')}catch(err){alert('読み込める学習データではありません')}
  };rd.readAsText(f);e.target.value='';
});
function resetAll(){if(confirm('学習記録をすべてリセットしますか？')){S=defaults();save();applyFont();home()}}

function storePost(payload){try{window.webkit.messageHandlers.storekit.postMessage(payload)}catch(_){toast('App Store版で利用できます')}}
function purchaseTier(tier){storePost({action:'purchase',tier})}
function restorePurchase(){storePost({action:'restore'})}
function manageSubscriptions(){storePost({action:'manageSubscriptions'})}
function premiumStatusLabel(){
  if(window.SM2_STORE.isPremium){
    return window.SM2_STORE.entitlementSource==='lifetime'?'買い切り版を利用中':'月額プランを利用中';
  }
  return '無料版を利用中';
}
function premiumPlansHTML(){
  const st=window.SM2_STORE;
  if(st.isPremium){
    return `<div class="card setting"><h3>プレミアム</h3><p><strong>${premiumStatusLabel()}</strong></p><p>全300問・全30セット・全分野・苦手復習を利用できます。</p>${st.entitlementSource==='monthly'?'<button class="primarycta" onclick="manageSubscriptions()"><span><strong>サブスクリプションを管理</strong><small>App Storeで更新・解約を確認</small></span><span class="arr">→</span></button>':''}<div class="databtns" style="margin-top:10px"><button onclick="restorePurchase()">購入を復元</button></div></div>`;
  }
  return `<div class="card setting"><h3>全300問を解放</h3><p>月額と買い切りは同じ機能です。続けるきっかけを作るなら月額、期限を気にせず使うなら買い切りを選べます。</p>
  <button class="primarycta" onclick="purchaseTier('monthly')"><span><strong>月額プラン</strong><small>学習を続けるきっかけに・${esc(st.monthlyPrice)}</small></span><span class="arr">→</span></button>
  <button class="action" style="margin-top:10px" onclick="purchaseTier('lifetime')"><span><strong>買い切り</strong><small>期限なし・${esc(st.lifetimePrice)}</small></span><span class="arr">→</span></button>
  <div class="databtns" style="margin-top:10px"><button onclick="restorePurchase()">購入を復元</button></div>
  <p style="margin-top:12px">無料版では最新1回相当の30問と今日のスプリントを利用できます。購入後は全300問、全30セット、全分野、苦手復習を解放します。</p>${st.message?`<p>${esc(st.message)}</p>`:''}</div>`;
}
function showPaywall(){
  setApp(topBlock('プレミアム','学びを続ける','自分に合う支払い方で、全300問を使えます。')+`<div class="sec settings">${premiumPlansHTML()}</div>`+nav('settings'));
  requestStoreStatus();
}
window.__storekitUpdate=function(payload){
  window.SM2_STORE=Object.assign(window.SM2_STORE||{},payload||{});
  if(document.querySelector('.settings'))settingsScreen();
  else if(document.querySelector('.home-grid'))home();
};

function settingsScreen(){
  const fs=S.fontSize,goal=S.dailyGoal;
  setApp(topBlock('設定','学び方','自分のペースに合わせて調整できます。')+
  `<div class="sec settings">
  ${premiumPlansHTML()}
  <div class="card setting"><h3>文字サイズ</h3><div class="seg"><button class="${fs==='standard'?'on':''}" onclick="setFont('standard')">標準</button><button class="${fs==='large'?'on':''}" onclick="setFont('large')">大</button><button class="${fs==='xlarge'?'on':''}" onclick="setFont('xlarge')">特大</button></div></div>
  <div class="card setting"><h3>1日の目標</h3><div class="seg"><button class="${goal===4?'on':''}" onclick="setGoal(4)">4問</button><button class="${goal===8?'on':''}" onclick="setGoal(8)">8問</button><button class="${goal===16?'on':''}" onclick="setGoal(16)">16問</button></div></div>
  <div class="card setting"><div class="toggle"><div><h3 style="margin:0">出題順をシャッフル</h3><p>今日のスプリント・分野学習で使用します。</p></div><button class="switch ${S.shuffleQuestions?'on':''}" onclick="toggleSetting('shuffleQuestions')" aria-pressed="${S.shuffleQuestions}"><i></i></button></div></div>
  <div class="card setting"><div class="toggle"><div><h3 style="margin:0">選択肢もシャッフル</h3><p>正答位置を保ったまま選択肢だけ並べ替えます。</p></div><button class="switch ${S.shuffleChoices?'on':''}" onclick="toggleSetting('shuffleChoices')" aria-pressed="${S.shuffleChoices}"><i></i></button></div></div>
  <div class="card setting"><h3>試験日</h3><input class="dateinput" type="date" value="${esc(S.examDate)}" onchange="saveExamDate(this.value)"><p>設定するとホームに残日数と一周に必要な1日ペースを表示します。</p></div>
  <div class="card setting"><h3>学習データ</h3><div class="databtns"><button onclick="exportData()">JSONを書き出す</button><button onclick="importData()">JSONを読み込む</button></div></div>
  <div class="card setting"><h3>覚えかたのルール</h3><div class="memory"><span class="memorylabel">苦手卒業</span>間違い・「わからない」は苦手に追加。苦手問題を3回連続で正解すると自動で外れます。</div></div>
  <div class="card setting"><h3>この教材について</h3><div class="legal">第二種衛生管理者の学習支援教材です。公表問題は論点確認に使用し、問題文・選択肢・解説は独自作成。法令基準日 ${LEGAL_DATE}。法令の最終確認は厚生労働省・e-Gov等の最新一次資料を優先してください。</div></div>
  <div class="card setting"><h3>学習記録リセット</h3><button class="dangerbtn" onclick="resetAll()">すべての学習記録を消す</button></div>
  </div>`+nav('settings'));
  requestStoreStatus();
}
home();
if('serviceWorker' in navigator)window.addEventListener('load',()=>navigator.serviceWorker.register('./sw.js').catch(()=>{}));
