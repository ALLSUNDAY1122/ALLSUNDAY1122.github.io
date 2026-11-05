'use client';
import {useMemo,useState} from 'react';
import type {Input} from '../lib/fortune';
import {buildDeepReading,type Blood,type Relation,type Extra} from '../lib/deep-reading';
const bloodOptions:{value:Blood;label:string}[]=[{value:'unknown',label:'選択しない'},{value:'A',label:'A型'},{value:'B',label:'B型'},{value:'O',label:'O型'},{value:'AB',label:'AB型'}];
const relationOptions:{value:Relation;label:string}[]=[{value:'partner',label:'恋人・気になる人'},{value:'friend',label:'友人'},{value:'mother',label:'母親'},{value:'father',label:'父親'},{value:'child',label:'子ども'},{value:'sibling',label:'きょうだい'},{value:'colleague',label:'職場の相手'}];
const defaultExtra:Extra={birthYear:'',blood:'unknown',otherBirthday:'',otherYear:'',otherBlood:'unknown',relation:'partner',parentBirthday:'',parentYear:''};
function validYear(s:string){return s===''||/^\d{4}$/.test(s)&&Number(s)>=1900&&Number(s)<=2026}
function validBirthday(s:string){if(s==='')return true;if(!/^\d{2}-\d{2}$/.test(s))return false;const[m,d]=s.split('-').map(Number);return m>=1&&m<=12&&d>=1&&d<=new Date(Date.UTC(2024,m,0)).getUTCDate()}
export default function PremiumPreview({input}:{input:Input}){
 const [extra,setExtra]=useState<Extra>({...defaultExtra,otherBirthday:input.kind==='compatibility'?input.partnerBirthday??'':''});
 const [opened,setOpened]=useState(false);
 const update=<K extends keyof Extra>(key:K,value:Extra[K])=>{setExtra(p=>({...p,[key]:value}));setOpened(false)};
 const valid=validYear(extra.birthYear)&&validYear(extra.otherYear)&&validYear(extra.parentYear)&&validBirthday(extra.otherBirthday)&&validBirthday(extra.parentBirthday)&&(!extra.birthYear||input.birthday!=='02-29'||Number(extra.birthYear)%4===0&&Number(extra.birthYear)%100!==0||Number(extra.birthYear)%400===0)&&(!extra.otherYear||extra.otherBirthday!=='02-29'||Number(extra.otherYear)%4===0&&Number(extra.otherYear)%100!==0||Number(extra.otherYear)%400===0);
 const result=useMemo(()=>valid?buildDeepReading(input,extra):null,[input.kind,input.birthday,input.partnerBirthday,input.concern,input.stage,input.goal,input.situation,extra,valid]);
 return <section className="premium" aria-label="多層鑑定の品質検証版">
  <p className="eyebrow">CHAPTER 03｜もっと深い星の世界へ</p>
  <h2>一つの星座だけでは、語りきれない。</h2>
  <p>あなたの太陽星座に、<strong>生まれ年と干支、数秘、血液型の物語</strong>を重ねると、同じ星座でも違う読み解きが生まれます。さらに、気になる人や親の誕生日を重ね、二人の星の関係をたどります。</p>
  <div className="specGrid"><div><strong>干支 × 太陽星座</strong><small>生まれ年が添える物語</small></div><div><strong>生年月日の数秘</strong><small>星座が同じでも異なる数字</small></div><div><strong>血液型の象徴</strong><small>任意・娯楽的な読み物</small></div><div><strong>大切な人との星</strong><small>恋人・家族・友人との縁</small></div></div>
  <p className="disclaimer">有料想定：自分の多層鑑定480円／相手や家族との関係鑑定980円。現在は全内容を無料体験できます。販売・決済は行いません。</p>
  <div className="premiumStudio">
   <h3>追加情報を重ねて、星の続きを読む</h3>
   <p>出生年や血液型は任意です。分からない場合は空欄にできます。入力した情報から計算できる占いのみ表示します。</p>
   <div className="formgrid">
    <label htmlFor="extra-year">あなたの生まれ年（西暦）<input id="extra-year" inputMode="numeric" value={extra.birthYear} maxLength={4} placeholder="例：1992" onChange={e=>update('birthYear',e.target.value)} /></label>
    <label htmlFor="extra-blood">あなたの血液型<select id="extra-blood" value={extra.blood} onChange={e=>update('blood',e.target.value as Blood)}>{bloodOptions.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select></label>
   </div>
   <div className="explain">
    <h3>気になる人との縁を重ねる</h3>
    <div className="formgrid">
     <label htmlFor="extra-rel">その人との関係<select id="extra-rel" value={extra.relation} onChange={e=>update('relation',e.target.value as Relation)}>{relationOptions.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select></label>
     <label htmlFor="extra-other">相手の誕生日（月-日）<input id="extra-other" placeholder="例：09-23" value={extra.otherBirthday} maxLength={5} onChange={e=>update('otherBirthday',e.target.value)}/></label>
     <label htmlFor="extra-other-year">相手の生まれ年（任意）<input id="extra-other-year" inputMode="numeric" placeholder="例：1991" maxLength={4} value={extra.otherYear} onChange={e=>update('otherYear',e.target.value)}/></label>
     <label htmlFor="extra-other-blood">相手の血液型（任意）<select id="extra-other-blood" value={extra.otherBlood} onChange={e=>update('otherBlood',e.target.value as Blood)}>{bloodOptions.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select></label>
    </div>
   </div>
   <details className="familyDetails"><summary>さらに親の誕生日を重ねて読む（任意）</summary>
    <div className="formgrid"><label htmlFor="parent-md">親の誕生日（月-日）<input id="parent-md" value={extra.parentBirthday} placeholder="例：06-15" maxLength={5} onChange={e=>update('parentBirthday',e.target.value)}/></label><label htmlFor="parent-year">親の生まれ年（任意）<input id="parent-year" value={extra.parentYear} placeholder="例：1965" inputMode="numeric" maxLength={4} onChange={e=>update('parentYear',e.target.value)}/></label></div>
   </details>
   <p className="disclaimer">入力値はこのブラウザ内でのみ処理し、当サイトのサーバーには送信・保存しません。他者の誕生日は本人のプライバシーに配慮して入力してください。</p>
   {!valid&&<p className="error" role="alert">生まれ年は1900〜2026、誕生日はMM-DD形式で入力してください。2月29日はうるう年のみ有効です。</p>}
   {result&&<div className="premiumSpec"><strong>この入力で重なる星の層</strong><div className="layerPills">{result.summary.map((s,i)=><span key={i}>{s}</span>)}</div></div>}
   <button className="secondary" type="button" disabled={!valid} onClick={()=>setOpened(v=>!v)}>{opened?'多層鑑定を閉じる':'重なった星の鑑定結果を読む（無料体験）'}</button>
   {opened&&result&&<article className="deepResult" aria-live="polite">
    <h2>{result.title}</h2><p className="lead">{result.intro}</p>
    {result.chapters.map((chapter,i)=><section className="deepChapter" key={i}><p className="eyebrow">{chapter.label}</p><h3>{chapter.title}</h3><p>{chapter.body}</p></section>)}
    <div className="method"><h3>鑑定方法と限界</h3><p>{result.method}</p><p>占術を重ねた結果は創作的・文化的な解釈です。相手の本心、親子関係、未来の成否を実際に知るものではありません。</p></div>
   </article>}
  </div>
 </section>;
}
