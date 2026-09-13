const FREE_SET=EXAMSETS[0];
window.SM2_STORE=window.SM2_STORE||{isPremium:false,entitlementSource:'none',monthlyPrice:'App Storeで価格を確認',lifetimePrice:'App Storeで価格を確認',monthlyAvailable:false,lifetimeAvailable:false,message:''};
function nativeStoreAvailable(){return !!window.webkit?.messageHandlers?.storekit}
function isPremiumAccess(){return !nativeStoreAvailable()||!!window.SM2_STORE.isPremium}
function requestStoreStatus(){try{window.webkit.messageHandlers.storekit.postMessage({action:'status'})}catch(_){}}
function freePool(){return QUESTIONS.filter(q=>q.examSet===FREE_SET)}
function premiumCTA(){return `<div id="home-premium-cta">${isPremiumAccess()?'':`<div class="sec"><button class="action" onclick="showPaywall('home')"><span class="aicon mock">${ICON.mock}</span><span><strong>全300問を解放</strong><small>月額または買い切りで、全30セット・苦手復習まで</small></span><span class="pill hot">PLUS</span></button></div>`}</div>`}

function home(){
  const d=dailyNow(),goal=S.dailyGoal,w=Object.keys(S.weak).length,rate=S.total?Math.round(S.correct/S.total*100):0,days=Object.values(S.daily).filter(x=>x.a>0).length;
  const mockSetCount=EXAMSETS.length;
  let resume='';
  if(S.resume&&S.resume.ids?.length&&S.resume.idx<S.resume.ids.length) resume=`<button class="resume" onclick="resumeSession()"><strong>続きから再開</strong><small>${esc(S.resume.title)}　${S.resume.idx+1}問目から</small></button>`;
  const html=topBlock('学びスプリント','第二種衛生管理者','今日も1問、力に変える。')+countdownHTML()+
  `<div class="today">${ringHTML(d.a,goal)}<div class="todaycopy"><b>今日の学習</b><p>${todayMessage(d.a,d.c,goal)}</p><span class="streakchip">連続 ${streakDays()}日</span></div></div>${resume}
  <div class="sec"><button class="primarycta" onclick="startDaily()"><span><strong>今日のスプリント</strong><small>${goal}問・${minutes(goal)}分ほど</small></span><span class="arr">→</span></button></div>
  <div class="sec"><button class="action" onclick="startWeak()"><span class="aicon weak">${ICON.weak}</span><span><strong>苦手をつぶす</strong><small>間違えた問題を3連続正解で卒業</small></span><span class="pill ${w?'hot':''}">${w}</span></button></div>
  <div class="sec"><button class="action" onclick="mockScreen()"><span class="aicon mock">${ICON.mock}</span><span><strong>30問模擬試験</strong><small>総合60%＋各科目40%の合格基準で判定</small></span><span class="pill">${mockSetCount}回</span></button></div>
  ${premiumCTA()}
  <div class="sec"><div class="sectitle"><h2>分野から解く</h2><span>全${QUESTIONS.length}問</span></div><div class="subjectlist">${SUBJECTS.map(subjectCard).join('')}</div></div>
  <div class="sec"><div class="sectitle"><h2>これまで</h2></div><div class="homestats"><div class="hstat"><b>${S.total}</b><small>のべ回答</small></div><div class="hstat"><b>${rate}%</b><small>正答率</small></div><div class="hstat"><b>${days}</b><small>学習日数</small></div></div></div>`+nav('home');
  setApp(html,true);
  requestStoreStatus();
}
function pickForDaily(pool,n){
  let unseen=pool.filter(q=>!(S.seen[q.id]||0)),seen=pool.filter(q=>(S.seen[q.id]||0));
  let ordered=S.shuffleQuestions?shuffle(unseen).concat(shuffle(seen)):unseen.concat(seen);
  return ordered.slice(0,Math.min(n,ordered.length));
}
function startDaily(){begin('今日のスプリント',pickForDaily(isPremiumAccess()?QUESTIONS:freePool(),S.dailyGoal),{mode:'sprint'})}
function startSubject(s){
  const pool=(isPremiumAccess()?QUESTIONS:freePool()).filter(q=>q.subject===s);
  begin(s+'｜分野学習',pickForDaily(pool,S.dailyGoal),{mode:'subject',subject:s})
}
function startWeak(){
  let qs=Object.keys(S.weak).map(id=>QMAP[id]).filter(Boolean);
  if(!isPremiumAccess())qs=qs.filter(q=>q.examSet===FREE_SET);
  if(!qs.length){toast(isPremiumAccess()?'いま苦手登録はありません':'無料範囲の苦手登録はありません');return}
  begin('苦手をつぶす',S.shuffleQuestions?shuffle(qs):qs,{mode:'weak'})
}
function pairKey(set,sub){return set+'｜'+sub}
function pairAnswers(set,sub){return S.pairAnswers[pairKey(set,sub)]||0}
function fullMockKey(set){return '30問模試｜'+set}
function mockSetCard(set){
  const r=S.mockResults[fullMockKey(set)]||null;
  const locked=!isPremiumAccess()&&set!==FREE_SET;
  const status=locked?'PLUS':r?(r.passed?'合格':'再挑戦'):'未受験';
  const detail=locked?'プレミアムで解放':r?`前回 ${r.score}/30・${r.passed?'合格基準クリア':'合格基準未達'}`:'30問・総合60%＋各科目40%';
  return `<button class="mockcard" onclick="${locked?`showPaywall('mock')`:`startFullMock('${set}')`}"><span class="pill ${locked?'hot':r?.passed?'good':r?'bad':''}">${status}</span><div class="mockring" style="--pct:${r?Math.round(r.score/30*100):0}%"></div><b>${esc(set)}</b><small>${detail}</small></button>`;
}
function mockScreen(){
  const cards=EXAMSETS.map(mockSetCard).join('');
  setApp(topBlock('模擬試験','30問で本番判定','各回30問を通して解き、総合60%以上・各科目40%以上で判定します。')+`<div class="sec"><div class="mockgrid">${cards}</div></div>`+nav('mock'));
  requestStoreStatus();
}
function startFullMock(set){
  if(!isPremiumAccess()&&set!==FREE_SET){showPaywall('mock');return}
  const qs=QUESTIONS.filter(q=>q.examSet===set);
  if(qs.length!==30){toast('この回の30問を準備できません');return}
  begin(set+'｜30問模試',qs,{mode:'fullmock',examSet:set})
}
function startMock(set,sub){
  if(!isPremiumAccess()&&set!==FREE_SET){showPaywall('mock');return}
  begin(pairKey(set,sub),QUESTIONS.filter(q=>q.examSet===set&&q.subject===sub),{mode:'mock',examSet:set,subject:sub})
}

