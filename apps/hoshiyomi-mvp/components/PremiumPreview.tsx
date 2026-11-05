'use client';
import {useState} from 'react';
import {makePremiumKit} from '../lib/premium-kit';
import type {Input} from '../lib/fortune';

export default function PremiumPreview({input}:{input:Input}){
 const kit=makePremiumKit(input);
 const [open,setOpen]=useState(false);
 const [branch,setBranch]=useState(0);
 const [checked,setChecked]=useState<boolean[]>(Array(7).fill(false));
 const [notes,setNotes]=useState<string[]>(Array(5).fill(''));
 const complete=checked.filter(Boolean).length;
 return <section className="premium" aria-label="有料商品品質評価">
  <p className="eyebrow">NEXT STEP｜あなた専用の実行設計書</p>
  <h2>「どうしたらいい？」を具体的な選択肢に変える</h2>
  <p>無料で分かったのは、星座の物語と、いま整理したい問題です。詳細レポートではその続きとして、<strong>いつ・何を伝え・反応別にどう動き・何を根拠に判断するか</strong>まで設計します。</p>
  <div className="premiumSpec"><p><strong>今回選んだ状況から作成</strong></p><p>{kit.context}</p></div>
  <div className="specGrid"><div><strong>3案比較</strong><small>進める・整理する・保留</small></div><div><strong>会話文3種類</strong><small>初回・曖昧・区切り</small></div><div><strong>7日間の計画</strong><small>行動・記録・判断基準</small></div><div><strong>反応別3分岐</strong><small>青・黄・赤の対応</small></div></div>
  <p className="disclaimer">商品予定価格：{input.kind==='compatibility'?'980':'480'}円（税込）。現在はコンテンツ品質評価中のため、<strong>課金せず全内容を試せます</strong>。本番販売は開始していません。</p>
  <button className="secondary" type="button" onClick={()=>setOpen(x=>!x)} aria-expanded={open}>{open?'実行設計書を閉じる':'この条件の実行設計書を無料で試す'}</button>
  {open&&<div className="premiumStudio">
   <h3>{kit.title}</h3><p>{kit.promise}</p>
   <h3>1｜まず3つの方針を比較する</h3>
   <div className="optionGrid">{kit.options.map((o,i)=><div className="optionCard" key={i}><h4>{o.name}</h4><p><strong>得られること：</strong>{o.benefit}</p><p><strong>注意：</strong>{o.cost}</p><p><strong>次の一歩：</strong>{o.next}</p></div>)}</div>
   <h3>2｜今すぐ使える文面</h3><p>選んだ出来事に合わせた文面です。相手の意思を尊重し、実際の事情に合わせて調整してください。</p>
   {kit.scripts.map((s,i)=><div className="scriptBox" key={i}><strong>{s.label}</strong><p>{s.text}</p></div>)}
   <h3>3｜相手や状況の反応で次の一歩を変える</h3>
   <div className="branchTabs">{kit.branches.map((b,i)=><button type="button" key={i} className={branch===i?'selectedBranch':'secondary'} onClick={()=>setBranch(i)} aria-pressed={branch===i}>{b.label.split('｜')[0]}</button>)}</div>
   <div className="branchBody"><strong>{kit.branches[branch].label}</strong><p>{kit.branches[branch].action}</p></div>
   {kit.pairExercise&&<div className="pairExercise"><p className="eyebrow">相性鑑定980円版の追加内容</p><h3>{kit.pairExercise.title}</h3><p>生年月日だけで相手の本心を決めつけず、双方の希望を本人が記入・確認する実践シートです。</p><ol>{kit.pairExercise.steps.map((step,i)=><li key={i}>{step}</li>)}</ol><p>{kit.pairExercise.agreement}</p></div>}
   <h3>4｜7日間の実行チェックリスト</h3>
   <p>達成率：{complete} / 7日。各日は必要に応じて休み、実施できた日だけチェックします。記録はこのページを閉じると失われます。</p>
   {kit.days.map((d,i)=><div className="dayCard" key={i}><label className="dayTitle"><input type="checkbox" checked={checked[i]} onChange={e=>setChecked(current=>current.map((v,j)=>i===j?e.target.checked:v))}/><strong>Day {d.day}｜{d.title}</strong></label><p>{d.do}</p><p><strong>残すもの：</strong>{d.record}</p><p><strong>判断基準：</strong>{d.gate}</p></div>)}
   <h3>5｜自分の状況を言語化する記入ワーク</h3>
   {kit.worksheet.map((w,i)=><label className="noteLabel" key={i}>{w.label}<small>{w.help}</small><textarea rows={2} maxLength={500} placeholder="自分の言葉で記入（保存・送信されません）" value={notes[i]} onChange={e=>setNotes(a=>a.map((v,j)=>i===j?e.target.value:v))}/></label>)}
   <p className="disclaimer">入力メモはブラウザの一時的な状態として扱い、サーバーには送信しません。ページを閉じると失われます。</p>
   <button className="secondary" type="button" onClick={()=>{const text=[kit.title,...kit.worksheet.map((w,i)=>w.label+'：'+notes[i])].join('\n');const b=new Blob([text],{type:'text/plain;charset=utf-8'});const u=URL.createObjectURL(b);const a=document.createElement('a');a.href=u;a.download='hoshiyomi-workbook.txt';a.click();URL.revokeObjectURL(u)}}>記入したワークをテキスト保存</button>
   <h3>最後に確認</h3><p>{kit.stopRule}</p><p className="disclaimer">{kit.closing}</p>
  </div>}
 </section>
}
