'use strict';
(async function(){
  const app=document.getElementById('app');
  try{
    const files=[1,2,3,4,5].map(n=>`questions/exam-1/chapter-${n}.json`);
    const parts=await Promise.all(files.map(async f=>{
      const r=await fetch(f,{cache:'no-store'});
      if(!r.ok) throw new Error(`${f}: HTTP ${r.status}`);
      return r.json();
    }));
    const rows=parts.flat();
    if(rows.length!==120) throw new Error(`第1回の問題数が${rows.length}問です`);
    window.QUESTIONS=rows.map(q=>({
      id:q.id,
      topic:q.topic,
      chapter:q.chapter,
      question:q.question,
      choices:q.choices,
      answer:q.correct_index,
      point:q.point||q.explanation,
      detail:q.detail||q.explanation,
      source_url:q.source_url||''
    }));
    const s=document.createElement('script');
    s.src='app-v07.js';
    s.onerror=()=>{throw new Error('app-v07.jsを読み込めませんでした')};
    document.body.appendChild(s);
  }catch(e){
    app.innerHTML=`<div class="home-top"><div class="brand-title">問題データを読み込めませんでした</div><p class="brand-sub">${String(e.message||e)}</p><button class="secondary-btn" onclick="location.reload()">再読み込み</button></div>`;
  }
})();