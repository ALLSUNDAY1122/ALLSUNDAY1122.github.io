(async()=>{
'use strict';
const parts=[1,2,3,4,5].map(n=>`./app-v0.7.2-${n}.part?v=073`);
try{
  const responses=await Promise.all(parts.map(path=>fetch(path,{cache:'no-cache'})));
  for(const response of responses){if(!response.ok)throw new Error(`script ${response.status}`)}
  let source=(await Promise.all(responses.map(response=>response.text()))).join('');

  source=source.replace("const VERSION='0.7.2';","const VERSION='0.7.3';");

  const oldPlay=/async function playBgm\(mode='timer'\)\{[\s\S]*?\n\}(?=\nfunction pauseBgm)/;
  if(!oldPlay.test(source))throw new Error('BGM playback function not found');
  source=source.replace(oldPlay,`async function playBgm(mode='timer'){
  if(mode==='timer'&&!state.settings.bgmEnabled)return false;
  audio.pendingTimerPlay=mode==='timer';
  if(!await unlockAudio())return false;
  try{
    await loadBgm();
    if(mode==='timer'&&audio.source&&audio.mode==='timer'){
      const now=audio.ctx.currentTime;
      audio.gain.gain.cancelScheduledValues(now);
      audio.gain.gain.setTargetAtTime(readForm().bgmVolume,now,.05);
      setAudioStatus('再生中','ready');
      return true;
    }
    const ok=startBuffer(mode);
    if(mode==='preview'&&ok)audio.previewTimer=setTimeout(()=>{stopBgm(true);toast('試聴を終了しました')},12000);
    return ok;
  }catch(error){
    console.error(error);
    if(mode==='timer')toast('BGMを読み込めませんでした。タイマーは続行します');
    return false;
  }
}`);

  const oldDuck=/function duckBgm\(\)\{[\s\S]*?\}(?=\nfunction tone)/;
  if(!oldDuck.test(source))throw new Error('BGM ducking function not found');
  source=source.replace(oldDuck,"function duckBgm(){}\n");

  (0,eval)(source);
  document.title='Sprint Study v0.7.3';
  const badge=document.querySelector('.version-badge');
  if(badge)badge.textContent='v0.7.3';
  const note=document.querySelector('.technical-note');
  if(note)note.insertAdjacentHTML('beforebegin','<p class="local-data-note">BGMはセッション中に止めたり音量を下げたりせず、曲の最後まで連続再生してから先頭へ戻ります。</p>');
}catch(error){
  console.error(error);
  document.body.innerHTML='<main style="font-family:-apple-system;padding:24px"><h1>Sprint Study</h1><p>アプリの読み込みに失敗しました。ページを再読み込みしてください。</p></main>';
}
})();
