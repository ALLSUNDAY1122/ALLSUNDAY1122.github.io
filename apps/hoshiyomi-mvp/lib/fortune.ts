export type Kind='love'|'compatibility'|'career';
export type Product='detail'|'pair';
export type Concern='uncertainty'|'communication'|'decision';
export type Stage='early'|'ongoing'|'strained';
export type Input={kind:Kind;birthday:string;partnerBirthday?:string;concern?:Concern;stage?:Stage};
export type Section={title:string;body:string};
export const products={detail:{name:'実践設計レポート',price:480},pair:{name:'ふたりの対話設計レポート',price:980}} as const;
export const concernOptions:Record<Kind,{value:Concern;label:string}[]>={
 love:[{value:'uncertainty',label:'相手の気持ちが分からない'},{value:'communication',label:'連絡や会話が噛み合わない'},{value:'decision',label:'関係を進めるか迷っている'}],
 compatibility:[{value:'uncertainty',label:'価値観の違いが気になる'},{value:'communication',label:'すれ違いが続いている'},{value:'decision',label:'将来を話し合いたい'}],
 career:[{value:'uncertainty',label:'自分の強みが分からない'},{value:'communication',label:'上司・同僚との関係に悩む'},{value:'decision',label:'転職・異動を迷っている'}]
};
export const stageOptions=[{value:'early',label:'まだ始まったばかり'},{value:'ongoing',label:'しばらく続いている'},{value:'strained',label:'負担や不安が大きい'}] as const;
const signs=['山羊座','水瓶座','魚座','牡羊座','牡牛座','双子座','蟹座','獅子座','乙女座','天秤座','蠍座','射手座'] as const;
const limits=[20,19,21,20,21,22,23,23,23,23,22,22];
export function validDate(s:unknown):s is string{if(typeof s!=='string'||!/^\d{2}-\d{2}$/.test(s))return false;const[m,d]=s.split('-').map(Number);return m>=1&&m<=12&&d>=1&&d<=new Date(Date.UTC(2024,m,0)).getUTCDate()}
export function validInput(v:unknown):v is Input{if(!v||typeof v!=='object')return false;const x=v as Record<string,unknown>;return ['love','compatibility','career'].includes(String(x.kind))&&validDate(x.birthday)&&(x.kind!=='compatibility'||validDate(x.partnerBirthday))&&(x.partnerBirthday===undefined||validDate(x.partnerBirthday))&&(x.concern===undefined||['uncertainty','communication','decision'].includes(String(x.concern)))&&(x.stage===undefined||['early','ongoing','strained'].includes(String(x.stage)))}
export function sign(date:string){if(!validDate(date))throw Error('Invalid birthday');const[m,d]=date.split('-').map(Number);return signs[d>=limits[m-1]?m%12:(m+11)%12]}
const library:Record<Kind,Record<Concern,{insight:string;pitfall:string;question:string;action:string;signal:string;script:string;week:string[]}>>={
 love:{
  uncertainty:{insight:'返信の速さや絵文字の多さだけでは、相手の好意は確定できません。「実際に起きたこと」「自分が受け取った意味」「まだ確認できていないこと」を分けると、不安による早合点を減らせます。',pitfall:'占いの結果を根拠に相手の心を決めつけたり、返事を催促し続けたりしないこと。',question:'相手が実際に示してくれた行動と、自分の期待を一つずつ挙げられますか。',action:'次の会話では、返答の有無に関係なく気持ちよく終われる一つの話題を送ってみましょう。',signal:'相手からの自発的な質問・具体的な約束の提案があるか。',script:'「最近どうしてる？ 前に話していた○○、その後どうなった？」',week:['事実と推測を書き分ける','自分が望む距離感を言語化する','負担の少ない話題を一度送る','反応を追いかけすぎず生活を優先','自発的な相互性を観察する','続けたい関係の条件を確認','翌週の接点を持つか決める']},
  communication:{insight:'連絡頻度の不一致は、必ずしも気持ちの差ではありません。忙しさや会話の好みも影響します。「頻度」「内容」「緊急時の連絡」を別々に相談する方が伝わりやすくなります。',pitfall:'既読時間を監視したり、試すために返事を遅らせたりすると関係がこじれやすくなります。',question:'いま困るのは連絡の回数、言葉の冷たさ、予定が決まらないことのどれでしょう。',action:'不満ではなく希望として、無理のない連絡方法を一つ提案しましょう。',signal:'双方の負担が減り、予定や用件が以前より明確になるか。',script:'「お互い無理のない連絡のペースを相談できたらうれしい」',week:['困っている場面を具体化','自分の希望を短くまとめる','落ち着いた時間を選ぶ','希望を一つだけ伝える','相手の事情も確認','無理なく続く方法を試す','方法を調整する']},
  decision:{insight:'関係を進めるかどうかは、相手を好きな気持ちと、尊重されている実感を分けて考えると整理できます。判断を一回の出来事だけで決めず、継続している行動を見ましょう。',pitfall:'将来の不安を埋めるためだけに、同意や約束を急がせないこと。',question:'続けたい理由と、譲れない条件をそれぞれ二つ書けますか。',action:'次の一歩を「会って話す」「少し距離を置く」など可逆的な選択から考えましょう。',signal:'話し合いで互いの意思が尊重され、約束が行動につながっているか。',script:'「これからの関係について、私はこう考えている。あなたの考えも聞きたい」',week:['大事な条件を二つ書く','事実を時系列で整理','選択肢を三つ作る','信頼できる人に相談','相手と希望を共有','負担と納得感を確認','次の一歩を選ぶ']}
 },
 compatibility:{
  uncertainty:{insight:'価値観の違いそのものよりも、「違いを話せるか」が実生活では重要です。お金、時間、家族、自由度を一度に決めず、具体的な場面ごとに相互理解を深めましょう。',pitfall:'星座を使って相手を固定的に評価しないこと。',question:'最近のすれ違いは、価値観の違いですか、それとも説明不足ですか。',action:'同じ言葉でも意味が違いそうなテーマを一つ選び、具体例を聞きましょう。',signal:'双方が相手の考えを自分の言葉で説明できるか。',script:'「私にとって○○はこういう意味なんだけど、あなたはどう考える？」',week:['違いを一つ選ぶ','自分の考えを整理','相手の理由を聞く','一致点を探す','譲れる点を決める','小さな運用ルールを試す','無理のない調整か振り返る']},
  communication:{insight:'会話が噛み合わないときは、「問題を解決したい人」と「まず気持ちを受け止めてほしい人」の期待がずれている場合があります。会話の目的を先に確認すると負担を減らせます。',pitfall:'過去の不満を同時に持ち出したり、どちらが正しいかの勝負にしないこと。',question:'相手に求めていたのはアドバイス、共感、具体的な行動のどれでしょう。',action:'話し始めに「今日は相談したい／聞いてほしい」と目的を添えましょう。',signal:'会話が終わったとき双方が理解されたと感じるか。',script:'「解決策を決める前に、まずお互いの受け取り方を話してもいい？」',week:['繰り返す場面を特定','会話の目的を書き出す','落ち着いた時間を確保','相手の言葉を要約','自分の希望を伝える','小さな約束を試す','負担の変化を確認']},
  decision:{insight:'将来の話し合いでは、理想だけでなく、具体的な条件と期限を揃えると判断しやすくなります。「いつか」ではなく、住まい・お金・仕事・家族への考えを別々に確かめましょう。',pitfall:'話す準備がない相手に即答を強要しないこと。',question:'最優先で一致を確認したいテーマは何でしょう。',action:'一度に結論を出さず、30分で一テーマだけ話す場を提案しましょう。',signal:'曖昧だった論点が具体的な選択肢や期限に変わるか。',script:'「今すぐ答えを出さなくていいから、来月までに○○について一度話せる？」',week:['重要テーマを選ぶ','自分の条件を整理','相手の希望を聞く','一致と相違を分ける','費用・時期を確認','保留点を言語化','次に話す日を決める']}
 },
 career:{
  uncertainty:{insight:'強みは「好きなこと」だけでなく、繰り返し成果が出た行動に表れます。過去の経験を「状況・自分の行動・結果」に分けると、職務上の再現性が見えやすくなります。',pitfall:'一度の失敗や占いの結果で向き不向きを断定しないこと。',question:'最近、周囲より少ない負担でできた仕事を一つ挙げられますか。',action:'直近3か月の成功例を二つ書き、共通する行動を探しましょう。',signal:'別の場面でも同じ行動が成果につながるか。',script:'「最近の私の仕事で、特に役立った点を一つ教えてもらえますか」',week:['成功した仕事を三つ列挙','行動と結果を分離','周囲からの評価を確認','共通する得意行動を抽出','小さな仕事で再現','負担と成果を記録','伸ばす力を一つ決める']},
  communication:{insight:'職場の摩擦は人格の相性だけでなく、期待する成果・期限・裁量の認識違いで生じます。相手の要求を具体的な成果物と優先順位に変換して確認すると改善の糸口になります。',pitfall:'相手の性格や星座だけを原因として決めつけないこと。',question:'いま一番食い違っているのは、期限・品質・担当範囲のどれですか。',action:'次の依頼時に「優先順位」「完成条件」「期限」を一度確認しましょう。',signal:'手戻りや認識違いが実際に減るか。',script:'「今回の優先順位と、完成と判断する条件を確認してもよいでしょうか」',week:['食い違いを具体化','相手の期待を書き出す','確認事項を三つに絞る','短い確認を取る','合意内容を記録','手戻りを観察','伝え方を調整']},
  decision:{insight:'転職や異動は年収だけでなく、生活時間・成長機会・裁量・健康負荷などの条件を一緒に比べることが重要です。現職を改善する選択肢も残したうえで評価しましょう。',pitfall:'診断だけで退職を決めたり、応募前に現職を辞めたりしないこと。',question:'今より改善したい条件を重要度順に三つ挙げられますか。',action:'現職・異動・転職の3案を、同じ5項目で比較表にしましょう。',signal:'希望条件について、求人票や面談など検証できる証拠が増えるか。',script:'「次の役割で期待される成果、働き方、評価条件を具体的に教えてください」',week:['現状の不満を分類','譲れない条件を決める','選択肢を三つ整理','求人・社内制度を調査','情報不足を質問','費用と負担を比較','次の情報収集を決める']}
 }};
