'use strict';
(function(){
function targetFromId(id){
  const m=String(id||'').match(/(\d+)$/);
  const n=m?parseInt(m[1],10):1;
  return Math.max(0,(n-1)%5);
}
function rotate(q,target){
  if(!q||!Array.isArray(q.choices)||q.choices.length!==5)return q;
  const key=Number.isInteger(q.correct_index)?'correct_index':'answer';
  const current=q[key];
  if(!Number.isInteger(current)||current<0||current>4)return q;
  if(current===target)return q;
  const correct=q.choices[current];
  const choices=q.choices.slice();
  choices.splice(current,1);
  choices.splice(target,0,correct);
  q.choices=choices;
  q[key]=target;
  if(key==='correct_index'&&Object.prototype.hasOwnProperty.call(q,'answer'))q.answer=target;
  return q;
}
if(typeof QUESTIONS!=='undefined'&&Array.isArray(QUESTIONS)){
  QUESTIONS.forEach(q=>rotate(q,targetFromId(q.id)));
}
const nativeFetch=window.fetch.bind(window);
window.fetch=async function(input,init){
  const response=await nativeFetch(input,init);
  const url=typeof input==='string'?input:(input&&input.url)||'';
  if(!/questions\/exam-[123]\/chapter-[1-5]\.json(?:\?|$)/.test(url))return response;
  const originalJson=response.json.bind(response);
  response.json=async function(){
    const data=await originalJson();
    if(Array.isArray(data))data.forEach(q=>rotate(q,targetFromId(q.id)));
    return data;
  };
  return response;
};
})();