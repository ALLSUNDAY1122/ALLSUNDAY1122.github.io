(() => {
  'use strict';
  const CARD_KEY='toru-tango-beta-cards-v1';
  const URL_KEY='toru-tango-ai-url-v1';
  const EVAL_KEY='toru-tango-ai-evaluations-v1';
  const $=(selector)=>document.querySelector(selector);
  const norm=(value)=>String(value??'').trim().replace(/\s+/g,' ').toLocaleLowerCase('ja-JP');
  const normalizeRotation=(value)=>((value%360)+360)%360;
  let cards=[];
  let evaluations=[];
  let lastAiResult=null;
  let selectedPhoto=null;
  let photoImage=null;
  let photoRotation=0;
  let manualRotation=false;
  let queue=[];
  let position=0;
  let backVisible=false;

  try{const parsed=JSON.parse(localStorage.getItem(CARD_KEY)||'[]');cards=Array.isArray(parsed)?parsed:[]}catch{cards=[]}
  try{const parsed=JSON.parse(localStorage.getItem(EVAL_KEY)||'[]');evaluations=Array.isArray(parsed)?parsed:[]}catch{evaluations=[]}

  const configuredUrl=()=>localStorage.getItem(URL_KEY)||window.TORU_TANGO_CONFIG?.aiApiUrl||'';
  const endpoint=()=>{const base=configuredUrl().trim();if(!base)return'';return base.endsWith('/generate')?base:base.replace(/\/$/,'')+'/generate'};
  const persist=()=>{localStorage.setItem(CARD_KEY,JSON.stringify(cards));renderCards()};
  const persistEvaluations=()=>{localStorage.setItem(EVAL_KEY,JSON.stringify(evaluations));renderEvaluationStatus()};
  const speak=(text)=>{if(!('speechSynthesis'in window))return alert('このブラウザは読み上げに対応していません。');speechSynthesis.cancel();const utterance=new SpeechSynthesisUtterance(text);utterance.lang='ja-JP';utterance.rate=.95;speechSynthesis.speak(utterance)};
  const addCard=(front,back)=>{front=String(front??'').trim();back=String(back??'').trim();if(!front||!back)return false;if(cards.some(card=>norm(card.front)===norm(front)&&norm(card.back)===norm(back)))return false;cards.push({id:Date.now()+Math.random(),front,back,correct:0,wrong:0});return true};
  const parseLines=(text)=>String(text).split(/\n/).map(line=>{const parts=line.split(/[｜|\t]/);return parts.length>=2?{front:(parts.shift()||'').trim(),back:parts.join('｜').trim()}:null}).filter(Boolean);

  document.querySelectorAll('.tab').forEach(button=>button.onclick=()=>{document.querySelectorAll('.tab').forEach(item=>item.classList.toggle('active',item===button));document.querySelectorAll('.panel').forEach(item=>item.classList.toggle('active',item.id===button.dataset.tab));});

  function escapeHtml(value){return String(value).replace(/[&<>"']/g,character=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[character]))}
  function renderCards(){
    $('#cardCount').textContent=cards.length;
    $('#cardList').innerHTML=cards.length?cards.map((card,index)=>`<article class="cardItem"><div class="face"><div class="faceLabel">表</div><div class="faceText">${escapeHtml(card.front)}</div></div><div class="face"><div class="faceLabel">裏</div><div class="faceText">${escapeHtml(card.back)}</div></div><div class="row"><button class="btn secondary" data-read-front="${index}">表を読む</button><button class="btn secondary" data-read-back="${index}">裏を読む</button><button class="btn danger" data-delete="${index}">削除</button></div></article>`).join(''):'<div class="empty">カードはまだありません。</div>';
    document.querySelectorAll('[data-read-front]').forEach(button=>button.onclick=()=>speak(cards[Number(button.dataset.readFront)].front));
    document.querySelectorAll('[data-read-back]').forEach(button=>button.onclick=()=>speak(cards[Number(button.dataset.readBack)].back));
    document.querySelectorAll('[data-delete]').forEach(button=>button.onclick=()=>{const index=Number(button.dataset.delete);if(confirm('このカードを削除しますか？')){cards.splice(index,1);persist()}});
  }

  function setGenerated(lines,message,isAi=false){$('#generated').value=lines.join('\n');$('#generated').classList.toggle('hidden',!lines.length);$('#saveGenerated').classList.toggle('hidden',!lines.length);$('#qualityRow').classList.toggle('hidden',!isAi||!lines.length);$('#status').className='status';$('#status').textContent=message}

  function loadPhoto(file){
    return new Promise((resolve,reject)=>{
      const objectUrl=URL.createObjectURL(file);
      const image=new Image();
      image.onload=()=>{URL.revokeObjectURL(objectUrl);resolve(image)};
      image.onerror=()=>{URL.revokeObjectURL(objectUrl);reject(new Error('画像を読み込めませんでした'))};
      image.src=objectUrl;
    });
  }

  function createPhotoCanvas(rotation,maxSide=1600,enhance=false){
    if(!photoImage)throw new Error('画像がありません');
    const normalized=normalizeRotation(rotation);
    const swap=normalized===90||normalized===270;
    const sourceWidth=photoImage.naturalWidth||photoImage.width;
    const sourceHeight=photoImage.naturalHeight||photoImage.height;
    const rotatedWidth=swap?sourceHeight:sourceWidth;
    const rotatedHeight=swap?sourceWidth:sourceHeight;
    const scale=Math.min(2,Math.max(0.35,maxSide/Math.max(rotatedWidth,rotatedHeight)));
    const canvas=document.createElement('canvas');
    canvas.width=Math.max(1,Math.round(rotatedWidth*scale));
    canvas.height=Math.max(1,Math.round(rotatedHeight*scale));
    const context=canvas.getContext('2d',{willReadFrequently:enhance});
    context.fillStyle='#fff';
    context.fillRect(0,0,canvas.width,canvas.height);
    context.save();
    context.translate(canvas.width/2,canvas.height/2);
    context.rotate(normalized*Math.PI/180);
    context.drawImage(photoImage,-sourceWidth*scale/2,-sourceHeight*scale/2,sourceWidth*scale,sourceHeight*scale);
    context.restore();

    if(enhance){
      const imageData=context.getImageData(0,0,canvas.width,canvas.height);
      const data=imageData.data;
      const histogram=new Uint32Array(256);
      for(let index=0;index<data.length;index+=4){
        const luminance=Math.round(data[index]*0.299+data[index+1]*0.587+data[index+2]*0.114);
        histogram[luminance]++;
      }
      const pixels=canvas.width*canvas.height;
      const percentile=(ratio)=>{let total=0;for(let value=0;value<256;value++){total+=histogram[value];if(total>=pixels*ratio)return value}return 255};
      const low=percentile(.02);
      const high=Math.max(low+20,percentile(.985));
      for(let index=0;index<data.length;index+=4){
        const luminance=data[index]*0.299+data[index+1]*0.587+data[index+2]*0.114;
        let adjusted=(luminance-low)*255/(high-low);
        adjusted=(adjusted-128)*1.18+128;
        const value=Math.max(0,Math.min(255,Math.round(adjusted)));
        data[index]=value;data[index+1]=value;data[index+2]=value;data[index+3]=255;
      }
      context.putImageData(imageData,0,0);
    }
    return canvas;
  }

  function renderPhotoPreview(){
    if(!photoImage)return;
    const canvas=createPhotoCanvas(photoRotation,1400,false);
    $('#photoPreview').src=canvas.toDataURL('image/jpeg',.9);
    $('#photoPreview').classList.remove('hidden');
    $('#rotationStatus').textContent=`現在の向き：${normalizeRotation(photoRotation)}度${manualRotation?'（手動固定）':'（OCR時に自動判定）'}`;
  }

  function projectionSuggestsSideways(rotation){
    const canvas=createPhotoCanvas(rotation,360,true);
    const context=canvas.getContext('2d',{willReadFrequently:true});
    const {data}=context.getImageData(0,0,canvas.width,canvas.height);
    const rows=new Float64Array(canvas.height);
    const columns=new Float64Array(canvas.width);
    for(let y=0;y<canvas.height;y++){
      for(let x=0;x<canvas.width;x++){
        const value=data[(y*canvas.width+x)*4];
        if(value<175){rows[y]++;columns[x]++}
      }
    }
    const variation=(values)=>{let mean=0;for(const value of values)mean+=value;mean/=values.length||1;let variance=0;for(const value of values)variance+=(value-mean)**2;variance/=values.length||1;return Math.sqrt(variance)/(mean+.001)};
    return variation(columns)>variation(rows)*1.18;
  }

  function ocrTextScore(value){
    const text=String(value||'');
    const japanese=(text.match(/[\u3040-\u30ff\u3400-\u9fff]/g)||[]).length;
    const digits=(text.match(/[0-9]/g)||[]).length;
    const latin=(text.match(/[A-Za-z]/g)||[]).length;
    const noise=(text.match(/[|_=<>\\]{1}/g)||[]).length;
    const meaningfulLines=text.split(/\n/).filter(line=>(line.match(/[\u3040-\u30ff\u3400-\u9fff0-9]/g)||[]).length>=4).length;
    return japanese*5+digits+meaningfulLines*20-latin*.35-noise*1.5;
  }

  function cleanOcrText(value){
    return String(value||'')
      .replace(/\r/g,'')
      .split(/\n/)
      .map(line=>line.replace(/[ \t]{2,}/g,' ').trim())
      .filter(line=>{
        if(!line)return false;
        const meaningful=(line.match(/[\u3040-\u30ff\u3400-\u9fff0-9A-Za-z]/g)||[]).length;
        return meaningful>=2;
      })
      .join('\n')
      .replace(/\n{3,}/g,'\n\n')
      .trim();
  }

  async function recognizeCanvas(canvas,status,label,progressPrefix){
    const result=await window.Tesseract.recognize(canvas,'jpn+eng',{logger:(message)=>{if(typeof message.progress==='number')status.textContent=`${progressPrefix}${label} ${Math.round(message.progress*100)}%`;}});
    return cleanOcrText(result?.data?.text||'');
  }

  async function chooseRotation(status){
    if(manualRotation)return photoRotation;
    if(!projectionSuggestsSideways(photoRotation))return photoRotation;
    const candidates=[normalizeRotation(photoRotation+90),normalizeRotation(photoRotation+270)];
    let best={rotation:candidates[0],score:-Infinity};
    for(let index=0;index<candidates.length;index++){
      const rotation=candidates[index];
      const canvas=createPhotoCanvas(rotation,850,true);
      const text=await recognizeCanvas(canvas,status,`${index+1}/${candidates.length}`,'向きを確認中 ');
      const score=ocrTextScore(text);
      if(score>best.score)best={rotation,score};
    }
    return best.rotation;
  }

  $('#photo').onchange=async(event)=>{
    selectedPhoto=event.target.files?.[0]||null;
    photoImage=null;photoRotation=0;manualRotation=false;
    $('#ocrText').classList.add('hidden');
    $('#useOcrText').classList.add('hidden');
    if(!selectedPhoto){$('#photoPreview').classList.add('hidden');return}
    const status=$('#ocrStatus');
    status.className='status';status.classList.remove('hidden');status.textContent='写真を読み込んでいます。';
    try{photoImage=await loadPhoto(selectedPhoto);renderPhotoPreview();status.textContent='写真を選択しました。OCR時に向きを自動判定します。必要なら回転ボタンで調整してください。';}
    catch(error){status.className='status error';status.textContent=error instanceof Error?error.message:'画像を読み込めませんでした';}
  };

  $('#rotateLeft').onclick=()=>{if(!photoImage)return alert('先に写真を選択してください。');photoRotation=normalizeRotation(photoRotation-90);manualRotation=true;renderPhotoPreview()};
  $('#rotateRight').onclick=()=>{if(!photoImage)return alert('先に写真を選択してください。');photoRotation=normalizeRotation(photoRotation+90);manualRotation=true;renderPhotoPreview()};
  $('#autoRotation').onclick=()=>{if(!photoImage)return alert('先に写真を選択してください。');photoRotation=0;manualRotation=false;renderPhotoPreview();$('#ocrStatus').className='status';$('#ocrStatus').textContent='OCR時に向きを自動判定します。'};

  $('#runOcr').onclick=async()=>{
    if(!selectedPhoto||!photoImage)return alert('先に写真を撮るか選択してください。');
    const status=$('#ocrStatus');
    status.className='status';status.classList.remove('hidden');status.textContent='文字認識機能を読み込み中です。';
    try{
      if(!window.Tesseract){await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';script.onload=resolve;script.onerror=reject;document.head.appendChild(script)})}
      const selectedRotation=await chooseRotation(status);
      photoRotation=selectedRotation;
      renderPhotoPreview();
      const canvas=createPhotoCanvas(selectedRotation,2500,true);
      const text=await recognizeCanvas(canvas,status,'','文字認識中 ');
      if(!text||ocrTextScore(text)<80)throw new Error('文字を十分に認識できませんでした。写真を正面から撮り、回転を調整してください');
      $('#ocrText').value=text;
      $('#ocrText').classList.remove('hidden');
      $('#useOcrText').classList.remove('hidden');
      status.textContent=`文字認識が完了しました。${manualRotation?'手動指定':'自動判定'}の向きは${selectedRotation}度です。内容を確認して教材本文へ送ってください。`;
    }catch(error){status.className='status error';status.textContent=`文字認識に失敗しました：${error instanceof Error?error.message:'原因不明のエラー'}`;}
  };

  $('#useOcrText').onclick=()=>{const text=$('#ocrText').value.trim();if(!text)return alert('認識結果がありません。');$('#source').value=text;$('#status').className='status';$('#status').textContent='認識結果を教材本文へ入れました。作問方法を選んでください。';$('#source').scrollIntoView({behavior:'smooth',block:'center'});};

  $('#localGenerate').onclick=()=>{
    lastAiResult=null;
    const text=$('#source').value.trim();
    if(text.length<20)return setGenerated([],'教材本文を20文字以上入力してください。');
    const lines=window.ToruTangoGeneratorV2.generateQuestionsV2(text,Number($('#count').value),$('#type').value,$('#difficulty').value);
    setGenerated(lines,lines.length?`端末内の簡易作問で${lines.length}枚作成しました。AIは使用していません。`:'この文章では簡易作問できませんでした。AI作問を使うか、主語と説明がある文章を追加してください。');
  };

  $('#aiGenerate').onclick=async()=>{
    lastAiResult=null;
    const text=$('#source').value.trim();
    if(text.length<20)return setGenerated([],'教材本文を20文字以上入力してください。');
    const url=endpoint();
    if(!url){$('#status').className='status error';$('#status').textContent='AI APIは未接続です。設定タブでCloudflare Worker URLを登録してください。';return}
    $('#status').className='status';$('#status').textContent='GPT-5 nanoで作問中です。';
    try{
      const controller=new AbortController();const timer=setTimeout(()=>controller.abort(),45000);
      const response=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({text,count:Number($('#count').value),type:$('#type').value,difficulty:$('#difficulty').value}),signal:controller.signal});
      clearTimeout(timer);
      const payload=await response.json();
      if(!response.ok)throw new Error(payload.error||`HTTP ${response.status}`);
      const seen=new Set();const lines=(Array.isArray(payload.questions)?payload.questions:[]).map(question=>({front:String(question.question||'').trim(),back:String(question.answer||'').trim()})).filter(question=>{const key=norm(question.front)+'|'+norm(question.back);if(!question.front||!question.back||seen.has(key))return false;seen.add(key);return true}).map(question=>`${question.front}｜${question.back}`);
      const usage=payload.usage||{};const quality=payload.quality||{};
      lastAiResult={createdAt:new Date().toISOString(),model:payload.model||'unknown',reasoningEffort:payload.reasoningEffort||'unknown',sourceLength:text.length,type:$('#type').value,difficulty:$('#difficulty').value,requestedCount:Number($('#count').value),generatedCount:lines.length,usage,quality,elapsedMs:Number(payload.elapsedMs)||0};
      const metrics=`生出力${Number(quality.rawCount)||lines.length}件、採用${lines.length}件、重複除外${Number(quality.duplicateCount)||0}件、不適切除外${Number(quality.rejectedCount)||0}件、入力${Number(usage.inputTokens)||0}／出力${Number(usage.outputTokens)||0}トークン、${lastAiResult.elapsedMs?`${(lastAiResult.elapsedMs/1000).toFixed(1)}秒`:'時間未取得'}`;
      setGenerated(lines,`AI（${lastAiResult.model}・推論${lastAiResult.reasoningEffort}）で作成しました。${metrics}`,true);
    }catch(error){$('#qualityRow').classList.add('hidden');$('#status').className='status error';$('#status').textContent=`AI作問に失敗しました: ${error?.name==='AbortError'?'時間切れ':error instanceof Error?error.message:'原因不明のエラー'}。端末内簡易作問へは自動切替していません。`}
  };

  document.querySelectorAll('[data-quality]').forEach(button=>button.onclick=()=>{if(!lastAiResult)return;evaluations.push({...lastAiResult,rating:button.dataset.quality,cards:parseLines($('#generated').value)});if(evaluations.length>100)evaluations=evaluations.slice(-100);persistEvaluations();$('#qualityRow').classList.add('hidden');$('#status').textContent+=' 評価を端末内へ記録しました。';});
  $('#saveGenerated').onclick=()=>{let added=0;for(const item of parseLines($('#generated').value)){if(addCard(item.front,item.back))added++}persist();alert(`${added}枚保存しました。`)};
  $('#saveOne').onclick=()=>{if(!addCard($('#front').value,$('#back').value))return alert('未入力または同じカードが保存済みです。');$('#front').value='';$('#back').value='';persist()};
  $('#clearAll').onclick=()=>{if(confirm('すべてのカードを削除しますか？')&&confirm('取り消せません。実行しますか？')){cards=[];queue=[];persist();renderStudy()}};

  function startStudy(){queue=[...cards].sort(()=>Math.random()-.5).map(card=>card.id);position=0;backVisible=false;renderStudy()}
  function currentCard(){return cards.find(card=>card.id===queue[position])||null}
  function renderStudy(){const card=currentCard();const active=Boolean(card);$('#studyEmpty').classList.toggle('hidden',active);$('#studyArea').classList.toggle('hidden',!active);if(!active){$('#studyEmpty').textContent=queue.length&&position>=queue.length?'学習完了です。':'カードを保存してから学習を開始してください。';$('#bar').style.width=queue.length?'100%':'0%';return}$('#flashSide').textContent=backVisible?'裏':'表';$('#flashText').textContent=backVisible?card.back:card.front;$('#flipHint').textContent=`タップして${backVisible?'表':'裏'}へ`;$('#counter').textContent=`${position+1} / ${queue.length}`;$('#bar').style.width=`${position/queue.length*100}%`;$('#gradeRow').classList.toggle('hidden',!backVisible)}
  function flip(){if(!currentCard())return;backVisible=!backVisible;renderStudy()}
  function grade(correct){const card=currentCard();if(!card)return;correct?card.correct++:card.wrong++;if(!correct)queue.push(card.id);position++;backVisible=false;persist();renderStudy()}
  $('#startStudy').onclick=startStudy;$('#shuffleStudy').onclick=startStudy;$('#flashcard').onclick=flip;$('#flashcard').onkeydown=event=>{if(event.key==='Enter'||event.key===' '){event.preventDefault();flip()}};$('#speakFront').onclick=()=>{const card=currentCard();if(card)speak(card.front)};$('#speakBack').onclick=()=>{const card=currentCard();if(card)speak(card.back)};$('#again').onclick=()=>grade(false);$('#known').onclick=()=>grade(true);

  $('#apiUrl').value=configuredUrl();
  function renderApi(){const url=configuredUrl();$('#apiStatus').textContent=url?`設定済み: ${url}`:'未設定です。AI作問は利用できません。';$('#status').textContent=url?'AI API URLが設定されています。標準モデルはWorker側のGPT-5 nanoです。':'AI APIは未接続です。端末内簡易作問は別ボタンで利用できます。'}
  $('#saveApiUrl').onclick=()=>{const value=$('#apiUrl').value.trim();if(value&&!/^https:\/\//.test(value))return alert('https://から始まるURLを入力してください。');value?localStorage.setItem(URL_KEY,value):localStorage.removeItem(URL_KEY);renderApi()};
  function renderEvaluationStatus(){const good=evaluations.filter(item=>item.rating==='good').length;const edit=evaluations.filter(item=>item.rating==='edit').length;const bad=evaluations.filter(item=>item.rating==='bad').length;$('#evaluationStatus').textContent=`評価${evaluations.length}件：そのまま使える${good}件・要修正${edit}件・使えない${bad}件。`}
  $('#exportEvaluations').onclick=()=>{const blob=new Blob([JSON.stringify({exportedAt:new Date().toISOString(),evaluations},null,2)],{type:'application/json'});const anchor=document.createElement('a');anchor.href=URL.createObjectURL(blob);anchor.download=`toru-tango-nano-evaluations-${new Date().toISOString().slice(0,10)}.json`;anchor.click();URL.revokeObjectURL(anchor.href)};

  renderCards();renderStudy();renderApi();renderEvaluationStatus();
})();
