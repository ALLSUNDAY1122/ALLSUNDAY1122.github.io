'use strict';
(function(){
  if(!Array.isArray(window.QUESTIONS)&&typeof QUESTIONS==='undefined') return;
  const list=typeof QUESTIONS!=='undefined'?QUESTIONS:window.QUESTIONS;
  list.forEach(q=>{
    if(!q||!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)) return;
    const m=String(q.id||'').match(/(\d+)$/);
    if(!m) return;
    const target=(Number(m[1])-1)%5;
    const shift=(q.answer-target+5)%5;
    if(!shift) return;
    q.choices=q.choices.slice(shift).concat(q.choices.slice(0,shift));
    q.answer=target;
  });
})();
