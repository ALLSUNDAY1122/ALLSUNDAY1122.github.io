function home(){
  let w=Object.keys(S.weak).length,se=Object.keys(S.seen).length,ac=S.total?Math.round(S.correct/S.total*100):0;
  let r=S.resume?`<div class="section"><button class="full" onclick="resume()"><span class="icon">▶</span><span><strong>続きから</strong><small>${e(S.resume.mode)}・${Math.min(S.resume.idx+1,S.resume.ids.length)}問目</small></span><span class="arrow">›</span></button></div>`:'';
  app.innerHTML=head('第二種衛生管理者')+
  `<div class="hero"><h2>学びスプリント</h2><div class="sub">試験回と科目を選んで、10問ずつ集中して学習。</div></div>
   <div class="notice">Safari価値検証 v1.0｜90問・9セット監査済｜法令基準日 2026-08-08</div>
   ${r}
   <div class="section"><h3>試験回・科目別</h3><div class="sub" style="margin:-4px 0 10px">各掲載回の出題論点に準拠した独自問題です。</div>
     ${examGroup('令和8年4月','令和8年4月掲載分')}
     ${examGroup('令和7年10月','令和7年10月掲載分')}
     ${examGroup('令和7年4月','令和7年4月掲載分')}
   </div>
   <div class="section"><h3>補助学習</h3><div class="grid">
     <button class="card" onclick="daily()"><strong>今日の12問</strong><small>収録済み問題から12問</small></button>
     <button class="card" onclick="weak()"><strong>苦手・誤答</strong><small>${w?w+'問':'復習待ちなし'}</small></button>
     <button class="card" onclick="unseen()"><strong>未出題</strong><small>${Math.max(0,Q.length-se)}問</small></button>
   </div></div>
   <div class="section"><h3>現在地</h3><div class="stats">
     <div class="stat"><b>${ac}%</b><span>累計正答率</span></div>
     <div class="stat"><b>${w}</b><span>苦手</span></div>
     <div class="stat"><b>${se}</b><span>接触問題</span></div>
   </div></div>`+tabs('home')
}
function study(){
  app.innerHTML=head('学習メニュー')+
  `<div class="section"><h3>試験回・科目別 9セット</h3>
    ${examGroup('令和8年4月','令和8年4月掲載分')}
    ${examGroup('令和7年10月','令和7年10月掲載分')}
    ${examGroup('令和7年4月','令和7年4月掲載分')}
   </div>
   <div class="section"><h3>補助学習</h3>
     <button class="full" onclick="daily()"><span class="icon">12</span><span><strong>今日の12問</strong><small>収録済み問題からランダム出題</small></span><span class="arrow">›</span></button>
   </div>`+tabs('study')
}
function hist(){let h=S.history.slice().reverse().map(x=>`<div class="history"><span><b>${e(x.mode)}</b><br><span class="sub">${e(x.date)}</span></span><span><b>${x.score}/${x.total}</b><br>${Math.round(x.score/x.total*100)}%</span></div>`).join('');app.innerHTML=head('学習履歴')+`<div class="section">${h||'<div class="sub">まだ履歴はありません。</div>'}</div>`+tabs('hist')}
function settings(){app.innerHTML=head('設定')+`<div class="section"><div class="q"><b>試作版</b><div class="sub">FP2級HTMLの配色・カード・回答UI・弱点ロジックを基準にしています。9セットの「解答 ○回」は、その試験回×科目で回答した問題の累計回数です。</div></div></div>
<div class="section"><h3>法令・権利対応</h3><div class="legal-card"><div class="legal-ok">法令対応 完了</div><b>法令基準日 ${LEGAL.checked}</b>
<div class="sub">3試験回×3科目の90問を収録。法令問題は2026年8月8日現行法で監査し、将来施行分は分離。</div>
<div class="legal-row"><strong>2026年8月1日改正</strong><span>産業医の辞任・解任・退任時の監督署報告義務を反映済み</span></div>
<div class="legal-row"><strong>著作権対応</strong><span>${e(LEGAL.copyright)}</span></div>
<div class="legal-row"><strong>将来施行</strong><span>${LEGAL.future.map(e).join('<br>')}</span></div>
<div class="legal-note">本アプリは学習支援用です。法令の最終確認は厚生労働省・e-Gov等の最新一次資料を優先します。</div></div></div>
<div class="section"><button class="unknown" onclick="reset()">学習記録をリセット</button></div>`+tabs('set')}function reset(){if(confirm('記録を削除しますか？')){localStorage.removeItem(KEY);S=init();home()}}
function daily(){begin('今日の12問',sh(Q).slice(0,12))}
function examSubject(set,subject){
  let q=Q.filter(x=>x.examSet===set&&x.subject===subject);
  if(q.length<10)return alert(set+'｜'+subject+' は現在 '+q.length+'/10問です。問題が揃うまで水増ししません。');
  begin(set+'｜'+subject,q)
}
function weak(){let q=Q.filter(x=>S.weak[x.id]);if(!q.length)return alert('復習待ちはありません');begin('苦手・誤答',sh(q))}
function unseen(){let q=Q.filter(x=>!S.seen[x.id]);if(!q.length)return alert('未出題はありません');begin('未出題',sh(q))}
function mock(){let law=sh(Q.filter(x=>x.subject==='関係法令')).slice(0,10),hyg=sh(Q.filter(x=>x.subject==='労働衛生')).slice(0,10),phy=sh(Q.filter(x=>x.subject==='労働生理')).slice(0,10);begin('30問模試',[...law,...hyg,...phy])}
function begin(m,q){mode=m;session=q;idx=0;score=0;results=[];render()}
function remember(n=idx){S.resume={mode,idx:n,ids:session.map(x=>x.id),score,results};save()}
function resume(){let r=S.resume;if(!r)return home();mode=r.mode;idx=r.idx;score=r.score;results=r.results||[];session=r.ids.map(id=>Q.find(x=>x.id===id)).filter(Boolean);if(idx>=session.length)return finish();render()}
function render(){if(idx>=session.length)return finish();let q=session[idx];selected=0;locked=false;remember();app.innerHTML=quizHead(mode)+`<div class="quiz"><div class="top"><span>${idx+1} / ${session.length}</span><span class="tag">${e(q.subject)}${q.examSet?'｜'+e(q.examSet):''}</span></div><div class="bar"><i style="width:${((idx+1)/session.length)*100}%"></i></div><div class="q"><small>${e(q.topic)}</small>${e(q.question)}</div>${q.choices.map((c,i)=>`<button id="c${i+1}" class="choice" onclick="pick(${i+1})"><em>${i+1}</em><span>${e(c)}</span></button>`).join('')}<button id="go" class="primary" disabled onclick="grade(false)">回答する</button><button id="unk" class="unknown" onclick="grade(true)">わからない</button><div id="fb"></div></div>`;go=document.getElementById('go');unk=document.getElementById('unk');fb=document.getElementById('fb')}
function pick(n){if(locked)return;selected=n;document.querySelectorAll('.choice').forEach((x,i)=>x.classList.toggle('sel',i+1===n));go.disabled=false}
function grade(u){if(locked||(!u&&!selected))return;locked=true;let q=session[idx],ok=!u&&selected===q.answer;if(ok)score++;results.push({id:q.id,subject:q.subject,ok:ok,unknown:u,selected:selected,answer:q.answer});S.seen[q.id]=(S.seen[q.id]||0)+1;S.total++;if(ok)S.correct++;if(!ok){S.weak[q.id]=1;S.streak[q.id]=0}else if(S.weak[q.id]){S.streak[q.id]=(S.streak[q.id]||0)+1;if(S.streak[q.id]>=2){delete S.weak[q.id];delete S.streak[q.id]}}document.querySelectorAll('.choice').forEach((x,i)=>{x.classList.add('lock');if(i+1===q.answer)x.classList.add('ok');if(!u&&i+1===selected&&selected!==q.answer)x.classList.add('ng')});go.style.display='none';unk.style.display='none';fb.innerHTML=`<div class="fb ${ok?'ok':'ng'}"><h4>${ok?'正解':'不正解'}${u?'（わからない）':''}</h4><div class="quick">${e(q.quick)}</div>${ok?'':`<div class="reason-title">今回の間違い理由 <span>任意</span></div><div class="reason-chips" data-qid="${e(q.id)}"><button onclick="setReason('${q.id}','知識不足',this)">知識不足</button><button onclick="setReason('${q.id}','数字の混同',this)">数字の混同</button><button onclick="setReason('${q.id}','読み違い',this)">読み違い</button><button onclick="setReason('${q.id}','迷って変更',this)">迷って変更</button></div>`}<button class="detail-toggle" onclick="toggleDetail(this)">詳しい解説を見る</button><div class="detail-panel" hidden><div class="expl">${e(q.explanation)}</div><div class="basis">${e(q.basis)}｜${q.lawRelated?`法令監査済 ${e(q.legalChecked)}`:`内容監査済 2026-08-08`}</div></div></div><button class="primary" style="margin-top:12px" onclick="next()">${idx+1===session.length?'結果を見る':'次の問題'}</button>`;save();remember(idx+1)}
function toggleDetail(btn){let p=btn.nextElementSibling;p.hidden=!p.hidden;btn.textContent=p.hidden?'詳しい解説を見る':'詳しい解説を閉じる'}
function setReason(qid,reason,btn){
  let old=S.reasonByQuestion[qid];
  if(old&&S.reasonCounts[old])S.reasonCounts[old]=Math.max(0,S.reasonCounts[old]-1);
  S.reasonByQuestion[qid]=reason;
  S.reasonCounts[reason]=(S.reasonCounts[reason]||0)+1;
  btn.parentElement.querySelectorAll('button').forEach(x=>x.classList.remove('chosen'));
  btn.classList.add('chosen');
  save();
}
function next(){idx++;render()}function judgeMock(){let subjects=['関係法令','労働衛生','労働生理'],ss={};subjects.forEach(s=>{let a=results.filter(r=>r.subject===s);ss[s]={correct:a.filter(r=>r.ok).length,total:a.length}});let total=results.filter(r=>r.ok).length;let eachOK=subjects.every(s=>ss[s].correct>=4);return {subjects:ss,total,pass:eachOK&&total>=18,eachOK,totalOK:total>=18}}
function previousCompleted(m){return [...(S.history||[])].reverse().find(x=>x.mode===m&&x.total===session.length)||null}
function retryCurrent(){let same=[...session];begin(mode,same)}
function reasonSummary(){
  let labels=['知識不足','数字の混同','読み違い','迷って変更'];
  let rows=labels.filter(x=>(S.reasonCounts[x]||0)>0).map(x=>`<span class="reason-summary-chip">${e(x)} ${S.reasonCounts[x]}回</span>`).join('');
  return rows?`<div class="reason-summary"><div class="sub">これまでの誤答理由</div><div>${rows}</div></div>`:'';
}
function finish(){
  S.resume=null;
  let prev=previousCompleted(mode);
  let diff=prev?score-prev.score:null;
  let compare=prev?`<div class="compare ${diff>0?'up':diff<0?'down':'same'}">前回 ${prev.score}/${prev.total}　<span>${diff>0?'+':''}${diff}</span></div>`:`<div class="compare first">このセットは初回完了</div>`;
  let rec={mode,score,total:session.length,date:new Date().toLocaleString('ja-JP')};
  if(mode==='30問模試'||mode.startsWith('過去問：')){
    let j=judgeMock();rec.mock=j;S.history.push(rec);save();
    let rows=['関係法令','労働衛生','労働生理'].map(s=>`<div class="stat"><b>${j.subjects[s].correct}/10</b><span>${s}<br>${j.subjects[s].correct>=4?'40％基準○':'40％基準×'}</span></div>`).join('');
    let reason=[];if(!j.eachOK)reason.push('科目別40％未達あり');if(!j.totalOK)reason.push('総得点60％未達');
    app.innerHTML=head('模試結果')+`<div class="result"><div class="sub">${e(mode)}</div><b>${j.pass?'合格圏':'不合格圏'}</b><div class="sub">総合 ${j.total}/30（${Math.round(j.total/30*100)}％）</div>${compare}</div><div class="section"><div class="stats">${rows}</div>${j.pass?'<div class="fb ok"><h4>合格基準を満たしました</h4><div class="expl">3科目すべて40％以上、かつ総得点60％以上です。</div></div>':`<div class="fb ng"><h4>合格基準に未達</h4><div class="expl">${e(reason.join('／'))}</div></div>`}${reasonSummary()}<button class="full" style="margin-top:12px" onclick="retryCurrent()"><span class="icon">↻</span><span><strong>同じ問題をもう一度</strong><small>今回と同じ出題で再挑戦</small></span><span class="arrow">›</span></button><button class="primary" style="margin-top:12px" onclick="home()">ホームへ</button></div>`+tabs('home');return
  }
  S.history.push(rec);save();
  app.innerHTML=head('結果')+`<div class="result"><div class="sub">${e(mode)}</div><b>${score} / ${session.length}</b><div class="sub">正答率 ${Math.round(score/session.length*100)}%</div>${compare}</div><div class="section">${reasonSummary()}<button class="full" onclick="retryCurrent()"><span class="icon">↻</span><span><strong>同じ${session.length}問をもう一度</strong><small>前回比を確認しながら再挑戦</small></span><span class="arrow">›</span></button><button class="full" style="margin-top:10px" onclick="weak()"><span class="icon">◎</span><span><strong>苦手を復習</strong><small>間違い・わからないを優先</small></span><span class="arrow">›</span></button><button class="primary" style="margin-top:12px" onclick="home()">ホームへ</button></div>`+tabs('home')
}
home();
