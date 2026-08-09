(function(){
'use strict';
const groups=new Map();
for(const q of (window.Q_PARTS||[])){const k=q.examSet+'|'+q.subject;if(!groups.has(k))groups.set(k,[]);groups.get(k).push(q)}
const seqs=[[2,5,1,4,3,1,3,5,2,4],[4,1,5,2,3,5,2,4,1,3],[3,5,2,1,4,2,4,1,5,3]];
let gi=0;
for(const qs of groups.values()){
  const seq=seqs[gi++%seqs.length];
  qs.forEach((q,i)=>{
    const target=seq[i%seq.length];
    if(!Array.isArray(q.choices)||q.choices.length!==5||!Number.isInteger(q.answer)||q.answer<1||q.answer>5)return;
    const from=q.answer-1,to=target-1;
    if(from!==to){const tmp=q.choices[to];q.choices[to]=q.choices[from];q.choices[from]=tmp;q.answer=target}
  });
}
window.SM2_ANSWER_POSITION_POLICY='each-10-set: positions-1-to-5-twice';
})();
