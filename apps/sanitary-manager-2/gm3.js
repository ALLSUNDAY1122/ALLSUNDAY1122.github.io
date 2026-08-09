function renderQuiz(){
  if(idx>=session.questions.length)return finish();
  answered=false;
  const q=session.questions[idx],order=currentOrder[idx];
  const progress=Math.round((idx/session.questions.length)*100);
  const choices=order.map((orig,di)=>`<button class="choice" id="ch${di}" onclick="choose(${di})"><span class="num">${di+1}</span><span>${esc(q.choices[orig])}</span></button>`).join('');
  const header=`<header class="quizhead"><div class="qhrow"><button class="closebtn" onclick="leaveQuiz()" aria-label="ホームへ戻る">✕</button><div class="qhcopy"><b>${esc(session.title)}</b><small>${esc(q.subject)}｜${esc(q.topic)}</small></div><div class="pips">${session.questions.map((_,i)=>pipHTML(i)).join('')}</div></div><div class="qprogress"><i style="width:${progress}%"></i></div></header>`;
  setApp(`${header}<article class="qcard"><span class="qtag">${esc(q.subject)}・${idx+1}/${session.questions.length}</span><div class="qtext">${esc(q.question)}</div><div class="choices">${choices}</div><button class="unknown" onclick="unknown()">わからない（答えを見る）</button><div id="feedback"></div></article>`);
}
function choose(di){if(answered)return;grade(di,false)}
function unknown(){if(answered)return;grade(-1,true)}
function updateLearning(q,ok,unknownFlag){
  S.total++;if(ok)S.correct++;
  S.seen[q.id]=(S.seen[q.id]||0)+1;
  const k=todayKey();S.daily[k]=S.daily[k]||{a:0,c:0};S.daily[k].a++;if(ok)S.daily[k].c++;
  S.subjectStats[q.subject]=S.subjectStats[q.subject]||{a:0,c:0};S.subjectStats[q.subject].a++;if(ok)S.subjectStats[q.subject].c++;
  if(session.mode==='mock'){const pk=pairKey(session.examSet,session.subject);S.pairAnswers[pk]=(S.pairAnswers[pk]||0)+1}
  if(!ok||unknownFlag){S.weak[q.id]={streak:0,last:Date.now()};return '苦手に追加しました　あとで復習できます'}
  if(S.weak[q.id]){
    S.weak[q.id].streak=(S.weak[q.id].streak||0)+1;S.weak[q.id].last=Date.now();
    if(S.weak[q.id].streak>=3){delete S.weak[q.id];toast('苦手をひとつ卒業しました');return '3回連続正解　苦手から外れました'}
    const st=S.weak[q.id].streak;return `苦手卒業まであと${3-st}回　${'●'.repeat(st)}${'○'.repeat(3-st)}`;
  }
  return '';
}
function grade(di,unknownFlag){
  if(answered)return;answered=true;
  const q=session.questions[idx],order=currentOrder[idx],orig=di>=0?order[di]:-1,correctOrig=q.answer-1,correctDi=order.indexOf(correctOrig);
  const ok=!unknownFlag&&orig===correctOrig;
  if(ok)score++;
  results[idx]={id:q.id,ok,unknown:unknownFlag,selected:orig,correct:correctOrig};
  const weakMsg=updateLearning(q,ok,unknownFlag);
  document.querySelectorAll('.choice').forEach((el,i)=>{
    el.disabled=true;
    if(i===correctDi){el.classList.add('correct');el.insertAdjacentHTML('beforeend',markO())}
    else if(!unknownFlag&&i===di){el.classList.add('wrong');el.insertAdjacentHTML('beforeend',markX())}
    else el.classList.add('dim');
  });
  const u=document.querySelector('.unknown');if(u)u.style.display='none';
  const audit=q.lawRelated?`法令監査 ${esc(q.legalChecked||LEGAL_DATE)}`:'内容監査済';
  $('#feedback').innerHTML=`<div class="feedback"><div class="fbhead ${ok?'ok':'ng'}">${ok?'正解':'惜しい'}</div><div class="fbbody"><div class="memory"><span class="memorylabel">ここだけ覚える</span>${esc(q.quick)}</div><div class="reason">${esc(q.explanation)}</div><details class="details"><summary>もう少し詳しく</summary><div class="detail">${esc(q.basis)}<br>${audit}</div></details>${weakMsg?`<div class="weaknote">${esc(weakMsg)}</div>`:''}<button class="nextbtn" onclick="nextQ()">${idx+1===session.questions.length?'結果を見る':'次の問題へ'}</button></div></div>`;
  storeResume(idx+1);save();
}
function nextQ(){idx++;storeResume(idx);renderQuiz()}
function finish(){
  const total=session.questions.length,pct=Math.round(score/total*100),wrong=results.filter(r=>!r.ok).map(r=>r.id);
  if(session.mode==='mock')S.mockResults[pairKey(session.examSet,session.subject)]={score,total,date:new Date().toISOString()};
  S.history.unshift({date:new Date().toISOString(),title:session.title,score,total,mode:session.mode,ids:session.ids,wrong});S.history=S.history.slice(0,50);
  S.resume=null;save();
  const msg=pct>=80?'よく定着しています。':pct>=60?'合格ラインを意識できる出来です。':'要点を拾い直すと伸びます。';
  const weakBtn=wrong.length?`<button class="reviewbtn" onclick='repeatIds(${JSON.stringify(wrong)})'>間違えた問題をすぐ復習</button>`:'';
  setApp(`<div class="resultwrap"><div class="card resultcard"><div class="brand">今回の結果</div><div class="score">${score}<span> / ${total}</span></div><div class="rmsg">${msg}</div><div class="rmeta">正答率 ${pct}%</div><div class="resultactions">${weakBtn}<button class="retrybtn" onclick='repeatIds(${JSON.stringify(session.ids)})'>もう一度${total}問</button><button class="homebtn" onclick="home()">ホームへ戻る</button></div></div></div>`);
}
function repeatIds(ids){begin('復習',ids.map(id=>QMAP[id]).filter(Boolean),{mode:'review'})}
