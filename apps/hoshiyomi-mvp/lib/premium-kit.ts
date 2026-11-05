import type {Input, Kind, Concern, Section} from './fortune';
import {personalize, type Situation, type Goal, situationOptions, goalOptions} from './personalization';

type CasePlan={friction:string;fact:string;verification:string;open:string;follow:string;stop:string;green:string;yellow:string;red:string;measure:string;alternatives:[string,string,string]};
type Kit={title:string;promise:string;context:string;question:string;options:{name:string;benefit:string;cost:string;next:string}[];scripts:{label:string;text:string}[];branches:{label:string;action:string}[];days:{day:number;title:string;do:string;record:string;gate:string}[];worksheet:{label:string;help:string}[];stopRule:string;closing:string;freeDifference:string;sections:Section[];pairExercise?:{title:string;steps:string[];agreement:string}};
const cases:Record<Kind,Record<Situation,CasePlan>>={
love:{
silence:{friction:'連絡が減り、相手の考えが見えない',fact:'返信の間隔・内容と、相手からの質問や提案を分けて見る',verification:'連絡を増やす約束ではなく、会話を続ける意思が双方にあるか',open:'「この間話していた○○、その後どうなった？ 無理のない時で大丈夫だよ」',follow:'「やりとりのペースについて、負担のない方法を一度相談できる？」',stop:'「返事を急がせたくないから、こちらからは一度区切るね。また話せる時に教えて」',green:'相手から自発的な質問や日程提案がある',yellow:'返信はあるが予定や気持ちが具体化しない',red:'断りを無視した接触や、相手から明確な拒否がある',measure:'質問や具体的な約束の相互性',alternatives:['負担の少ない連絡を一度だけ試す','連絡の優先度を下げ、自分の予定を守る','返答がなくても結論を保留し、距離を取る']},
mixed:{friction:'対面では親しいが、離れると反応が曖昧',fact:'会う約束が守られているかと、連絡時の反応を別々に評価する',verification:'対面での親しさと継続した関係への意思を混同しない',open:'「会う時間は楽しい。普段の連絡はどのくらいが心地よい？」',follow:'「今後も会う時間をつくりたいか、気持ちを聞いてもいい？」',stop:'「答えを急がせたくない。私は今の距離感を少し整理してみるね」',green:'次に会う約束と意思が具体的になる',yellow:'好意的な言葉はあるが予定や行動が定まらない',red:'意見を尊重せず無理な約束を求められる',measure:'発言と約束が行動として一致する頻度',alternatives:['次回の約束について具体的に確認する','期待する連絡頻度を共有する','自分が安心できる距離を再設定する']},
pressure:{friction:'関係の方向性を決める期限を意識している',fact:'決める必要のある内容と、保留できる内容を区別する',verification:'双方の同意と譲れない条件を明示できるか',open:'「今すぐ答えを出す前に、私たちが大切にしたい条件を話したい」',follow:'「一度で決めず、確認が必要なことを整理する時間を取れる？」',stop:'「納得できるまで結論を保留したい。今は約束できない」',green:'希望と条件を尊重しながら具体的に話せる',yellow:'結論は一致しないが保留を認め合える',red:'脅し・強要・同意のない決断がある',measure:'対等に選択・保留できること',alternatives:['条件を一つずつ話し合う','結論の期限を相談する','無理な同意を避け安全を優先する']}},
compatibility:{
silence:{friction:'話し合いが途中で止まってしまう',fact:'会話が止まった場面と、その直前の話題を具体化する',verification:'意見の違いよりも会話を続けられる条件は何か',open:'「今は結論を出さなくていいから、10分だけ互いの考えを聞いてみない？」',follow:'「前の話のうち、どこまでは共通認識だったかな？」',stop:'「疲れているなら今日はここまでにしよう。別の日に話せる？」',green:'一つのテーマで双方が最後まで話せる',yellow:'話はできるが論点が増えて混乱する',red:'侮辱・威圧・沈黙を使った支配がある',measure:'双方が話したい内容を要約できるか',alternatives:['話すテーマを一つに絞る','時間と場所を変えて対話する','安全や尊重を欠くなら話し合いを中断する']},
mixed:{friction:'日常は良好でも一部の価値観で衝突する',fact:'どの条件で意見が分かれ、どこは一致しているかを記録する',verification:'違いが意見・優先順位・事実認識のどれにあるか',open:'「同じことを大事にしている部分もあると思う。違いが出る場面を一つだけ話したい」',follow:'「あなたの考える『公平』は具体的にどんな状態？」',stop:'「ここは無理に一致させず、今は別のやり方を考えよう」',green:'共通目標と調整可能な条件が見つかる',yellow:'違いは残るが理解は深まる',red:'どちらかだけが恒常的に我慢を求められる',measure:'共通目標と譲れない条件を分けられるか',alternatives:['同じ言葉の意味を具体化する','交代制などの試行ルールをつくる','一致しないことを前提に距離や役割を調整する']},
pressure:{friction:'将来の大きな決断が近づいている',fact:'住居・仕事・家計・家族などの論点を分けて比較する',verification:'それぞれが譲れない条件と期限を明示できるか',open:'「大事なことだから、条件を一つずつ整理してから決めたい」',follow:'「先に決めないと困ることは何で、保留できることは何かな？」',stop:'「まだ同意できない部分があるので、いったん決定を保留したい」',green:'条件・費用・時期が具体化する',yellow:'条件が合わないが話す余地がある',red:'同意を迫られ、安全や金銭面に深刻な不安がある',measure:'選択肢と費用・期限の見通し',alternatives:['条件と期限を表で整理する','決定を段階に分ける','第三者の支援を利用し負担の大きい決定を避ける']}},
career:{
silence:{friction:'評価・期待が見えず、成果の方向が定まらない',fact:'任された仕事・完成条件・実績とフィードバックを照合する',verification:'評価基準や成果期待を具体的に確認できたか',open:'「今回の仕事で特に重視する成果と評価基準を教えてください」',follow:'「今の進め方で改善すべき点を一つ挙げていただけますか」',stop:'「優先順位を確認してから着手したいので、期限の調整は可能でしょうか」',green:'目標・期限・評価方法が言語化される',yellow:'評価はあるが基準が曖昧なまま',red:'不合理な要求や継続的なハラスメントがある',measure:'期待成果と実績の具体的な一致',alternatives:['評価基準を質問する','自身の成果を記録する','改善しない場合は別の相談経路を使う']},
mixed:{friction:'成果は出ている一方で仕事の負担が増えている',fact:'成果だけでなく時間・疲労・継続可能性を確認する',verification:'減らせる仕事・委任できる仕事・残す仕事は何か',open:'「成果を維持したいので、優先順位と負荷の見直しをご相談できますか」',follow:'「今月必須の成果と、延期できる業務を分けたいです」',stop:'「この条件では品質が落ちるため、範囲か期限の調整が必要です」',green:'担当と優先順位が整理される',yellow:'一時的に楽になるが仕組みは変わらない',red:'健康を損なう負荷が継続している',measure:'成果を保ちながら負荷が減ったか',alternatives:['業務の優先順位を再設定する','成果と負荷を同時に可視化する','必要に応じ産業保健・専門相談に繋ぐ']},
pressure:{friction:'異動・転職など期限付きの選択を迫られている',fact:'年収・時間・役割・成長・安定性を同じ軸で比較する',verification:'不足している条件が比較前に確かめられたか',open:'「判断に必要なので、業務範囲・評価基準・勤務条件を詳しく教えてください」',follow:'「この条件について、書面で確認することはできますか」',stop:'「確認できていない条件があるため、回答期限を相談したいです」',green:'条件が文書で確認でき、意思決定が可能',yellow:'魅力はあるが労働条件が不確か',red:'重要条件の確認を拒まれる、強い圧力を受ける',measure:'確認できた条件数と残った不確実性',alternatives:['現職改善も含む3案を比較','条件を文書で確認する','期限に間に合わないなら無理な意思表示を避ける']}}
};
const focus:Record<Goal,{label:string;objective:string;criterion:string;step:string}> ={
understand:{label:'理解する',objective:'判断を急がず、事実と解釈のズレを見つける',criterion:'確かめられた事実を3つ、未確認事項を1つ記録する',step:'場面を分解し、まだ聞けていない質問を一つ選ぶ'},
talk:{label:'話し合う',objective:'会話を始めるための言葉とタイミングを用意する',criterion:'相手の自由を尊重する質問を一つ伝え、返答を実際の言葉で記録する',step:'話し合う時間を決め、伝えたい目的を一文にする'},
choose:{label:'選ぶ',objective:'期限・条件・負担を可視化して、保留も含む選択肢を持つ',criterion:'少なくとも3案と、それぞれの費用や負担を比較する',step:'譲れない条件と、確認できていない条件を一つずつ書く'}
};
const concernQuestions:Record<Concern,string>={uncertainty:'まだ事実として確認できていないことは何か？',communication:'どの言葉が違う意味で受け取られた可能性があるか？',decision:'意思決定に必要だが足りていない条件は何か？'};
const stageAdjust={early:'状況が始まったばかりなので観察を優先し、最初の3日は結論を保留する。',ongoing:'直近の出来事を過去2回と比べ、一貫した傾向があるかを確認する。',strained:'無理な接触・決断は避け、休息と安全を優先する。負担の大きい課題は省略してよい。'} as const;
export function makePremiumKit(input:Input):Kit{
 const kind=input.kind,scene=input.situation??'mixed',goal=input.goal??'understand',stage=input.stage??'ongoing',concern=input.concern??'uncertainty';
 const c=cases[kind][scene],f=focus[goal],p=personalize(input);
 const plan=[
 ['現状を確かめる','直近の実例を3つ書き出す。'+c.fact,'事実／解釈／未確認を分けた3行','判断材料が混ざっていないか'],
 ['判断基準を決める','「'+c.verification+'」をもとに、自分が重視する条件を2つ書く','重視条件2件、保留条件1件','自分で選べる条件か'],
 ['一つだけ試す',f.step+'。必要なら次の文面を参考にする：「'+c.open+'」','実施したこと／実施しなかった理由','相手が断る選択肢を残したか'],
 ['反応を読み違えない','以下の観察を行う：「'+c.measure+'」。事実の記録だけを先に書く','反応を青・黄・赤のどれかで分類','単発の出来事だけで判断していないか'],
 ['分岐する', '青なら次の対話、黄なら情報収集、赤なら中断や相談に進む。','選んだ分岐とその理由','危険や強い負担を軽視していないか'],
 ['3案を比較する',c.alternatives.join('／')+'。それぞれのメリット・負担・可逆性を比べる。','3案比較表','後戻りできる選択肢も含めたか'],
 ['次の一週間を決める',''+f.objective+'。'+f.criterion+'。','続ける行動1つ／やめる行動1つ／保留1つ','占いではなく実際の情報で判断しているか']
 ];
 const days=plan.map(([title,doText,record,gate],i)=>({day:i+1,title,do:doText+' '+stageAdjust[stage],record,gate}));
 const options=[{name:'A｜小さく動く',benefit:'実際の反応を確かめられる',cost:'相手や状況が応じない可能性',next:c.alternatives[0]},{name:'B｜一度整理する',benefit:'期待や推測を切り離せる',cost:'短期的に結論は出にくい',next:c.alternatives[1]},{name:'C｜距離を取る・保留',benefit:'無理な決断や消耗を防げる',cost:'不確実な状態が残る',next:c.alternatives[2]}];
 const scripts=[{label:'最初に伝える',text:c.open},{label:'相手の反応が曖昧なとき',text:c.follow},{label:'難しいときの区切り方',text:c.stop}];
 const branches=[{label:'青｜話し合いが進む',action:c.green+'。期待を固定せず、次の小さな約束を一つだけ明確にする。'},{label:'黄｜曖昧なまま',action:c.yellow+'。結論を出さず、期限を決めて必要情報を一つだけ確認する。'},{label:'赤｜負担や危険が大きい',action:c.red+'。無理に接触や結論を進めず、安全・健康・適切な相談先を優先する。'}];
 const worksheet=[{label:'私が確かめた事実',help:'相手の気持ちの推測ではなく観察できたこと'},{label:'まだ分からないこと',help:concernQuestions[concern]},{label:'私が大切にしたい条件',help:'「こうあるべき」より具体的で検証できる条件'},{label:'今週選ぶ行動',help:options[goal==='choose'?2:goal==='talk'?0:1].next},{label:'7日後の判断材料',help:c.measure}];
 const pairExercise=kind==='compatibility'?{title:'ふたりの合意づくりワーク',steps:['それぞれが自分の希望を3つ書く（相手の希望を代筆しない）','二人で一致する目標を一つ選び、条件と期限を確認する','各自が譲れる点と譲れない点を別々に記す','一致しない条件は保留し、次に話す日を決める','相手が拒否・中断したいときはそれを尊重し、合意したことにしない'],agreement:'合意メモには「決めたこと」「まだ決めていないこと」「次回確認する日」をそれぞれ明記します。'}:undefined;
 const sections:Section[]=[...days.map(d=>({title:'Day '+d.day+'｜'+d.title,body:'実施：'+d.do+'\n残すもの：'+d.record+'\n確認：'+d.gate})),...branches.map(b=>({title:b.label,body:b.action})),...scripts.map(s=>({title:s.label,body:s.text})),{title:'7日後の判断',body:f.criterion+'。'+stageAdjust[stage]}];
 return {title:'あなたの状況別・実行設計書',promise:'「何を聞く・何を見る・どう判断する」を7日間で整理する実用キット',context:'選んだ出来事：'+situationOptions[kind].find(x=>x.value===scene)!.label+'。今回の目標：'+goalOptions[kind].find(x=>x.value===goal)!.label+'。'+p.intro,question:concernQuestions[concern],options,scripts,branches,days,worksheet,stopRule:stageAdjust[stage]+' '+c.red+'ときは進行を中断してください。',pairExercise,closing:'このレポートは選択肢を考えるための補助であり、相手の感情や将来を保証しません。',freeDifference:'無料版は星座の物語と「何が気になるのか」の整理まで。有料版は分岐に応じた具体的な言葉、実施手順、観察基準、意思決定用の記入シートを提供します。',sections};
}
