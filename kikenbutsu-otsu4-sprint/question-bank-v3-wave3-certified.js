'use strict';
(function(){
const V=CONTENT_VERSION,CHECK='2026-08-09',BASE=[...QUESTIONS];
const LAW_URL='https://laws.e-gov.go.jp/law/323AC1000000186?occasion_date=20260809';
const DEC_URL='https://laws.e-gov.go.jp/law/334CO0000000306?occasion_date=20260809';
const CHEM_URL='https://www.fdma.go.jp/relocation/e-college/pdf/08-1-2.pdf';
const LAW_TITLE='消防法（e-Gov法令検索）',DEC_TITLE='危険物の規制に関する政令（e-Gov法令検索）',CHEM_TITLE='総務省消防庁 e-カレッジ｜危険物・基礎物理化学';
const CAT=[['特殊引火物',50],['第一石油類（非水溶性）',200],['第一石油類（水溶性）',400],['アルコール類',400],['第二石油類（非水溶性）',1000],['第二石油類（水溶性）',2000],['第三石油類（非水溶性）',2000],['第三石油類（水溶性）',4000],['第四石油類',6000],['動植物油類',10000]];
const SUB=[
 ['ジエチルエーテル',50,'S001','S002'],['二硫化炭素',50,'S005','S006'],['ガソリン',200,'S009','S010'],['ベンゼン',200,'S013','S014'],['トルエン',200,'S017','S018'],
 ['アセトン',400,'S021','S022'],['メタノール',400,'S025','S026'],['エタノール',400,'S029','S030'],['イソプロピルアルコール',400,'S033','S034'],
 ['灯油',1000,'S037','S038'],['軽油',1000,'S041','S042'],['重油',2000,'S045','S046'],['エチレングリコール',4000,'S049','S050'],
 ['引火点200℃以上250℃未満の潤滑油',6000,'S053','S054'],['動植物油類の定義に該当するなたね油',10000,'S057','S058']
];
function h(s){let x=2166136261;for(const c of s){x^=c.charCodeAt(0);x=Math.imul(x,16777619)}return x>>>0}
function fmt(x,d=3){const n=Math.round(x*10**d)/10**d;return Number.isInteger(n)?String(n):String(n)}
function uniq(a){return[...new Set(a.filter(v=>v!==undefined&&v!==null&&v!==''))]}
function pick5(id,correct,wrong=[],fallback=[]){const out=uniq([correct,...wrong,...fallback]);if(out.length<5)throw new Error(`${id}: choices<5`);out.splice(5);let seed=h(id),r=[];while(out.length){seed=(Math.imul(seed,1664525)+1013904223)>>>0;r.push(out.splice(seed%out.length,1)[0])}return[r,r.indexOf(correct)]}
function add(o){const [choices,answer]=pick5(o.id,o.correct,o.wrong,o.fallback||[]);QUESTIONS.push({id:o.id,subject:o.subject,topic:o.topic,question:o.question,choices,answer,point:o.point,detail:o.detail,tags:o.tags,sourceTitle:o.sourceTitle,sourceURL:o.sourceURL,sourceCheckedAt:CHECK,legalEffectiveDate:o.legalEffectiveDate??null,contentVersion:V,difficulty:o.difficulty??3,premium:true,sourceLocator:o.sourceLocator,sourceRefs:o.sourceRefs,learningObjective:o.objective,conceptKey:o.objective})}
function qid(p,n){return p+String(n).padStart(3,'0')}
function byId(id){const q=BASE.find(x=>x.id===id);if(!q)throw new Error('missing '+id);return q}
function ans(q){return q.choices[q.answer]}
function mergeRefs(qs){return uniq(qs.flatMap(q=>q.sourceRefs||[]).map(JSON.stringify)).map(JSON.parse)}
function lawRefs(locator='第10条第2項'){return[{title:LAW_TITLE,url:LAW_URL,locator},{title:DEC_TITLE,url:DEC_URL,locator:'別表第三'}]}
function chemRefs(locator){return[{title:CHEM_TITLE,url:CHEM_URL,locator}]}
function baseLaw(topic){const q=BASE.find(x=>x.subject==='法令'&&x.topic===topic);if(!q)throw new Error('missing law '+topic);return q}
function alt(pool,current,n=0){const a=uniq(pool).filter(x=>x!==current);if(!a.length)throw new Error('no alternative');return a[n%a.length]}

let L=241;
const fourSets=[
 [0,1,4,8,.10,.20,.25,.15],[2,3,5,9,.20,.15,.20,.10],[1,4,6,8,.30,.25,.15,.20],[0,5,7,9,.15,.20,.25,.10],
 [2,4,7,8,.25,.20,.10,.30],[3,5,6,9,.20,.30,.15,.10],[0,2,6,8,.25,.15,.20,.15],[1,3,7,9,.20,.25,.15,.20],
 [2,5,6,8,.30,.10,.25,.15],[0,4,7,9,.20,.15,.30,.10],[1,2,5,8,.15,.30,.20,.25],[3,4,6,9,.25,.20,.10,.30]
];
for(const row of fourSets){
 const idx=row.slice(0,4),fr=row.slice(4),items=idx.map((ci,i)=>[CAT[ci],fr[i]]),total=fr.reduce((a,b)=>a+b,0);
 const question=items.map(([c,f])=>`${c[0]}${Math.round(c[1]*f).toLocaleString('ja-JP')} L`).join('、');
 const correct=`${fmt(total)}倍`,wrong=[total-.20,total-.10,total+.10,total+.20].map(x=>`${fmt(x)}倍`),id=qid('L',L);
 add({id,subject:'法令',topic:'四品目倍数合算計算',question:`同一場所で${question}を貯蔵している。指定数量の倍数合計として正しいものはどれか。`,correct,wrong,
 point:`4品目を順に指定数量で割ると${fr.map(fmt).join('＋')}＝${fmt(total)}倍となる。`,
 detail:`${items.map(([c,f])=>`${c[0]}は${Math.round(c[1]*f).toLocaleString('ja-JP')} L÷${c[1].toLocaleString('ja-JP')} L＝${fmt(f)}倍`).join('、')}。品目ごとの倍数を合算して判定する。`,
 tags:['法令','指定数量','四品目','合算','計算'],sourceTitle:DEC_TITLE,sourceURL:DEC_URL,legalEffectiveDate:'2026-04-04',sourceLocator:'別表第三',sourceRefs:lawRefs(),objective:`wave3-law-four-total-${L}`});L++;
}
const reachSets=[
 [0,4,8,2,.10,.20,.20],[1,5,9,3,.15,.15,.20],[2,6,8,4,.20,.10,.25],[3,7,9,5,.25,.15,.10],
 [0,5,8,6,.20,.20,.15],[1,6,9,7,.10,.25,.20],[2,4,8,0,.15,.20,.25],[3,5,9,1,.20,.10,.30],
 [0,6,8,2,.25,.15,.10],[1,7,9,3,.20,.20,.15],[2,5,8,4,.10,.30,.20],[3,4,9,5,.15,.25,.20]
];
for(const [ai,bi,ci,di,fa,fb,fc] of reachSets){
 const a=CAT[ai],b=CAT[bi],c=CAT[ci],d=CAT[di],base=fa+fb+fc,gap=1-base,lit=Math.round(d[1]*gap),step=Math.max(1,Math.round(d[1]*.05));
 const correct=`${lit.toLocaleString('ja-JP')} L`,wrong=[lit-step*2,lit-step,lit+step,lit+step*2].map(x=>`${Math.max(1,x).toLocaleString('ja-JP')} L`),id=qid('L',L);
 add({id,subject:'法令',topic:'指定数量判定・到達量逆算計算',question:`同一場所に${a[0]}${Math.round(a[1]*fa).toLocaleString('ja-JP')} L、${b[0]}${Math.round(b[1]*fb).toLocaleString('ja-JP')} L、${c[0]}${Math.round(c[1]*fc).toLocaleString('ja-JP')} Lがある。ここへ${d[0]}を追加し、倍数合計をちょうど1.00倍にするときの追加量はどれか。`,correct,wrong,
 point:`現在は${fmt(fa)}＋${fmt(fb)}＋${fmt(fc)}＝${fmt(base)}倍なので、残り${fmt(gap)}倍。${d[0]}の指定数量${d[1].toLocaleString('ja-JP')} L×${fmt(gap)}＝${lit.toLocaleString('ja-JP')} L。`,
 detail:`既存3品目の倍数合計${fmt(base)}を先に求め、1.00との差${fmt(gap)}を追加品目の指定数量へ掛け戻す。指定数量の異なる品目をリットル数のまま足さない。`,
 tags:['法令','指定数量','逆算','追加量','計算'],sourceTitle:DEC_TITLE,sourceURL:DEC_URL,legalEffectiveDate:'2026-04-04',sourceLocator:'別表第三',sourceRefs:lawRefs(),objective:`wave3-law-reach-one-${L}`});L++;
}
const procFamilies=[
 ['設置許可','変更許可','完成検査','仮使用','廃止届','地位承継'],
 ['保安監督資格','保安監督実務','無資格者取扱','免状種類','乙種範囲','保安講習'],
 ['許可権者市町村','許可権者都道府県','広域移送許可','仮貯蔵承認','免状交付','監督者届']
];
const procIdx=[[0,1,2,3],[1,2,3,4],[2,3,4,5],[0,2,4,5]];
for(const fam of procFamilies){
 const qs=fam.map(baseLaw);
 for(const ix of procIdx){
  const chosen=ix.map(i=>qs[i]),topics=ix.map(i=>fam[i]),aa=chosen.map(ans);
  const correct=topics.map((t,i)=>`${t}：${aa[i]}`).join('／');
  const perms=[[1,0,2,3],[0,2,1,3],[0,1,3,2],[1,2,3,0]];
  const wrong=perms.map(p=>topics.map((t,i)=>`${t}：${aa[p[i]]}`).join('／'));
  const id=qid('L',L);
  add({id,subject:'法令',topic:'手続・資格四論点組合せ',question:`「${topics.join('」「')}」の4論点について、法令上の結論がすべて正しい組合せはどれか。`,correct,wrong,
   point:topics.map((t,i)=>`${t}は「${aa[i]}」`).join('、')+'。',
   detail:`4論点を個別に照合する。${topics[0]}と${topics[1]}だけでなく、${topics[2]}・${topics[3]}まで一致する選択肢を選ぶ。`,
   tags:['法令','手続','資格','四論点','組合せ'],sourceTitle:chosen[0].sourceTitle,sourceURL:chosen[0].sourceURL,legalEffectiveDate:chosen[0].legalEffectiveDate,sourceLocator:chosen.map(q=>q.sourceLocator).join('／'),sourceRefs:mergeRefs(chosen),objective:`wave3-law-procedure-four-${L}`});L++;
 }
}
const facilityFamilies=[
 ['簡易タンク数','簡易容量','簡易屋外空地','簡易室内間隔','簡易同品質'],
 ['移動容量','移動間仕切','移動鋼板','移動水圧','圧力タンク試験'],
 ['屋内タンク間隔','屋内タンク容量','圧力タンク設備','屋外空地500','屋外空地1000'],
 ['屋外空地1000','屋外空地2000','屋外空地3000','屋外空地4000','接地電極']
];
const fix=[[0,1,2,3],[1,2,3,4],[0,2,3,4]];
for(const fam of facilityFamilies){
 const qs=fam.map(baseLaw);
 for(const ix of fix){
  const chosen=ix.map(i=>qs[i]),topics=ix.map(i=>fam[i]),aa=chosen.map(ans),correct=topics.map((t,i)=>`${t}：${aa[i]}`).join('／');
  const perms=[[1,0,2,3],[0,2,1,3],[0,1,3,2],[1,2,3,0]];
  const wrong=perms.map(p=>topics.map((t,i)=>`${t}：${aa[p[i]]}`).join('／'));
  const id=qid('L',L);
  add({id,subject:'法令',topic:'施設四論点組合せ',question:`製造所等の位置・構造・設備に関する「${topics.join('」「')}」の4項目について、基準値または要件がすべて正しい組合せはどれか。`,correct,wrong,
   point:topics.map((t,i)=>`${t}は「${aa[i]}」`).join('、')+'。',
   detail:`設備基準は対象設備ごとに条件が異なる。${topics.join('・')}を一対一で対応させ、4項目すべて一致するか確認する。`,
   tags:['法令','施設基準','四論点','組合せ'],sourceTitle:chosen[0].sourceTitle,sourceURL:chosen[0].sourceURL,legalEffectiveDate:chosen[0].legalEffectiveDate,sourceLocator:chosen.map(q=>q.sourceLocator).join('／'),sourceRefs:mergeRefs(chosen),objective:`wave3-law-facility-four-${L}`});L++;
 }
}
if(L!==289)throw new Error('law wave3 count='+(L-241));

let P=161;
const mech=[
 ['冷却消火','隣接タンク外壁が火炎で加熱されている。延焼防止のため外壁へ散水する主な狙いはどれか。','タンク壁と内容物の温度上昇を抑え、着火・破損の危険を下げる','酸素濃度だけを下げて燃焼を止める','可燃物を設備外へ移して燃料をなくす','連鎖反応だけを化学的に遮断する','蒸気圧を一定値へ固定して燃焼を止める'],
 ['冷却消火','燃焼中の液体そのものではなく周囲設備を散水冷却する場面で、最も直接的な効果はどれか。','周囲設備への熱移動を抑え、二次着火や損傷を防ぐ','可燃性蒸気を不燃性ガスへ置き換える','燃料濃度を自動的に燃焼下限未満へする','酸化反応の活性種だけを消失させる','液体の指定数量区分を変化させる'],
 ['窒息消火','密閉性を確保できる区画で不活性ガスを用いるとき、消火原理として最も適切なものはどれか。','燃焼を支える酸素濃度を低下させる','燃料表面の温度だけを引火点未満へ下げる','燃焼物を設備外へ移して量を減らす','静電気を接地へ流して火花を防ぐ','液体の沸点を上げて蒸発を止める'],
 ['窒息消火','泡で燃焼液面を覆う操作に期待する中心的な効果はどれか。','液面を空気から遮断し、蒸気供給と酸素接触を抑える','液体の比熱をゼロに近づけて急冷する','燃料を化学的に不燃物へ変換する','容器の接地抵抗を下げて帯電を防ぐ','指定数量倍数を小さくして火勢を弱める'],
 ['静電気','絶縁性液体を配管で高速移送するとき、流速を下げる理由として最も適切なものはどれか。','電荷の発生・蓄積を抑え、放電着火の可能性を下げる','液体の指定数量を小さくして法規制を外す','空気中の酸素濃度を下げて燃焼を防ぐ','液体の発火点を上げて着火しにくくする','蒸気の比重を小さくして上方へ逃がす'],
 ['静電気','液体を容器へ落下させず、注入管先端を液中へ近づける運用の目的として適切なものはどれか。','飛散・摩擦による帯電を抑え、静電気放電の危険を下げる','液体の密度を高めて蒸発量を減らす','容器内の酸素を完全に排除する','危険物の品名区分を低危険側へ変える','燃焼上限を引き上げて着火範囲を狭める'],
 ['接地','金属製設備を接地する対策が有効となる理由として最も適切なものはどれか。','設備に蓄積した電荷を大地へ逃がし、電位差を小さくする','液体温度を直接下げて引火点未満に保つ','可燃性蒸気を水へ吸収して濃度を下げる','液体の蒸気圧を一定に保って揮発を止める','燃料供給配管を閉止して可燃物を除去する'],
 ['接地','二つの金属容器間で移替えを行う前にボンディングと接地を確認する主目的はどれか。','容器間の電位差と対地電位を抑え、火花放電を防ぐ','液体の比重差を小さくして混合を均一にする','蒸発潜熱を大きくして液温を下げる','燃焼範囲そのものを狭くして着火を防ぐ','指定数量倍数を容器間で均等にする']
];
for(const [topic,q,c,...w] of mech){const id=qid('P',P);add({id,subject:'物理・化学',topic,question:q,correct:c,wrong:w,point:c+'。',detail:`${topic}の原理を、設備・移送条件を含む具体的な場面に当てはめて判断する。設問${id}では他の消火原理や物性変化と混同しない。`,tags:['物理・化学',topic,'実務場面'],sourceTitle:CHEM_TITLE,sourceURL:CHEM_URL,sourceLocator:`${topic}・火災予防`,sourceRefs:chemRefs(`${topic}・火災予防`),objective:`wave3-physics-mechanism-${P}`});P++;}
const concept=[
 ['引火点','引火点より十分低い温度の液体について、一般に最も適切な説明はどれか。','通常はその温度で点火源を近づけても燃焼を始めるだけの蒸気が生じにくい','外部点火源がなくても必ず自己発火する温度である','液体の沸騰が必ず始まる温度である','蒸気圧が大気圧と等しくなる温度である','燃焼上限濃度が最大になる温度である'],
 ['引火点','同じ取扱条件なら、引火点の低い液体をより慎重に扱う理由として適切なものはどれか。','低い液温でも点火可能な濃度の蒸気を生じやすいから','液体の比熱が必ず大きくなるから','水への溶解度が必ず高くなるから','蒸気が必ず空気より軽くなるから','指定数量が必ず大きくなるから'],
 ['発火点','発火点の説明として最も適切なものはどれか。','外部の火炎などを直接与えなくても燃焼を開始し得る最低温度の指標である','液面上の蒸気へ火炎を近づけた瞬間だけ燃える最低温度である','液体が標準大気圧で沸騰を開始する温度である','液体の蒸気圧がゼロに近づく温度である','燃焼下限と上限が一致する温度である'],
 ['発火点','高温配管へ漏えい液が接触する事故で発火点を意識する理由として適切なものはどれか。','配管表面が十分高温なら、裸火がなくても着火源になり得るから','高温面では液体の指定数量が減少するから','発火点を超えると液体が必ず水溶性になるから','高温面では蒸気の比重が必ず1になるから','発火点を超えると酸素が不要になるから'],
 ['蒸気圧','同一物質で液温が上昇したときの蒸気圧の一般的な変化として適切なものはどれか。','液温が高いほど蒸気圧は大きくなる傾向がある','液温が高いほど蒸気圧は小さくなる傾向がある','液温にかかわらず蒸気圧は一定である','沸点より低ければ蒸気圧は存在しない','蒸気圧は液体の量だけで決まり温度に依存しない'],
 ['蒸気圧','密閉容器を日射で加熱しないよう管理する理由を蒸気圧の観点から説明したものはどれか。','温度上昇に伴う蒸気圧上昇が容器内圧上昇につながり得るから','温度上昇で蒸気圧が下がり容器が必ず真空になるから','温度上昇で液体の質量が急増するから','温度上昇で気体定数が変化するから','温度上昇で液体の指定数量区分が消失するから'],
 ['比熱','同じ質量へ同じ熱量を加えるとき、比熱が大きい物質ほどどうなるか。','温度上昇は小さくなる','温度上昇は大きくなる','必ず沸騰する','必ず蒸発量が同じになる','体積が必ず半分になる'],
 ['比熱','同じ質量の二物質を同じ温度だけ上げる場合、比熱が大きい物質について適切なものはどれか。','必要な熱量は大きくなる','必要な熱量は小さくなる','必要な熱量は常に同じである','密度だけで必要熱量が決まる','蒸気圧だけで必要熱量が決まる']
];
for(const [topic,q,c,...w] of concept){const id=qid('P',P);add({id,subject:'物理・化学',topic,question:q,correct:c,wrong:w,point:c+'。',detail:`${topic}の定義・温度依存性を実際の取扱条件へ適用する。設問${id}は類似概念との区別を要求する。`,tags:['物理・化学',topic,'概念適用'],sourceTitle:CHEM_TITLE,sourceURL:CHEM_URL,sourceLocator:`${topic}・基礎物理化学`,sourceRefs:chemRefs(`${topic}・基礎物理化学`),objective:`wave3-physics-concept-${P}`});P++;}
const heatCases=[[2,2.0,20,50,150],[3,1.5,15,45,120],[1.5,2.4,25,55,180],[2.5,1.8,10,40,160],[4,1.2,20,35,140],[1.2,3.0,30,60,200],[3.5,1.4,18,48,170],[2.2,2.2,22,52,190]];
for(const [m,c,t1,t2,Lh] of heatCases){
 const sensible=m*c*(t2-t1),latent=m*Lh,total=sensible+latent,id=qid('P',P),correct=`${Math.round(total)} kJ`,wrong=[total-sensible*.25,total-latent*.2,total+sensible*.2,total+latent*.15].map(x=>`${Math.round(x)} kJ`);
 add({id,subject:'物理・化学',topic:'熱収支二段階計算',question:`質量${m} kg、比熱${c} kJ/(kg・K)の液体を${t1}℃から${t2}℃まで加熱した後、その全量を蒸発させる。蒸発潜熱を${Lh} kJ/kgとすると、必要な総熱量はどれか。熱損失は無視する。`,correct,wrong,
 point:`顕熱${fmt(m)}×${fmt(c)}×(${t2}−${t1})＝${fmt(sensible)} kJ、潜熱${fmt(m)}×${Lh}＝${fmt(latent)} kJ、合計${Math.round(total)} kJ。`,
 detail:`加熱段階q=mcΔTと相変化段階q=mLを分けて求め、最後に合算する。設問${id}では温度差${t2-t1} Kと質量${m} kgを両段階で正しく用いる。`,
 tags:['物理・化学','熱量','蒸発潜熱','二段階','計算'],sourceTitle:CHEM_TITLE,sourceURL:CHEM_URL,sourceLocator:'熱量・比熱・蒸発潜熱',sourceRefs:chemRefs('熱量・比熱・蒸発潜熱'),objective:`wave3-physics-heat-two-stage-${P}`});P++;
}
const concCases=[[4,80,20,1.4,7.6],[6,120,30,2.0,8.0],[5,100,25,1.5,7.0],[8,160,40,2.5,9.5],[3,75,25,1.2,6.5],[7,140,60,2.0,8.5],[4.5,90,30,1.8,7.8],[9,180,45,3.0,10.0]];
for(const [vap,air,addAir,lel,uel] of concCases){
 const conc=vap/(vap+air+addAir)*100,inside=conc>=lel&&conc<=uel,correct=`${fmt(conc,2)} vol%・${inside?'燃焼範囲内':'燃焼範囲外'}`;
 const vals=[conc*.75,conc*.9,conc*1.1,conc*1.25],wrong=vals.map((x,i)=>`${fmt(x,2)} vol%・${i%2===0?(inside?'燃焼範囲外':'燃焼範囲内'):(x>=lel&&x<=uel?'燃焼範囲内':'燃焼範囲外')}`),id=qid('P',P);
 add({id,subject:'物理・化学',topic:'希釈後燃焼濃度計算',question:`可燃性蒸気${vap} Lと空気${air} Lの混合気へ、さらに空気${addAir} Lを加えた。体積は加算できるものとし、この蒸気の燃焼範囲を${lel}〜${uel} vol%とする。希釈後の蒸気濃度と燃焼範囲判定の組合せとして正しいものはどれか。`,correct,wrong,
 point:`希釈後濃度は${vap}÷(${vap}＋${air}＋${addAir})×100＝${fmt(conc,2)} vol%。これを${lel}〜${uel} vol%と比較する。`,
 detail:`空気追加後の総体積${vap+air+addAir} Lを分母にする。設問${id}では計算値${fmt(conc,2)} vol%が燃焼下限・上限のどちら側にあるかまで判定する。`,
 tags:['物理・化学','燃焼範囲','希釈','濃度','計算'],sourceTitle:CHEM_TITLE,sourceURL:CHEM_URL,sourceLocator:'燃焼範囲・濃度計算',sourceRefs:chemRefs('燃焼範囲・濃度計算'),objective:`wave3-physics-dilution-${P}`});P++;
}
if(P!==193)throw new Error('physics wave3 count='+(P-161));

let S=201;
const subFour=[[0,2,9,13,.2,.25,.3,.1],[1,5,10,14,.1,.3,.25,.15],[2,6,11,12,.35,.2,.15,.1],[3,7,9,14,.2,.25,.2,.1],[4,8,10,13,.3,.15,.25,.1],[0,5,11,14,.15,.2,.25,.1],[1,6,9,12,.2,.15,.3,.1],[2,7,10,13,.25,.2,.15,.2],[3,8,11,14,.2,.3,.1,.15],[4,5,9,12,.15,.25,.2,.2]];
for(const row of subFour){
 const ix=row.slice(0,4),fr=row.slice(4),mats=ix.map(i=>SUB[i]),total=fr.reduce((a,b)=>a+b,0),parts=mats.map((m,i)=>`${m[0]}${Math.round(m[1]*fr[i]).toLocaleString('ja-JP')} L`);
 const correct=`${fmt(total)}倍`,wrong=[total-.15,total-.10,total+.10,total+.15].map(x=>`${fmt(x)}倍`),id=qid('S',S),refs=mergeRefs(mats.map(m=>byId(m[2])));
 add({id,subject:'性質・消火',topic:'比較応用・四品目倍数計算',question:`同一場所に${parts.join('、')}がある。これら4物質の指定数量倍数合計として正しいものはどれか。`,correct,wrong,
 point:`各量をそれぞれの指定数量で割ると${fr.map(fmt).join('＋')}＝${fmt(total)}倍。`,
 detail:`${mats.map((m,i)=>`${m[0]}は${Math.round(m[1]*fr[i]).toLocaleString('ja-JP')} L÷${m[1].toLocaleString('ja-JP')} L＝${fmt(fr[i])}倍`).join('、')}。物質名から法令区分を対応させてから合算する。`,
 tags:['性質・消火','物質名','指定数量','四品目','計算'],sourceTitle:DEC_TITLE,sourceURL:DEC_URL,legalEffectiveDate:'2026-04-04',sourceLocator:'別表第三',sourceRefs:refs,objective:`wave3-properties-four-total-${S}`});S++;
}
const triples=[[0,5,9],[1,6,10],[2,7,11],[3,8,12],[4,5,13],[0,6,14],[1,7,9],[2,8,10],[3,5,11],[4,6,12]];
for(const ix of triples){
 const mats=ix.map(i=>SUB[i]),facts=mats.map(m=>[ans(byId(m[2])),ans(byId(m[3]))]),correct=mats.map((m,i)=>`${m[0]}：${facts[i][0]}・${facts[i][1]}`).join('／');
 const classPool=SUB.map(m=>ans(byId(m[2]))),waterPool=SUB.map(m=>ans(byId(m[3])));
 const wrong=[
   mats.map((m,i)=>`${m[0]}：${i===0?alt(classPool,facts[i][0],1):facts[i][0]}・${facts[i][1]}`).join('／'),
   mats.map((m,i)=>`${m[0]}：${facts[i][0]}・${i===1?alt(waterPool,facts[i][1],2):facts[i][1]}`).join('／'),
   mats.map((m,i)=>`${m[0]}：${i===2?alt(classPool,facts[i][0],3):facts[i][0]}・${facts[i][1]}`).join('／'),
   mats.map((m,i)=>`${m[0]}：${facts[i][0]}・${i===0?alt(waterPool,facts[i][1],4):facts[i][1]}`).join('／')
 ];
 const id=qid('S',S),srcqs=mats.flatMap(m=>[byId(m[2]),byId(m[3])]);
 add({id,subject:'性質・消火',topic:'水溶性・品名組合せ',question:`${mats.map(m=>m[0]).join('、')}について、法令上の品名区分と水との関係がすべて正しい組合せはどれか。`,correct,wrong,
 point:mats.map((m,i)=>`${m[0]}は${facts[i][0]}で、${facts[i][1]}`).join('。')+'。',
 detail:`品名区分と水溶性は別論点として確認する。設問${id}では3物質について両方の属性が一致する選択肢だけが正解となる。`,
 tags:['性質・消火','品名区分','水溶性','三物質','組合せ'],sourceTitle:srcqs[0].sourceTitle,sourceURL:srcqs[0].sourceURL,sourceLocator:srcqs.map(q=>q.sourceLocator).join('／'),sourceRefs:mergeRefs(srcqs),objective:`wave3-properties-class-solubility-${S}`});S++;
}
const actionTopics=['低所蒸気','静電気','水面拡大','耐アルコール泡','隣接冷却','燃料遮断','再着火','ミスト','高温面','油布発熱','流出封じ','濃度測定','防爆換気','消火剤適応','事故通報'];
const actionQs=actionTopics.map(t=>{const q=BASE.find(x=>x.subject==='性質・消火'&&x.topic===t);if(!q)throw new Error('missing action '+t);return q});
const actionTriples=[[0,1,4],[2,3,5],[6,7,8],[9,10,11],[12,13,14],[0,5,10],[1,6,12],[2,7,13],[3,8,14],[4,9,11]];
for(const ix of actionTriples){
 const chosen=ix.map(i=>actionQs[i]),topics=ix.map(i=>actionTopics[i]),aa=chosen.map(ans),correct=topics.map((t,i)=>`${t}：${aa[i]}`).join('／');
 const perms=[[1,0,2],[0,2,1],[2,1,0],[1,2,0]];
 const wrong=perms.map(p=>topics.map((t,i)=>`${t}：${aa[p[i]]}`).join('／'));
 const id=qid('S',S);
 add({id,subject:'性質・消火',topic:'消火・予防戦術組合せ',question:`第四類危険物の火災予防・事故対応に関する「${topics.join('」「')}」の3場面について、対応がすべて適切な組合せはどれか。`,correct,wrong,
 point:topics.map((t,i)=>`${t}では「${aa[i]}」`).join('、')+'。',
 detail:`危険物の性状、蒸気挙動、帯電、消火剤適応を場面ごとに切り分ける。設問${id}は3場面すべてに適切な対応を選ぶ複合問題である。`,
 tags:['性質・消火','火災予防','事故対応','三場面','組合せ'],sourceTitle:chosen[0].sourceTitle,sourceURL:chosen[0].sourceURL,sourceLocator:chosen.map(q=>q.sourceLocator).join('／'),sourceRefs:mergeRefs(chosen),objective:`wave3-properties-response-triple-${S}`});S++;
}
const rankSets=[[0,2,9],[1,5,10],[2,6,11],[3,7,12],[4,8,13],[0,5,14],[1,6,9],[2,7,10],[3,8,11],[4,5,12]];
const rankFr=[[.25,.6,.4],[.5,.3,.7],[.45,.8,.2],[.65,.35,.5],[.55,.25,.75],[.4,.7,.3],[.6,.2,.45],[.3,.75,.5],[.7,.4,.25],[.5,.65,.35]];
for(let k=0;k<rankSets.length;k++){
 const mats=rankSets[k].map(i=>SUB[i]),fr=rankFr[k],amounts=mats.map((m,i)=>Math.round(m[1]*fr[i]));
 const order=[0,1,2].sort((a,b)=>fr[b]-fr[a]),correct=order.map(i=>mats[i][0]).join(' ＞ '),perms=[[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]].map(p=>p.map(i=>mats[i][0]).join(' ＞ ')).filter(x=>x!==correct),id=qid('S',S);
 add({id,subject:'性質・消火',topic:'比較応用・保有量順位',question:`${mats.map((m,i)=>`${m[0]}${amounts[i].toLocaleString('ja-JP')} L`).join('、')}を別々に保有している。指定数量に対する倍数が大きい順に並べたものはどれか。`,correct,wrong:perms.slice(0,4),fallback:perms.slice(4),
 point:mats.map((m,i)=>`${m[0]}は${amounts[i].toLocaleString('ja-JP')}÷${m[1].toLocaleString('ja-JP')}＝${fmt(fr[i])}倍`).join('、')+'。',
 detail:`リットル数の大小ではなく、各物質の指定数量に対する比で順位付けする。設問${id}では${fr.map(fmt).join('・')}倍を比較する。`,
 tags:['性質・消火','物質名','指定数量','比較','順位'],sourceTitle:DEC_TITLE,sourceURL:DEC_URL,legalEffectiveDate:'2026-04-04',sourceLocator:'別表第三',sourceRefs:mergeRefs(mats.map(m=>byId(m[2]))),objective:`wave3-properties-holding-rank-${S}`});S++;
}
if(S!==241)throw new Error('properties wave3 count='+(S-201));
if(QUESTIONS.length!==720)throw new Error('wave3 total='+QUESTIONS.length);
})();