const stageNotes:Record<Stage,string>={early:'まだ関係・状況の情報が少ない段階です。確信よりも観察と小さな試行を優先してください。',ongoing:'ある程度の経緯がある段階です。直近1回より繰り返すパターンと改善例を比べてください。',strained:'負担が大きい段階です。無理に話し合いを進めず、自分の安全・休息・信頼できる相談先を優先してください。'};
const signLenses=['慎重に条件を見直す','自由な選択肢を探す','気持ちを言葉にする','まず小さく動く','安定を大事にする','異なる視点を並べる','安心できる環境を作る','自分の意思を明確にする','現実的に整理する','相手と均衡を探す','深い本音を見つめる','少し先の可能性を描く'];
export function reading(input:Input){if(!validInput(input))throw Error('Invalid input');const concern=input.concern??'uncertainty',stage=input.stage??'ongoing',base=library[input.kind][concern],first=sign(input.birthday),other=input.kind==='compatibility'?sign(input.partnerBirthday!):undefined;const lens=signLenses[signs.indexOf(first)];return {title:other?first+' × '+other+'｜関係を整えるための読み解き':first+'｜'+({love:'恋愛',compatibility:'相性',career:'仕事'} as const)[input.kind]+'の読み解き',subtitle:concernOptions[input.kind].find(x=>x.value===concern)!.label,sections:[{title:'いまの状況を読み解く',body:base.insight},{title:'星座からの振り返り視点',body:first+'を物語のモチーフにするなら「'+lens+'」が今回のキーワード。占星術から実際の性格を判定したわけではありません。この問いが自分に役立つかを確かめてください。'},{title:'見落としやすい注意点',body:base.pitfall+' '+stageNotes[stage]},{title:'今日できる具体的な一歩',body:base.action},{title:'自分への問い',body:base.question}],hint:base.insight,caveat:'占いは娯楽・自己理解のためのものです。誕生日から性格、相手の気持ち、未来の出来事を科学的に推定するものではありません。',productPreview:{what:'自分の状況に合わせた7日間の行動プラン、具体的な会話例、変化を確かめるチェック項目、進まない場合の代替策',example:base.script}}}
const dayGuides=[
 {instruction:'まず直近の具体的な出来事を3つ挙げ、各出来事について「起こった事実」「自分の解釈」「まだ確認できないこと」を別々の列に記録してください。',deliverable:'出来事3件の事実・推測メモ',check:'推測を事実として書いていないか'},
 {instruction:'この悩みで「今週は改善したいこと」「譲れないこと」「今は判断しなくてよいこと」を一つずつ決めてください。',deliverable:'希望・境界線・保留の3行',check:'他者を動かす目標ではなく自分が選べる行動になっているか'},
 {instruction:'次の一歩を一つだけ小さく実行します。実行前に所要時間と負担を見積もり、難しいときは半分の作業に縮めてください。',deliverable:'実施記録とそのときの感情1行',check:'成果ではなく、自分で決めた行動を実行できたか'},
 {instruction:'前日までの結果を「変わったこと」「変わらないこと」「判断できないこと」に整理してください。相手がいる場合は同意や事情を尊重してください。',deliverable:'観察結果3分類',check:'一度の反応だけで結論づけていないか'},
 {instruction:'続ける・変える・いったん休むの3案を作り、期待できることと負担をそれぞれ短く比較してください。',deliverable:'3案×メリット・負担の比較表',check:'実行可能性と心身の負担を含めているか'},
 {instruction:'信頼できる情報源や人から別の見方を一つ集めてください。断定的な予言ではなく、確認できる情報を優先します。',deliverable:'新しい視点1件と未確認の点1件',check:'新たに分かったことと依然不明なことを分けているか'},
 {instruction:'一週間を振り返り、次週も続ける行動を一つ、やめる行動を一つ決めてください。結論を保留する選択も認めます。',deliverable:'次の7日間に残す行動1件',check:'現実の変化を確認でき、無理な継続を前提としていないか'}
] as const;
export function report(input:Input,product:Product){
 if(!validInput(input))throw Error('Invalid input');
 if(product==='pair'&&input.kind!=='compatibility')throw Error('Invalid pair');
 const free=reading(input),base=library[input.kind][input.concern??'uncertainty'],stage=input.stage??'ongoing';
 const pace=stage==='strained'?'心身の負担が強い場合はこの日の課題を休み、安心できる人への相談を優先して構いません。':stage==='early'?'始まったばかりの状況では、断定よりも情報を集める行動を選んでください。':'これまでの経緯も振り返り、繰り返す傾向があるかを確認してください。';
 const week:Section[]=base.week.map((s,i)=>{
  const g=dayGuides[i];return {title:'Day '+(i+1)+'｜'+s,body:'目的：'+s+'。\n具体的な手順：'+g.instruction+'\n記録する成果物：'+g.deliverable+'。\n自己確認の基準：'+g.check+'。\n調整：'+pace};
 });
 const extra:Section[]=[
 {title:'今回のテーマに使える会話例',body:'次の表現をそのまま使う必要はありません。相手の状況を尊重できる言い方へ調整してください。\n例：「'+base.script.replace(/^「|」$/g,'')+'」\n話し終えたら、相手の回答を推測で埋めずに実際の言葉で記録してください。'},
 {title:'変化を見極める観察指標',body:'観察すること：'+base.signal+'。\n判断の方法：初日・4日目・7日目に「自分が行動できたか」「相手や環境に変化があったか」「まだ判断できないこと」をそれぞれ記録します。'},
 {title:'想定どおりに進まない場合',body:'①反応がない場合：要求を重ねず、時間を置いて別の選択肢を検討。②話し合いが難しい場合：目的を一つに絞り、別の日にする。③心身の負担が強い場合：行動計画を中断し、信頼できる人や適切な専門家に相談。無理に成功と判断する必要はありません。'},
 {title:'7日後に決めること',body:'続ける／方法を変える／休む の3つから選びます。根拠は「観察した事実」と「自分の希望」の両方を挙げてください。占い文を根拠に仕事や人間関係の重大な決断をしないでください。'},
 ...(product==='pair'?[{title:'ふたりの話し合いシート',body:'各自が「最も大事にしたいこと3つ」「譲れること2つ」「譲れないこと1つ」を別々に書きます。共通点と違いを見比べたら、今回決めることは1つだけに限定。答えが一致しない項目は保留し、話し合いを続けるかも含めて互いに選べるようにしてください。'}]:[])
 ];
 return {...free,product:products[product].name,sections:[...free.sections,...week,...extra]};
}
