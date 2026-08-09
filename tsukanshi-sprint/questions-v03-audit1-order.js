'use strict';
(()=>{
for(let n=1;n<=60;n++){
  const id=`V03-S-${String(n).padStart(3,'0')}`;
  const q=(TSUKANSHI_QUESTIONS||[]).find(x=>x.id===id);
  if(!q||!Array.isArray(q.choices)||q.choices.length!==4) throw new Error(`answer order target invalid: ${id}`);
  const shift=(n-1)%4;
  if(!shift) continue;
  const before=q.choices.slice();
  q.choices=before.slice(shift).concat(before.slice(0,shift));
  q.answer=(q.answer-shift+before.length)%before.length;
}
})();
