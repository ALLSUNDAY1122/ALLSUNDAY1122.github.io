(() => {
  'use strict';
  const CARD_KEY='toru-tango-beta-cards-v1';
  const URL_KEY='toru-tango-ai-url-v1';
  const EVAL_KEY='toru-tango-ai-evaluations-v1';
  const $=(selector)=>document.querySelector(selector);
  const norm=(value)=>String(value??'').trim().replace(/\s+/g,' ').toLocaleLowerCase('ja-JP');
  let cards=[];
  let evaluations=[];
  let lastAiResult=null;
  let selectedPhoto=null;
  let photoObjectUrl='';
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

  $('#photo').onchange=(event)=>{
    selectedPhoto=event.target.files?.[0]||null;
    $('#ocrText').classList.add('hidden');
    $('#useOcrText').classList.add('hidden');
    if(photoObjectUrl)URL.revokeObjectURL(photoObjectUrl);
    if(!selectedPhoto){$('#photoPreview').classList.add('hidden');return}
    photoObjectUrl=URL.createObjectURL(selectedPhoto);
    $('#photoPreview').src=photoObjectUrl;
    $('#photoPreview').classList.remove('hidden');
    $('#ocrStatus').className='status';
    $('#ocrStatus').classList.remove('hidden');
    $('#ocrStatus').textContent='写真を選択しました。「写真から文字を読む」を押してください。';
  };

  $('#runOcr').onclick=async()=>{
    if(!selectedPhoto)return alert('先に写真を撮るか選択してください。');
    const status=$('#ocrStatus');
    status.className='status';
    status.classList.remove('hidden');
    status.textContent='文字認識機能を読み込み中です。';
    try{
      if(!window.Tesseract){
        await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js';script.onload=resolve;script.onerror=reject;document.head.appendChild(script)});
      }
      const result=await window.Tesseract.recognize(selectedPhoto,'jpn+eng',{logger:(message)=>{if(typeof message.progress==='number')status.textContent=`文字認識中 ${Math.round(message.progress*100)}%`;}});
      const text=String(result?.data?.text||'').trim();
      if(!text)throw new Error('文字を認識できませんでした');
      $('#ocrText').value=text;
      $('#ocrText').classList.remove('hidden');
      $('#useOcrText').classList.remove('hidden');
      status.textContent='文字認識が完了しました。内容を確認して教材本文へ送ってください。';
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
