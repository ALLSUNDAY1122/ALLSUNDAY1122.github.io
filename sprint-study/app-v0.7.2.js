(async()=>{
'use strict';
const parts=[1,2,3,4,5].map(n=>`./app-v0.7.2-${n}.part`);
try{
  const responses=await Promise.all(parts.map(path=>fetch(path,{cache:'no-cache'})));
  for(const response of responses){if(!response.ok)throw new Error(`script ${response.status}`)}
  const source=(await Promise.all(responses.map(response=>response.text()))).join('');
  (0,eval)(source);
}catch(error){
  console.error(error);
  document.body.innerHTML='<main style="font-family:-apple-system;padding:24px"><h1>Sprint Study</h1><p>アプリの読み込みに失敗しました。ページを再読み込みしてください。</p></main>';
}
})();
