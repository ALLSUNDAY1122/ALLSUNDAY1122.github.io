'use client';
import {useRef,useState} from 'react';
import {reading,validInput,concernOptions,stageOptions,sign,type Input,type Kind,type Concern,type Stage} from '../lib/fortune';
import {lore,elementalMeaning,modeMeaning} from '../lib/astrology';
import PremiumPreview from './PremiumPreview';
import {situationOptions,goalOptions,type Situation,type Goal} from '../lib/personalization';

export default function Diagnosis({kind}:{kind:Kind}){
 const [birthday,setBirthday]=useState('03-21'),[partnerBirthday,setPartner]=useState('09-23');
 const [concern,setConcern]=useState<Concern>('uncertainty'),[stage,setStage]=useState<Stage>('ongoing');
 const [situation,setSituation]=useState<Situation>('mixed'),[goal,setGoal]=useState<Goal>('understand');
 const [show,setShow]=useState(false);
 const resultRef=useRef<HTMLElement>(null);
 const input:Input={kind,birthday,concern,stage,situation,goal,...(kind==='compatibility'?{partnerBirthday}:{})};
 const valid=validInput(input),result=valid?reading(input):null;
 const first=valid?lore[sign(birthday)]:null;
 const other=valid&&kind==='compatibility'?lore[sign(partnerBirthday)]:null;
 function reveal(){setShow(true);requestAnimationFrame(()=>resultRef.current?.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'start'}))}
 return <section className="panel diagnosisPanel">
  <div className="sectionHeading"><span className="orbDot" aria-hidden="true"/> <p className="eyebrow">01 — OPEN THE STARS</p></div>
  <h2>{kind==='love'?'恋愛の星を読む':kind==='career'?'仕事の星を読む':'ふたりの星を読む'}</h2>
  <p>星座が語り継ぐ物語から始まり、いまのあなたの関心へ。自分のペースで、少しずつ読み進めてください。</p>
  <details className="loreDisclosure"><summary>星占いの読み方を知る <span aria-hidden="true">✧</span></summary><p>西洋占星術では、誕生日のころに太陽が位置するとされる黄道十二宮の区分を「太陽星座」と呼びます。十二の星座には四元素（火・地・風・水）、活動・不動・柔軟という三区分、支配星など、長く受け継がれてきた象徴があります。</p><p>ここで扱うのは誕生日の月日から求める太陽星座です。出生時刻と場所が必要な月星座・上昇宮や、現在の天体運行を計算した鑑定ではありません。古くからの解釈を物語として楽しみつつ、自分に役立つ問いだけを選んでください。</p></details>
  <div className="ritualForm">
   <p className="eyebrow">星への問いかけ</p>
   <div className="formgrid"><label htmlFor="dob">あなたの誕生日（月-日）<input id="dob" value={birthday} onChange={e=>{setBirthday(e.target.value);setShow(false)}} maxLength={5} placeholder="03-21"/></label>
    {kind==='compatibility'&&<label htmlFor="partner">お相手の誕生日（月-日）<input id="partner" value={partnerBirthday} onChange={e=>{setPartner(e.target.value);setShow(false)}} maxLength={5} placeholder="09-23"/></label>}</div>
   <label htmlFor="concern">いま一番知りたいこと</label><select id="concern" value={concern} onChange={e=>{setConcern(e.target.value as Concern);setShow(false)}}>{concernOptions[kind].map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
   <label htmlFor="situation">直近で気になった出来事</label><select id="situation" value={situation} onChange={e=>{setSituation(e.target.value as Situation);setShow(false)}}>{situationOptions[kind].map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
   <details className="optionalQuestions"><summary>もう少し詳しく伝える <span aria-hidden="true">＋</span></summary><label htmlFor="goal">今回の鑑定で整理したいこと</label><select id="goal" value={goal} onChange={e=>{setGoal(e.target.value as Goal);setShow(false)}}>{goalOptions[kind].map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select>
   <label htmlFor="stage">現在の状況</label><select id="stage" value={stage} onChange={e=>{setStage(e.target.value as Stage);setShow(false)}}>{stageOptions.map(o=><option key={o.value} value={o.value}>{o.label}</option>)}</select></details>
   <button className="ritualButton" disabled={!valid} type="button" onClick={reveal}><span aria-hidden="true">✧</span> 星の扉をひらく <span aria-hidden="true">✧</span></button>
   {!valid&&<p className="error" role="alert">誕生日をMM-DD形式で入力してください。</p>}
  </div>
  {show&&result&&first&&<article ref={resultRef} className="result revealScene" aria-live="polite">
   <div className="chapterProgress" aria-label="鑑定の流れ"><span className="activeStep">I 星座</span><span>II あなたの今</span><span>III 深層鑑定</span></div>
   <div className="storyhead"><p className="eyebrow">CHAPTER I · THE CONSTELLATION</p><h2>{first.name}<span className="chapterSub"> — {first.symbol}</span></h2><p>{first.period} 生まれ</p></div>
   <div className="starEmblem" aria-hidden="true"><span>✦</span><small>{first.element} / {first.mode}</small></div>
   <p className="lead">{first.origin}</p>
   <div className="symbolStrip"><span>{first.element}の元素</span><span>{first.mode}</span><span>支配星：{first.ruler}</span></div>
   <details className="readingDetail"><summary><span>✧</span> 星の象徴をもっと知る <span className="openHint">ひらく</span></summary><div className="detailBody"><p>{elementalMeaning[first.element]} {modeMeaning[first.mode]}</p><h3>この星座が語る「光」と「影」</h3><p>{first.gift}</p><p>{first.shadow}</p><p>{kind==='career'?first.career:first.love}</p></div></details>
   {other&&<details className="readingDetail"><summary><span>✧</span> もうひとつの星座 — {other.name} <span className="openHint">ひらく</span></summary><div className="detailBody"><p>{other.origin}</p><p>二人の物語を照らし合わせるなら、片方の正しさを証明するのではなく、それぞれの大切にしたいことを言葉にするための材料として使います。</p></div></details>}
   <div className="storyhead"><p className="eyebrow">CHAPTER II · THE READING</p><h2>{result.title}</h2><p>テーマ：{result.subtitle}</p></div>
   <div className="messageHighlight"><span className="eyebrow">いまのあなたへの星の手紙</span><p>{result.intro}</p></div>
   <p className="readingGuide">この先は気になる項目だけ開いて読めます。文章は省略せず収録しています。</p>
   <div className="readingList">{result.sections.map((s,i)=><details className="readingDetail" key={i} open={i===0?true:undefined}><summary><span className="chapterIndex">{String(i+1).padStart(2,'0')}</span><span>{s.title}</span><span className="openHint">ひらく</span></summary><div className="detailBody"><p>{s.body}</p></div></details>)}</div>
   <p className="disclaimer">{result.caveat}</p>
   <PremiumPreview key={[kind,birthday,partnerBirthday,concern,stage,situation,goal].join('-')} input={input}/>
  </article>}
 </section>
}
