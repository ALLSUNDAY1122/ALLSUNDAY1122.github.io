const $=id=>document.getElementById(id), screen=$('screen'), key='itp-rebuild-study-v1';
let bank=[],state={records:{},mock:null},session=null,timer=null;
function el(tag,text,parent=screen,cls){const n=document.createElement(tag);if(text!==undefined)n.textContent=text;if(cls)n.className=cls;parent.append(n);return n}
function btn(text,fn,parent=screen,cls){const n=el('button',text,parent,cls);n.onclick=fn;return n}
function save(){try{localStorage.setItem(key,JSON.stringify(state))}catch{$('notice').textContent='学習記録を保存できません。ブラウザ設定をご確認ください。'}}
function clear(){clearInterval(timer);screen.replaceChildren()}
function record(q,i){const r=state.records[q.id]??{attempts:0,correct:0};r.attempts++;r.correct+=Number(i===q.correct_index);r.lastCorrect=i===q.correct_index;r.lastAt=new Date().toISOString();state.records[q.id]=r;save()}
const weak=()=>bank.filter(q=>state.records[q.id]?.lastCorrect===false);
function home(){clear();el('h2','今日の学習');el('p',Object.keys(state.records).length+' / 500問 学習済み');btn('今日の10問',()=>start([...weak(),...bank.filter(q=>!state.records[q.id]),...bank].filter((q,i,a)=>a.findIndex(x=>x.id===q.id)===i).slice(0,10),'今日の学習'),screen,'primary');el('h2','年度別演習');for(const y of [2022,2023,2024,2025,2026])btn(y+'年度・100問',()=>start(bank.filter(q=>q.year===y),y+'年度'));el('h2','分野別演習');for(const [d,label] of [['strategy','ストラテジ'],['management','マネジメント'],['technology','テクノロジ']]){const qs=bank.filter(q=>q.domain===d);btn(label+' '+qs.length+'問',()=>start(qs,label)).disabled=!qs.length}el('p','苦手復習：'+weak().length+'問')}
function review(){clear();el('h2','苦手復習');el('p','直近の回答が不正解：'+weak().length+'問');btn('復習開始',()=>start(weak(),'苦手復習'),screen,'primary').disabled=!weak().length}
function start(qs,mode){if(!qs.length)return;session={ids:qs.map(q=>q.id),mode,index:0,answers:{}};render()}
function renderText(text,parent){let lines=text.split('\n');for(let i=0;i<lines.length;){if(/^\s*\|.*\|\s*$/.test(lines[i])){const wrap=el('div',undefined,parent,'tablewrap'),table=el('table',undefined,wrap);let row=0;while(i<lines.length&&/^\s*\|.*\|\s*$/.test(lines[i])){let cells=lines[i++].trim().slice(1,-1).split('|');if(cells.every(c=>/^\s*:?-+:?\s*$/.test(c)))continue;let tr=el('tr',undefined,table);cells.forEach(c=>el(row===0?'th':'td',c.trim(),tr));row++}}else{let part=[];while(i<lines.length&&!/^\s*\|.*\|\s*$/.test(lines[i]))part.push(lines[i++]);el('div',part.join('\n'),parent,'question')}}}
function render(){clear();const s=session,q=bank.find(x=>x.id===s.ids[s.index]),mock=s.mode==='模試';if(!q)return;el('h2',s.mode+' '+(s.index+1)+' / '+s.ids.length);const p=el('progress');p.max=s.ids.length;p.value=s.index+1;el('p',q.year+'年度 問'+q.question_number);if(q.category&&q.subcategory)el('p',q.category+' ／ '+q.subcategory);renderText(q.question,screen);let src=el('div',undefined,screen,'source');const link=el('a',q.source_label,src);link.href=q.source_url;link.target='_blank';link.rel='noopener noreferrer';if(q.modified)el('p','改変あり：'+q.modification_note,src);else if(q.modification_note)el('p',q.modification_note,src);
q.choices.forEach((c,i)=>{const selected=s.answers[q.id];let b=btn('アイウエ'[i]+'　'+c,()=>{s.answers[q.id]=i;if(mock){state.mock=s;save()}else record(q,i);render()},screen,'choice');if(selected!==undefined){if(mock){if(selected===i)b.classList.add('selected')}else{b.disabled=true;if(i===q.correct_index)b.classList.add('correct');else if(i===selected)b.classList.add('wrong')}}});
if(!mock&&s.answers[q.id]!==undefined){
 el('p',s.answers[q.id]===q.correct_index?'正解':'不正解・正答：'+q.correct_label);
 showExplanation(q,screen);
}
const row=el('div',undefined,screen,'row');if(mock&&s.index>0)btn('前へ',()=>{s.index--;save();render()},row);btn(s.index===s.ids.length-1?'終了':'次へ',()=>{if(s.index===s.ids.length-1)finish();else{s.index++;if(mock)save();render()}},row).disabled=!mock&&s.answers[q.id]===undefined;
if(mock){const t=el('p','',screen);const tick=()=>{let left=Math.max(0,Math.ceil((s.deadline-Date.now())/1000));t.textContent='残り '+Math.floor(left/60)+':'+String(left%60).padStart(2,'0');if(!left)finish()};btn('採点する',()=>{if(confirm('模試を終了して採点しますか？'))finish()});timer=setInterval(tick,1000);tick()}}
function showExplanation(q,parent){
 const box=el('section',undefined,parent);
 el('h2','短い解説',box);renderText(q.short,box);
 const detail=el('details',undefined,box);el('summary','詳しい解説を見る',detail);renderText(q.detail,detail);
}
function finish(){clear();const s=session;let n=0;for(const id of s.ids){const q=bank.find(x=>x.id===id),i=s.answers[id];if(i===q.correct_index)n++;if(s.mode==='模試'&&i!==undefined)record(q,i)}if(s.mode==='模試'){state.mock=null;save()}el('h2','学習結果');el('p',n+' / '+s.ids.length+'問 正解（単純正答率 '+Math.round(n/s.ids.length*100)+'%）');el('p','公式IRT評価点・合否判定ではありません。');if(s.mode==='模試'){
 const review=el('details',undefined,screen);el('summary','全問の正答・解説を見る',review);
 for(const id of s.ids){
  const q=bank.find(x=>x.id===id),i=s.answers[id];
  const item=el('details',undefined,review);el('summary',q.year+'年度 問'+q.question_number+' ／ '+(i===undefined?'未回答':i===q.correct_index?'正解':'不正解'),item);
  renderText(q.question,item);q.choices.forEach((c,j)=>el('p','アイウエ'[j]+'　'+c,item));el('p','正答：'+q.correct_label,item);showExplanation(q,item);
 }
}
btn('ホームへ',home,screen,'primary');session=null}
function mockHome(){clear();el('h2','100問模試・120分');el('p','年度別の公式公開問題を使用。採点は終了時のみ。');if(state.mock){btn('保存済み模試を再開',()=>{session=state.mock;render()},screen,'primary');return}for(const y of [2022,2023,2024,2025,2026])btn(y+'年度',()=>{session={ids:bank.filter(q=>q.year===y).map(q=>q.id),mode:'模試',index:0,answers:{},deadline:Date.now()+7200000};state.mock=session;save();render()})}
async function init(){try{const res=await fetch('../generated/questions.json');if(!res.ok)throw Error('データ取得失敗');const d=await res.json();bank=d.questions;if(bank.length!==500||new Set(bank.map(q=>q.id)).size!==500)throw Error('問題数またはID不正');if(bank.some(q=>!['strategy','management','technology'].includes(q.domain)||!q.category||!q.subcategory))throw Error('分野分類データ不完全');if(bank.some(q=>typeof q.short!=='string'||!q.short.trim()||typeof q.detail!=='string'||!q.detail.trim()))throw Error('解説データ不完全');try{const saved=JSON.parse(localStorage.getItem(key)||'null');if(saved&&saved.records)state=saved}catch{$('notice').textContent='保存記録を読み込めませんでした。'}$('home').onclick=home;$('review').onclick=review;$('mock').onclick=mockHome;home()}catch(e){screen.textContent='起動できません：'+e.message}}
init();