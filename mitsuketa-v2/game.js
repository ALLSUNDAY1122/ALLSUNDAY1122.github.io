const animalEl=document.getElementById('animal');
const prompt=document.getElementById('prompt');
const topText=document.getElementById('topText');
const faceMini=document.getElementById('faceMini');
const celebrate=document.getElementById('celebrate');
const bigAnimal=document.getElementById('bigAnimal');
const reaction=document.getElementById('reaction');
const nextBtn=document.getElementById('nextBtn');
const realModal=document.getElementById('realModal');
const realVideo=document.getElementById('realVideo');
const realTitle=document.getElementById('realTitle');
const realFact=document.getElementById('realFact');
const realCredit=document.getElementById('realCredit');
const realNext=document.getElementById('realNext');
const videoFallback=document.getElementById('videoFallback');
const targets=[...document.querySelectorAll('.target')];
const spots=[
 {id:'tree',x:23,y:52,peekX:25.5,peekY:50.5,label:'おおきな木'},
 {id:'rock',x:81,y:50,peekX:80.5,peekY:48.8,label:'岩'},
 {id:'bush',x:68,y:69,peekX:68.2,peekY:67.4,label:'草むら'},
 {id:'log',x:87,y:79,peekX:86.0,peekY:78.2,label:'丸太'}
];
const animals=[
 {name:'くまさん',mini:'🐻',kind:'bear',reaction:'ばあ！ みーつかった〜！',fact:'ほんものの くまさん。おはなが おおきいね！',video:'https://archive.org/download/grizzly-bear-selfie/GX010742.MP4',credit:'Grizzly Bear selfie / Tom Scott camera・CC0 / Public Domain'},
 {name:'うさぎさん',mini:'🐰',kind:'rabbit',reaction:'ぴょーん！ いたよ〜！',fact:'ほんものの うさぎさん。おみみが ながいね！',video:'https://upload.wikimedia.org/wikipedia/commons/transcoded/1/10/Pet_Rabbit_2_2013-07-18.ogv/Pet_Rabbit_2_2013-07-18.ogv.360p.webm',credit:'Pet Rabbit 2 2013-07-18 / Fastily・CC BY-SA 3.0'},
 {name:'らいおんさん',mini:'🦁',kind:'lion',reaction:'がおー！ みつかった！',fact:'ほんものの らいおんさん。おおきな からだだね！',video:'https://upload.wikimedia.org/wikipedia/commons/8/83/Lion.webm',credit:'Lion.webm / Altes・CC BY-SA 4.0'}
];
let round=0,found=0,currentAnimal,currentSpot,searching=false,hintLevel=0,hintTimer=null,paused=false;

