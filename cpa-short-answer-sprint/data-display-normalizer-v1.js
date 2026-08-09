'use strict';
(function(){
  const nativeFetch=window.fetch.bind(window);
  const target='questions-all-279.json';
  let correctionsPromise=null;

  function loadCorrections(){
    if(!correctionsPromise){
      correctionsPromise=nativeFetch('./data-display-corrections-v1.json',{cache:'no-store'}).then(r=>{
        if(!r.ok)throw new Error(`display corrections=${r.status}`);
        return r.json();
      });
    }
    return correctionsPromise;
  }

  function formatQuestionText(value){
    const text=String(value??'');
    const re=/([アイウエオカキクケコ])(?:[．。]|\))/g;
    const hits=[...text.matchAll(re)];
    if(hits.length<2||hits[0][1]!=='ア')return text;
    const order='アイウエオカキクケコ';
    for(let i=1;i<hits.length;i++){
      if(order.indexOf(hits[i][1])<=order.indexOf(hits[i-1][1]))return text;
    }
    let out='',last=0;
    hits.forEach((m,i)=>{
      out+=text.slice(last,m.index).replace(/[ \t　\n]+$/,'');
      out+=(i===0?'\n\n':'\n')+`${m[1]}) `;
      last=m.index+m[0].length;
      while(last<text.length&&/[ \t　]/.test(text[last]))last++;
    });
    out+=text.slice(last);
    return out
      .replace(/[ \t　]+\n/g,'\n')
      .replace(/\n[ \t　]+/g,'\n')
      .replace(/\n{3,}/g,'\n\n')
      .trim();
  }

  function sameArray(a,b){
    return Array.isArray(a)&&Array.isArray(b)&&a.length===b.length&&a.every((v,i)=>v===b[i]);
  }

  function syncOfficialExplanation(out){
    if(out.origin_type!=='licensed_official'||typeof out.explanation!=='string')return;
    const idx=Number(out.correct_index);
    if(!Number.isInteger(idx)||idx<0||idx>=out.choices.length)return;
    const mapping=`公式正解は選択肢${idx+1}「${out.choices[idx]}」。`;
    const re=/公式正解は選択肢\d+「[^」]*」。/;
    out.explanation=re.test(out.explanation)?out.explanation.replace(re,mapping):`${mapping}${out.explanation}`;
  }

  function applyCorrection(q,correction){
    const out={...q,choices:Array.isArray(q.choices)?q.choices.slice():[]};
    if(correction?.choices_to){
      const from=correction.choices_from||[];
      if(!sameArray(out.choices,from)&&!sameArray(out.choices,correction.choices_to)){
        throw new Error(`${q.id}: table-choice correction source mismatch`);
      }
      if(sameArray(out.choices,from))out.choices=correction.choices_to.slice();
    }
    for(const rep of correction?.choice_replacements||[]){
      const actual=out.choices[rep.index];
      if(actual!==rep.from&&actual!==rep.to){
        throw new Error(`${q.id}: choice ${rep.index+1} correction source mismatch: ${actual}`);
      }
      if(actual===rep.from)out.choices[rep.index]=rep.to;
    }
    syncOfficialExplanation(out);
    return out;
  }

  function normalizeAll(raw,corrections){
    const table=corrections?.questions||{};
    return raw.map(item=>{
      const q=applyCorrection(item,table[item.id]);
      q.question=formatQuestionText(q.question);
      return q;
    });
  }

  window.__CPA_DISPLAY_NORMALIZER__={version:3,formatQuestionText,normalizeAll};

  window.fetch=async function(input,init){
    const response=await nativeFetch(input,init);
    const url=typeof input==='string'?input:(input?.url||'');
    if(!url.includes(target))return response;
    if(!response.ok)return response;
    const [raw,corrections]=await Promise.all([response.clone().json(),loadCorrections()]);
    const normalized=normalizeAll(raw,corrections);
    const headers=new Headers(response.headers);
    headers.set('content-type','application/json; charset=utf-8');
    headers.delete('content-length');
    return new Response(JSON.stringify(normalized),{status:response.status,statusText:response.statusText,headers});
  };
})();