function buildOrders(qs,stored){
  if(stored&&stored.length===qs.length)return stored;
  return qs.map(q=>{
    let arr=q.choices.map((_,i)=>i);
    return S.shuffleChoices?shuffle(arr):arr;
  });
}
function begin(title,qs,opt={},resume=null){
  if(!qs.length){toast('出題できる問題がありません');return}
  session={title,mode:opt.mode||'sprint',examSet:opt.examSet||'',subject:opt.subject||'',ids:qs.map(q=>q.id),questions:qs};
  idx=resume?.idx||0;results=resume?.results||[];score=resume?.score||0;answered=false;
  currentOrder=buildOrders(qs,resume?.orders);
  storeResume(idx);
  renderQuiz();
}
function storeResume(nextIdx=idx){
  if(!session)return;
  S.resume={title:session.title,mode:session.mode,examSet:session.examSet,subject:session.subject,ids:session.ids,idx:nextIdx,results,score,orders:currentOrder};
  save();
}
function resumeSession(){
  const r=S.resume;if(!r)return home();
  const qs=r.ids.map(id=>QMAP[id]).filter(Boolean);
  if(!isPremiumAccess()&&qs.some(q=>q.examSet!==FREE_SET)){showPaywall('resume');return}
  if(!qs.length){S.resume=null;save();return home()}
  begin(r.title,qs,{mode:r.mode,examSet:r.examSet,subject:r.subject},r);
}
function leaveQuiz(){storeResume(answered?idx+1:idx);home()}
function pipHTML(i){
  if(i===idx)return `<i class="pip now"></i>`;
  const r=results[i];return `<i class="pip ${r?(r.ok?'ok':'ng'):''}"></i>`;
}
function markO(){return `<svg class="scribble" viewBox="0 0 40 40" aria-hidden="true"><circle cx="20" cy="20" r="15.5"/></svg>`}
function markX(){return `<svg class="scribble" viewBox="0 0 40 40" aria-hidden="true"><line x1="9" y1="9" x2="31" y2="31"/><line x1="31" y1="9" x2="9" y2="31"/></svg>`}