function animalSvg(kind){
 if(kind==='rabbit') return `<svg viewBox="0 0 220 220"><defs><radialGradient id="furR"><stop stop-color="#fff"/><stop offset="1" stop-color="#ddd8d1"/></radialGradient></defs><ellipse cx="82" cy="54" rx="24" ry="55" fill="#f2eee8" stroke="#c6bdb3" stroke-width="6"/><ellipse cx="138" cy="54" rx="24" ry="55" fill="#f2eee8" stroke="#c6bdb3" stroke-width="6"/><ellipse cx="82" cy="54" rx="10" ry="38" fill="#f4a5b8"/><ellipse cx="138" cy="54" rx="10" ry="38" fill="#f4a5b8"/><circle cx="110" cy="116" r="70" fill="url(#furR)" stroke="#c6bdb3" stroke-width="6"/><circle cx="83" cy="106" r="9" fill="#2f241f"/><circle cx="137" cy="106" r="9" fill="#2f241f"/><ellipse cx="110" cy="130" rx="12" ry="9" fill="#e98291"/><path d="M110 138 Q96 152 83 142 M110 138 Q124 152 138 142" fill="none" stroke="#5d4135" stroke-width="5" stroke-linecap="round"/><circle cx="72" cy="130" r="13" fill="#f6b8c5" opacity=".6"/><circle cx="148" cy="130" r="13" fill="#f6b8c5" opacity=".6"/></svg>`;
 if(kind==='lion') return `<svg viewBox="0 0 220 220"><defs><radialGradient id="mane"><stop stop-color="#d98735"/><stop offset="1" stop-color="#8e4b22"/></radialGradient><radialGradient id="faceL"><stop stop-color="#ffd77a"/><stop offset="1" stop-color="#eeb14d"/></radialGradient></defs><circle cx="110" cy="112" r="91" fill="url(#mane)"/><circle cx="110" cy="115" r="67" fill="url(#faceL)" stroke="#a45d27" stroke-width="5"/><circle cx="84" cy="104" r="9" fill="#30231c"/><circle cx="136" cy="104" r="9" fill="#30231c"/><ellipse cx="110" cy="129" rx="15" ry="11" fill="#5b351f"/><path d="M110 138 Q94 153 78 143 M110 138 Q127 153 143 143" fill="none" stroke="#6b4027" stroke-width="5" stroke-linecap="round"/><circle cx="76" cy="131" r="11" fill="#f5a46e" opacity=".6"/><circle cx="145" cy="131" r="11" fill="#f5a46e" opacity=".6"/></svg>`;
 return `<svg viewBox="0 0 220 220"><defs><radialGradient id="furB"><stop stop-color="#c97a43"/><stop offset="1" stop-color="#7f4528"/></radialGradient><linearGradient id="scarf" x1="0" x2="1"><stop stop-color="#ffd24d"/><stop offset="1" stop-color="#f59b28"/></linearGradient></defs><circle cx="62" cy="65" r="31" fill="#8b4d2d"/><circle cx="158" cy="65" r="31" fill="#8b4d2d"/><circle cx="62" cy="65" r="16" fill="#d59a71"/><circle cx="158" cy="65" r="16" fill="#d59a71"/><circle cx="110" cy="116" r="76" fill="url(#furB)" stroke="#713d24" stroke-width="5"/><ellipse cx="110" cy="135" rx="42" ry="31" fill="#e8b98c"/><circle cx="84" cy="107" r="9" fill="#2d2019"/><circle cx="136" cy="107" r="9" fill="#2d2019"/><ellipse cx="110" cy="126" rx="13" ry="10" fill="#3c2419"/><path d="M110 136 Q96 152 82 141 M110 136 Q125 152 140 141" fill="none" stroke="#5b3522" stroke-width="5" stroke-linecap="round"/><path d="M67 168 Q110 195 155 167 L143 205 L111 187 L79 205Z" fill="url(#scarf)" stroke="#d98020" stroke-width="4"/><circle cx="94" cy="185" r="5" fill="#fff2a2"/><circle cx="124" cy="190" r="5" fill="#fff2a2"/></svg>`;
}
function setAnimal(kind){animalEl.innerHTML=animalSvg(kind)}
function setProgress(){
 [...document.querySelectorAll('.slot')].forEach((s,i)=>{s.classList.toggle('done',i<found);s.textContent=i<found?'★':'●'})
}
function wait(ms){return new Promise(r=>setTimeout(r,ms))}

