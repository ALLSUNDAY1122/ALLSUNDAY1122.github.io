(()=>{
const music=document.getElementById('musicTrack');
const $=id=>document.getElementById(id);
const PARTS=['./audio/deep-focus-0.m4a.part','./audio/deep-focus-1.m4a.part'];
const nativeAudio=window.Audio;
const srcDescriptor=Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype,'src');
const nativePlay=music.play.bind(music);
let objectUrl=null;
function setState(text,ready=false){if($('bgmFileName'))$('bgmFileName').textContent='Deep Focus Desk Work';if($('bgmFileBadge')){$('bgmFileBadge').textContent=text;$('bgmFileBadge').classList.toggle('ready',ready)}music.dataset.ready=ready?'1':'0'}
if($('audioCard')){const notice=$('audioCard').querySelector('.notice');if(notice)notice.textContent='アップロードされた「Deep Focus Desk Work」をアプリに同梱しました。ファイル選択は不要です。開始または試聴を押すと再生します。';const actions=$('audioCard').querySelector('.file-actions');if(actions)actions.style.display='none';if($('localBgmFile'))$('localBgmFile').style.display='none'}
try{Object.defineProperty(music,'src',{configurable:true,get(){return srcDescriptor.get.call(this)},set(v){if(typeof v==='string'&&v.includes('drive.google.com'))return;srcDescriptor.set.call(this,v)}})}catch{}
window.Audio=function(){return music};
try{window.Audio.prototype=nativeAudio.prototype}catch{}
async function loadBundled(){setState('読込中',false);const buffers=[];for(const url of PARTS){const r=await fetch(url,{cache:'force-cache'});if(!r.ok)throw new Error(`BGM ${r.status}`);buffers.push(await r.arrayBuffer())}const blob=new Blob(buffers,{type:'audio/mp4'});if(objectUrl)URL.revokeObjectURL(objectUrl);objectUrl=URL.createObjectURL(blob);srcDescriptor.set.call(music,objectUrl);music.preload='auto';music.loop=true;music.playsInline=true;music.load();setState('同梱済み',true);if($('audioState'))$('audioState').textContent='BGM準備済み';return music}
const ready=loadBundled().catch(e=>{console.error(e);setState('読込失敗',false);if($('audioState'))$('audioState').textContent='音源読込エラー';throw e});
music.play=async function(){await ready;return nativePlay()};
window.SprintStudyBundledBgm=ready;
})();