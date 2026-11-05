'use client';
import {useState} from 'react';
import {reading,validInput,products,concernOptions,stageOptions,report,sign,type Input,type Kind,type Concern,type Stage,type Product} from '../lib/fortune';
import {lore,elementalMeaning,modeMeaning} from '../lib/astrology';

export default function Diagnosis({kind}:{kind:Kind}){
 const [birthday,setBirthday]=useState('03-21'),[partnerBirthday,setPartner]=useState('09-23');
 const [concern,setConcern]=useState<Concern>('uncertainty'),[stage,setStage]=useState<Stage>('ongoing');
 const [show,setShow]=useState(false),[showSample,setShowSample]=useState(false);
 const [busy,setBusy]=useState(false),[error,setError]=useState('');
 const input:Input={kind,birthday,concern,stage,...(kind==='compatibility'?{partnerBirthday}:{})};
 const valid=validInput(input);
 const result=valid?reading(input):null;
 const first=valid?lore[sign(birthday)]:null;
 const other=valid&&kind==='compatibility'?lore[sign(partnerBirthday)]:null;
 const paid=valid?report(input,kind==='compatibility'?'pair':'detail'):null;
 async function pay(product:Product){setBusy(true);setError('');try{const r=await fetch('/api/checkout',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({input,product})});const j=await r.json();if(!r.ok||!j.url)throw Error(j.error||'決済を開始できません');location.assign(j.url)}catch(e){setError(e instanceof Error?e.message:'通信エラー');setBusy(false)}}
 return <section className="panel">
  <p className="eyebrow">星詠みの無料鑑定</p>
  <h2>{kind==='love'?'恋愛運':kind==='career'?'仕事運':'相性診断'}を深く読み解く</h2>
  <p>太陽星座の伝統的な物語と、いま抱えている悩みを重ねて考えます。最初に星の象徴を知り、その後であなたの状況に合わせた読み解きをお届けします。</p>
  <div className="explain"><h3>太陽星座占いの読み方</h3><p>西洋占星術では、誕生日のころに太陽が位置するとされる黄道十二宮の区分を「太陽星座」と呼びます。十二の星座には四元素（火・地・風・水）、活動・不動・柔軟という三区分、支配星など、長く受け継がれてきた象徴があります。</p><p>ここで扱うのは誕生日の月日から求める太陽星座です。出生時刻と場所が必要な月星座・上昇宮や、現在の天体運行を計算した鑑定ではありません。古くからの解釈を物語として楽しみつつ、自分に役立つ問いだけを選んでください。</p></div>
  <div className="formgrid">
   <label htmlFor="dob">あなたの誕生日（月-日）<input id="dob" value={birthday} onChange={e=>{setBirthday(e.target.value);setShow(false)}} maxLength={5} placeholder="03-21"/></label>
   {kind==='compatibility'&&<label htmlFor="partner">お相手の誕生日（月-日）<input id="partner" value={partnerBirthday} onChange={e=>{setPartner(e.target.value);setShow(false)}} maxLength={5} placeholder="09-23"/></label>}
  </div>
  <label htmlFor="concern">いま一番知りたいこと</label><select id="concern" value={concern} onChange={e=>{setConcern(e.target.value as Concern);setShow(false)}}>{concernOptions[kind].map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
  <label htmlFor="stage">現在の状況</label><select id="stage" value={stage} onChange={e=>{setStage(e.target.value as Stage);setShow(false)}}>{stageOptions.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
  <button disabled={!valid} onClick={()=>{setShow(true);setShowSample(false);setError('')}}>星の物語と鑑定結果を読む（無料）</button>
  {!valid&&<p className="error">月日を MM-DD で正しく入力してください。</p>}
  {show&&result&&first&&<article className="result" aria-live="polite">
   <div className="storyhead"><p className="eyebrow">CHAPTER 01 — 星座が受け継いできた物語</p><h2>{first.name} — {first.symbol}</h2><p>{first.period} 生まれ</p></div>
   <p className="lead">{first.origin}</p>
   <dl className="symbols"><div><dt>元素</dt><dd>{first.element} — {elementalMeaning[first.element]}</dd></div><div><dt>三区分</dt><dd>{first.mode} — {modeMeaning[first.mode]}</dd></div><div><dt>支配星</dt><dd>{first.ruler}</dd></div></dl>
   <h3>この星座が語る「光」と「影」</h3><p>{first.gift}</p><p>{first.shadow}</p>
   <p>{kind==='career'?first.career:first.love}</p>
   {other&&<div className="explain"><h3>もうひとつの星座 — {other.name}</h3><p>{other.origin}</p><p>二人の物語を照らし合わせるなら、片方の正しさを証明するのではなく、それぞれの大切にしたいことを言葉にするための材料として使います。</p></div>}
   <div className="storyhead"><p className="eyebrow">CHAPTER 02 — あなたの今を読み解く</p><h2>{result.title}</h2><p>テーマ：{result.subtitle}</p></div>
   {result.sections.map((s,i)=><div className="readingSection" key={i}><p className="step">0{i+1}</p><h3>{s.title}</h3><p>{s.body}</p></div>)}
   <p className="disclaimer">{result.caveat}</p>
   <div className="premium">
    <p className="eyebrow">CHAPTER 03 — さらに具体的な次の一歩</p><h2>有料版で追加される内容</h2>
    <p>無料版はここまでで完結します。有料版は一般的な性格説明を繰り返さず、今回選んだ悩みに合わせて「実際にどう動くか」を整理するためのレポートです。</p>
    <ul><li>7日間の行動計画（各日の課題と振り返り）</li><li>相手や周囲に伝えるための会話例</li><li>進捗を判断する観察指標</li><li>うまく進まない場合の代替案</li>{kind==='compatibility'&&<li>ふたりの価値観を並べる対話ワーク</li>}</ul>
    <button className="secondary" onClick={()=>setShowSample(v=>!v)}>{showSample?'サンプルを閉じる':'有料レポートの内容を確認する（無料）'}</button>
    {showSample&&paid&&<div className="sample"><p className="eyebrow">サンプル — 購入前の内容確認</p><h3>{paid.sections[5]?.title}</h3><p>{paid.sections[5]?.body}</p><p>実際の有料版は、これに続く残り6日分の計画と、会話例・チェック項目などで構成します。現在は品質検証中です。</p></div>}
    <p className="disclaimer">価格予定：{kind==='compatibility'?products.pair.price:products.detail.price}円（税込）。テスト決済は未接続のため、購入できません。</p>
    <button disabled className="disabledPay">{kind==='compatibility'?products.pair.name:products.detail.name}（準備中）</button>
    {error&&<p className="error" role="alert">{error}</p>}
   </div>
  </article>}
 </section>
}
