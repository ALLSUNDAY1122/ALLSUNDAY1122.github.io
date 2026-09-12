'use strict';
(function(){
  const qty={'特殊引火物':50,'第一石油類（非水溶性）':200,'第一石油類（水溶性）':400,'アルコール類':400,'第二石油類（非水溶性）':1000,'第二石油類（水溶性）':2000,'第三石油類（非水溶性）':2000,'第三石油類（水溶性）':4000,'第四石油類':6000,'動植物油類':10000};
  const subQty={'ジエチルエーテル':50,'二硫化炭素':50,'ガソリン':200,'ベンゼン':200,'トルエン':200,'アセトン':400,'メタノール':400,'エタノール':400,'イソプロピルアルコール':400,'灯油':1000,'軽油':1000,'重油':2000,'エチレングリコール':4000,'引火点200℃以上250℃未満の潤滑油':6000,'動植物油類の定義に該当するなたね油':10000};
  const cats=Object.keys(qty);
  const clean=n=>Math.round(n*1000)/1000;
  const setCorrect=(q,correct,wrongs)=>{
    const pool=[correct,...wrongs].filter((v,i,a)=>a.indexOf(v)===i).slice(0,5);
    while(pool.length<5)pool.push(`該当しない ${pool.length}`);
    const shift=Number(q.id.slice(1))%5;
    q.choices=pool.slice(shift).concat(pool.slice(0,shift));
    q.answer=q.choices.indexOf(correct);
  };
  const multChoices=x=>[clean(Math.max(.05,x-.5))+'倍',clean(Math.max(.05,x-.25))+'倍',clean(x+.25)+'倍',clean(x+.5)+'倍',clean(x+1)+'倍'];

  for(const q of QUESTIONS.filter(q=>q.subject==='法令'&&q.topic==='指定数量計算')){
    const cat=cats.find(k=>q.question.includes(k));
    const m=q.question.match(/([\d,]+) L/);
    if(!cat||!m)throw new Error(`${q.id}: single quantity fixup parse failed`);
    const amount=Number(m[1].replace(/,/g,''));
    const x=clean(amount/qty[cat]);
    setCorrect(q,x+'倍',multChoices(x));
    q.point=`${amount.toLocaleString('ja-JP')}÷${qty[cat].toLocaleString('ja-JP')}＝${x}倍。`;
    q.detail=`${cat}の指定数量${qty[cat].toLocaleString('ja-JP')}Lを分母にし、実数量${amount.toLocaleString('ja-JP')}Lを割る。この条件では${x}倍となる。`;
  }

  for(const q of QUESTIONS.filter(q=>q.subject==='性質・消火'&&q.topic==='指定数量応用')){
    const name=Object.keys(subQty).find(k=>q.question.includes(k));
    const m=q.question.match(/([\d,]+) L/);
    if(!name||!m)throw new Error(`${q.id}: substance quantity fixup parse failed`);
    const amount=Number(m[1].replace(/,/g,''));
    const x=clean(amount/subQty[name]);
    setCorrect(q,x+'倍',multChoices(x));
    q.point=`${amount.toLocaleString('ja-JP')}÷${subQty[name].toLocaleString('ja-JP')}＝${x}倍。`;
    q.detail=`${name}の法令上の指定数量${subQty[name].toLocaleString('ja-JP')}Lを基準に、実数量${amount.toLocaleString('ja-JP')}Lを割る。この条件では${x}倍となる。`;
  }

  for(const q of QUESTIONS.filter(q=>q.subject==='法令'&&q.topic==='倍数合算')){
    const amounts=[...q.question.matchAll(/([\d,]+) L/g)].map(m=>Number(m[1].replace(/,/g,'')));
    let present=cats.filter(cat=>q.question.includes(cat)).sort((x,y)=>q.question.indexOf(x)-q.question.indexOf(y));
    if(amounts.length!==2||present.length<1)throw new Error(`${q.id}: mixed fixup parse failed`);
    let a=present[0],b=present[1]||present[0];
    if(present.length===1){
      const idx=cats.indexOf(a);b=cats[(idx+3)%cats.length];
      q.question=`${a}を${amounts[0].toLocaleString('ja-JP')} L、${b}を${amounts[1].toLocaleString('ja-JP')} L同一場所で扱う。指定数量の倍数の合計はいくつか。`;
      q.learningObjective=`${a}${amounts[0]}Lと${b}${amounts[1]}Lの混在時の倍数を計算する`;
    }
    const sum=clean(amounts[0]/qty[a]+amounts[1]/qty[b]);
    setCorrect(q,sum+'倍',multChoices(sum));
    q.point=`${amounts[0].toLocaleString('ja-JP')}/${qty[a].toLocaleString('ja-JP')}＋${amounts[1].toLocaleString('ja-JP')}/${qty[b].toLocaleString('ja-JP')}＝${sum}倍。`;
    q.detail=`${a}は${qty[a].toLocaleString('ja-JP')}L、${b}は${qty[b].toLocaleString('ja-JP')}Lを基準に個別の倍数を求めて加算する。このケースの合計は${sum}倍。`;
  }

  for(const q of QUESTIONS.filter(q=>q.subject==='法令'&&q.topic==='指定数量判定')){
    const m=q.question.match(/倍数合計([0-9.]+)/);
    if(m){
      const x=Number(m[1]);const premise=q.question.split('。')[0];
      q.point=`${premise}では倍数合計${x}なので、${x>=1?'指定数量以上':'指定数量未満'}として判定する。`;
      q.detail=`${premise}。各危険物について実数量÷指定数量を求めて合算すると${x}。1以上なら指定数量以上、1未満なら指定数量未満である。`;
    }
  }

  for(const q of QUESTIONS.filter(q=>q.subject==='物理・化学'&&['密度計算','熱量計算','定積気体計算','蒸気比重計算','燃焼範囲判定','定圧気体計算'].includes(q.topic))){
    const correct=q.choices[q.answer];
    q.point=`${q.question.split('。')[0]}では答えは「${correct}」。`;
    q.detail=`${q.question} ${q.topic}の定義・公式に数値を代入すると「${correct}」となる。単位と絶対温度、上下限の扱いを問題条件に合わせて確認する。`;
  }

  const seen=new Map();
  for(const q of QUESTIONS){
    if(!seen.has(q.question)){seen.set(q.question,q);continue}
    const prior=seen.get(q.question);
    if(prior.topic===q.topic)throw new Error(`${q.id}: unresolved same-topic duplicate with ${prior.id}`);
    q.question=`${q.topic}について、法令または試験範囲上もっとも適切な記述はどれか。`;
    q.point=`${q.topic}：${q.point}`;
    q.detail=`${q.topic}の観点で判断する。${q.detail}`;
    if(seen.has(q.question))throw new Error(`${q.id}: fixup still duplicates question`);
    seen.set(q.question,q);
  }
})();
