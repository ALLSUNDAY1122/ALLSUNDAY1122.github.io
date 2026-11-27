import type {Kind,Concern,Stage,Section,Input} from './fortune';
export type Situation='silence'|'mixed'|'pressure';
export type Goal='understand'|'talk'|'choose';
export const situationOptions:Record<Kind,{value:Situation;label:string}[]>={
love:[{value:'silence',label:'返信や連絡が減った'},{value:'mixed',label:'会うと優しいのに連絡が曖昧'},{value:'pressure',label:'関係をはっきりさせる話が出た'}],
compatibility:[{value:'silence',label:'話し合いが途切れがち'},{value:'mixed',label:'日常では仲良いが意見が割れる'},{value:'pressure',label:'大きな決断を迫られている'}],
career:[{value:'silence',label:'評価や期待が見えてこない'},{value:'mixed',label:'成果は出るが負担が増えている'},{value:'pressure',label:'異動・転職など期限が近い'}]
};
export const goalOptions:Record<Kind,{value:Goal;label:string}[]>={
love:[{value:'understand',label:'自分の気持ちを整理したい'},{value:'talk',label:'相手との会話を改善したい'},{value:'choose',label:'今後の関係を決めたい'}],
compatibility:[{value:'understand',label:'違いの理由を理解したい'},{value:'talk',label:'落ち着いて話し合いたい'},{value:'choose',label:'将来の方向性を決めたい'}],
career:[{value:'understand',label:'現状の原因を整理したい'},{value:'talk',label:'周囲と認識を合わせたい'},{value:'choose',label:'進路・働き方を判断したい'}]
};
const scenes:Record<Kind,Record<Situation,{observation:string;ambiguity:string;move:string;measure:string}>>={
love:{
silence:{observation:'最近の連絡が減ったことが、今回の不安を強めているようです。',ambiguity:'返信間隔だけでは、忙しさ・心理的な距離・連絡の習慣を区別できません。',move:'送った日時と返信の有無ではなく、直近のやりとりで互いに話題を広げているかを書き留める',measure:'7日間のうち、双方から話題や予定の提案があったか'},
mixed:{observation:'会っているときと離れているときの反応が違うことが、気になっている状況です。',ambiguity:'対面の親しさとメッセージの頻度は別の行動であり、片方だけで関係を評価できません。',move:'対面での約束・連絡時のやりとりを別々に整理する',measure:'会うときの約束が具体的に守られ、オンラインと対面の差を話し合えたか'},
pressure:{observation:'関係の方向を決める話が出たため、気持ちと現実的な条件を一度に考えがちな局面です。',ambiguity:'結論を急ぐほど、希望・不安・相手が求める条件が混ざりやすくなります。',move:'今すぐ決めることと保留できることを紙に分ける',measure:'期限と互いの意思を確認し、納得して保留または選択できたか'}},
compatibility:{
silence:{observation:'話したいことがあっても、途中で会話が終わってしまう状況が続いているようです。',ambiguity:'話せない理由が意見の不一致か、疲れやタイミングかはまだ分かりません。',move:'話題を一つに絞り、双方が話しやすい時間を確認する',measure:'10分間でも遮らず話せる機会を設けられたか'},
mixed:{observation:'普段は気持ちよく過ごせても、重要なテーマだけ意見が割れることが焦点です。',ambiguity:'大切にしている価値が違うのか、言葉の定義が違うのかを区別する必要があります。',move:'意見が割れた場面と、実は一致していた点を各一つ記録する',measure:'対立したテーマについて共通目標を一つ言語化できたか'},
pressure:{observation:'住まい・仕事・将来など、保留しにくい選択が近づいている状況です。',ambiguity:'相手を理解することと、全条件に同意することは同じではありません。',move:'双方の譲れない条件と、延期できる判断を整理する',measure:'同意できた条件・保留した条件を具体的に分けられたか'}},
career:{
silence:{observation:'周囲の期待や評価が見えず、自分が正しい方向に進んでいるか判断しにくい状況です。',ambiguity:'評価が伝わっていないことと、評価されていないことは区別すべきです。',move:'期待成果・期限・評価基準を短い質問にまとめる',measure:'期待成果と評価基準を一つ以上確認できたか'},
mixed:{observation:'成果を感じる一方で、負荷も増えており、今の働き方を続けるべきか考える局面です。',ambiguity:'成果が出ていることだけでは、継続可能な仕事量とは限りません。',move:'直近1週間の成果と時間・疲労を別々に記録する',measure:'成果と負荷の両方について改善策を一つ試せたか'},
pressure:{observation:'異動や転職など、意思決定の期限が近づいている状況です。',ambiguity:'目の前の選択肢の印象だけでは、中長期の負担や条件を比較できません。',move:'期限・年収・勤務時間・裁量・支援体制を同じ表で比較する',measure:'期限までに不足情報を二つ以上確認できたか'}}
};
const aims:Record<Goal,{perspective:string;task:string;checkpoint:string}>={
understand:{perspective:'結論よりも、まず状況を読み解くことが今回の目的です。',task:'確かめられた事実・自分の解釈・未確認事項を各一つ書く',checkpoint:'推測を取り除いたとき、まだ分からないことが何か'},
talk:{perspective:'大切なのは気持ちを当てることではなく、会話が少しでも進むことです。',task:'相手に確認したい質問を一つ作り、答える余地を残して伝える',checkpoint:'伝えた内容と相手の返答を別々に記録できたか'},
choose:{perspective:'答えを急がず、比較できる選択肢を持つことが今回の目的です。',task:'続ける・変える・保留の3案を書き、それぞれの負担を比較する',checkpoint:'自分が大切にしたい条件を選択に反映できたか'}
};
const phases:Record<Stage,{start:string;pace:string;boundary:string}>={
early:{start:'まだ材料が少ない段階なので、少数の出来事を未来全体の兆候として扱わないようにします。',pace:'まず3日間は観察を優先し、結論を出すことを目標にしません。',boundary:'情報不足は悪い兆しではなく、情報不足として扱ってください。'},
ongoing:{start:'ある程度の経緯があるので、一度の出来事よりも繰り返す傾向に注目します。',pace:'過去2〜3回の出来事と今回を比べ、変わった部分を探します。',boundary:'過去の印象だけで相手や環境を固定的に評価しないでください。'},
strained:{start:'今は負担が大きいため、関係や仕事をすぐ改善することより自分を消耗させない進め方を優先します。',pace:'負担が強い日は提案を実行せず、休息や信頼できる相談相手の利用を優先します。',boundary:'相手への接触や重大な決断を急ぐ必要はありません。安全や健康に関わるときは適切な支援を優先してください。'}
};
const concerns:Record<Concern,string>={
uncertainty:'確信が欲しいときほど、見えている行動と自分が補っている意味を区別することが助けになります。',
communication:'会話の回数ではなく、何が伝わり何が伝わらなかったかを分けると、改善できる一点が見つかりやすくなります。',
decision:'選択肢が少なく見えるときこそ、期限を延ばす・条件を変えるなどの中間案にも目を向けます。'
};
export function personalize(input:Input):{intro:string;sections:Section[];planPrefix:string;check:string;focusLabel:string}{
 const kind=input.kind,scene=input.situation??'mixed',goal=input.goal??'understand',stage=input.stage??'ongoing',concern=input.concern??'uncertainty';
 const s=scenes[kind][scene],a=aims[goal],p=phases[stage];
 const focusLabel=situationOptions[kind].find(x=>x.value===scene)!.label+' × '+goalOptions[kind].find(x=>x.value===goal)!.label;
 return {intro:s.observation+' '+p.start+' '+a.perspective,
 sections:[
 {title:'選んだ状況に照らした読み解き',body:s.observation+' '+s.ambiguity+' '+concerns[concern]+' '+p.start},
 {title:'あなたが今回目指す着地点',body:a.perspective+' 具体的には「'+a.task+'」から取り組みます。'+p.pace},
 {title:'出来事を確かめる観察ポイント',body:'今回確かめたいのは「'+s.measure+'」です。確認の基準は「'+a.checkpoint+'」。'+p.boundary},
 {title:'今日の小さな実行手順',body:'最初に「'+s.move+'」。その後「'+a.task+'」。他人の反応や成果を保証するのではなく、自分で実行できる範囲を決めましょう。'}
 ],planPrefix:s.move+'。続いて'+a.task+'。',check:s.measure,focusLabel};
}
