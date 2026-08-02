(()=>{
const DB='sprintStudyBgmDB',STORE='tracks',TRACK='deepfocus';let objectUrl=null,pending=null,bundled=document.getElementById('musicTrack').getAttribute('src')||'';
const $=id=>document.getElementById(id),music=()=>$('musicTrack');
function toast(t){const x=$('toast');if(!x)return;x.textContent=t;x.classList.add('show');setTimeout(()=>x.classList.remove('show'),2200)}
function state(name,ready){$('bgmFileName').textContent=name;$('bgmFileBadge').textContent=ready?'設定済み':'未設定';$('bgmFileBadge').classList.toggle('ready',ready);music().dataset.ready=ready?'1':'0'}
function openDb(){return new Promise((res,rej)=>{const r=indexedDB.open(DB,1);r.onupgradeneeded=()=>{if(!r.result.objectStoreNames.contains(STORE))r.result.createObjectStore(STORE)};r.onsuccess=()=>res(r.result);r.onerror=()=>rej(r.error)})}
async function get(){try{const d=await openDb();return await new Promise((res,rej)=>{const r=d.transaction(STORE).objectStore(STORE).get(TRACK);r.onsuccess=()=>res(r.result||null);r.onerror=()=>rej(r.error)})}catch{return null}}
async function put(v){const d=await openDb();return new Promise((res,rej)=>{const r=d.transaction(STORE,'readwrite').objectStore(STORE).put(v,TRACK);r.onsuccess=()=>res();r.onerror=()=>rej(r.error)})}
async function del(){try{const d=await openDb();await new Promise((res,rej)=>{const r=d.transaction(STORE,'readwrite').objectStore(STORE).delete(TRACK);r.onsuccess=()=>res();r.onerror=()=>rej(r.error)})}catch{}}
function use(blob,name){if(objectUrl)URL.revokeObjectURL(objectUrl);objectUrl=URL.createObjectURL(blob);music().src=objectUrl;music().load();state(name,true)}
async function load(){const x=await get();if(x?.blob){use(x.blob,x.name||'Deep Focus Desk Work');return}if(bundled){music().src=bundled;state('Deep Focus Desk Work（同梱）',true);return}music().removeAttribute('src');state('初回のみMP3を選択してください',false)}
function pick(el){pending=el||null;$('localBgmFile').value='';$('localBgmFile').click();toast('初回のみBGMファイルを選択してください')}
function needsFile(){return $('bgm').value!=='none'&&music().dataset.ready!=='1'}
function intercept(el){el.addEventListener('click',e=>{if(!needsFile())return;e.preventDefault();e.stopImmediatePropagation();pick(el)},true)}
$('chooseBgm').onclick=()=>pick(null);$('removeBgm').onclick=async()=>{music().pause();await del();if(objectUrl){URL.revokeObjectURL(objectUrl);objectUrl=null}if(bundled){music().src=bundled;state('Deep Focus Desk Work（同梱）',true)}else{music().removeAttribute('src');music().load();state('初回のみMP3を選択してください',false)}toast('保存したBGMを削除しました')};
$('localBgmFile').onchange=async e=>{const f=e.target.files?.[0];if(!f||!f.type.startsWith('audio/')){toast('MP3などの音声ファイルを選択してください');return}try{await put({blob:f,name:f.name,updatedAt:Date.now()});use(f,f.name);toast('BGMをこのiPhone内に保存しました');const x=pending;pending=null;if(x)setTimeout(()=>x.click(),80)}catch{toast('BGMの保存に失敗しました')}};
[$('mainBtn'),$('quickStart'),$('previewBgm'),...document.querySelectorAll('.q')].forEach(intercept);load();
})();