async function startRound(){
 clearInterval(hintTimer); hintLevel=0; searching=false; targets.forEach(t=>t.classList.remove('wiggle'));
 currentAnimal=animals[round%animals.length];
 currentSpot=spots[Math.floor(Math.random()*spots.length)];
 faceMini.textContent=currentAnimal.mini;
 topText.innerHTML=`${currentAnimal.name}が<br>かくれるよ！`;
 setAnimal(currentAnimal.kind);
 animalEl.className='animal';
 animalEl.style.left='14%';animalEl.style.top='40%';
 prompt.textContent=`${currentAnimal.name}が きたよ！`;
 await wait(900);
 if(paused)return;
 animalEl.style.left=currentSpot.x+'%'; animalEl.style.top=currentSpot.y+'%';
 prompt.textContent=`${currentAnimal.name} かくれるよ〜`;
 await wait(950);
 if(paused)return;
 animalEl.style.left=currentSpot.peekX+'%'; animalEl.style.top=currentSpot.peekY+'%';
 animalEl.style.transform='translate(-50%,-50%) scale(.52)';
 animalEl.classList.add('searching');
 searching=true;
 prompt.textContent=`${currentAnimal.name} どこかな？ 🐾`;
 startHints();
}
function startHints(){
 clearInterval(hintTimer);
 hintTimer=setInterval(()=>{
  if(!searching||paused)return;
  hintLevel=Math.min(3,hintLevel+1);
  if(hintLevel===1) prompt.textContent='よ〜く みてみよう 👀';
  if(hintLevel===2){document.getElementById(currentSpot.id).classList.add('wiggle');animalEl.style.transform='translate(-50%,-50%) scale(.64)';prompt.textContent=currentSpot.label+'が あやしいよ！'}
  if(hintLevel===3){animalEl.style.transform='translate(-50%,-50%) scale(.78)';prompt.textContent=currentAnimal.name+'が ちらっ！'}
 },3500);
}
function sparks(){
 const app=document.getElementById('app');
 for(let i=0;i<12;i++){
  const s=document.createElement('div');s.className='spark go';s.textContent=i%3===0?'★':'✦';s.style.left='50%';s.style.top='48%';
  s.style.setProperty('--dx',(Math.random()*360-180)+'px');s.style.setProperty('--dy',(Math.random()*260-180)+'px');app.appendChild(s);setTimeout(()=>s.remove(),950)
 }
}
async function foundAnimal(){
 if(!searching)return;
 searching=false;clearInterval(hintTimer);targets.forEach(t=>t.classList.remove('wiggle'));
 animalEl.classList.add('found');prompt.textContent='みーつけた！';
 sparks(); await wait(700);
 found++;setProgress();
 bigAnimal.innerHTML=animalSvg(currentAnimal.kind);reaction.textContent=currentAnimal.reaction;celebrate.classList.add('show');
}
targets.forEach(t=>t.addEventListener('click',()=>{if(searching&&t.id===currentSpot.id)foundAnimal();else if(searching)prompt.textContent='そこも みてみよう！'}));
animalEl.addEventListener('click',foundAnimal);
document.getElementById('hintBtn').addEventListener('click',()=>{if(searching){document.getElementById(currentSpot.id).classList.add('wiggle');animalEl.style.transform='translate(-50%,-50%) scale(.70)';prompt.textContent=currentSpot.label+'の ところかな？'}});
function showRealAnimal(){
 celebrate.classList.remove('show');
 realTitle.textContent='ほんものの '+currentAnimal.name+'！';
 realFact.textContent=currentAnimal.fact;
 realCredit.textContent='映像: '+currentAnimal.credit;
 videoFallback.hidden=true;realVideo.hidden=false;
 realVideo.src=currentAnimal.video;realVideo.currentTime=0;realModal.classList.add('show');
 const p=realVideo.play(); if(p&&p.catch)p.catch(()=>{});
 setTimeout(()=>{if(realModal.classList.contains('show')){realVideo.pause()}},5200);
}
nextBtn.addEventListener('click',showRealAnimal);
realVideo.addEventListener('error',()=>{realVideo.hidden=true;videoFallback.hidden=false});
realNext.addEventListener('click',()=>{
 realVideo.pause();realVideo.removeAttribute('src');realVideo.load();realModal.classList.remove('show');
 if(found>=3){found=0;round=0;setProgress();}else round++;startRound();
});
document.getElementById('pauseBtn').addEventListener('click',e=>{paused=!paused;e.currentTarget.textContent=paused?'▶':'Ⅱ';if(!paused)startRound()});
document.getElementById('soundBtn').addEventListener('click',e=>{e.currentTarget.textContent=e.currentTarget.textContent==='🔈'?'🔇':'🔈'});
setProgress();startRound();