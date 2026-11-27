import {sign,type Input} from './fortune';
import {lore} from './astrology';

export type Blood='A'|'B'|'O'|'AB'|'unknown';
export type Relation='partner'|'friend'|'mother'|'father'|'child'|'sibling'|'colleague';
export type Extra={birthYear:string;blood:Blood;otherBirthday:string;otherYear:string;otherBlood:Blood;relation:Relation;parentBirthday:string;parentYear:string};
export type Chapter={title:string;label:string;body:string};
const animals=['子（ねずみ）','丑（うし）','寅（とら）','卯（うさぎ）','辰（たつ）','巳（へび）','午（うま）','未（ひつじ）','申（さる）','酉（とり）','戌（いぬ）','亥（いのしし）'];
const animalStories=[
'「小さな兆しを見逃さず、新しい流れを見つける」始まりの年。','「時間を味方に、積み重ねたものを形にする」持続の年。',
'「変化の入口を見つけると動き出す」挑戦の年。','「目に見えない距離感と調和を大切にする」柔らかな年。',
'「大きな物語を構想し、視野を高く保つ」飛躍の年。','「静かに深く観察し、本質を探る」内省の年。',
'「自由と勢いを大切に、遠くへ進む」移動の年。','「集いと穏やかな関係を育てる」共感の年。',
'「視点を切り替え、工夫を見つける」発見の年。','「暮らしや約束に秩序を与える」整頓の年。',
'「忠実さと信頼を土台にする」守護の年。','「豊かさを分かち合うことを喜ぶ」実りの年。'];
const numbers:Record<number,{name:string;theme:string;shadow:string}> ={
1:{name:'開拓',theme:'自分で始まりを選ぶ力',shadow:'先へ進むほど周囲の歩幅を見直す'},
2:{name:'共鳴',theme:'人と人のあいだにある機微',shadow:'気遣いの奥に自分の希望を残す'},
3:{name:'表現',theme:'好奇心と楽しみを分かち合う姿勢',shadow:'広げる楽しさと深める時間を両立する'},
4:{name:'礎',theme:'日々の小さな積み重ね',shadow:'守るための仕組みを時々更新する'},
5:{name:'旅路',theme:'変化を受け入れ世界を広げる力',shadow:'自由を保ちながら約束を大切にする'},
6:{name:'調和',theme:'身近な人への思いやりと美意識',shadow:'誰かを支えることと自分の時間を分ける'},
7:{name:'探究',theme:'一人で考える深さと真実への好奇心',shadow:'考えの内側にこもりすぎず共有する'},
8:{name:'結実',theme:'目に見える形をつくる構想力',shadow:'成果以外の価値を見落とさない'},
9:{name:'統合',theme:'多様な立場を受け止める視野',shadow:'すべてを引き受けようとしすぎない'}
};
const bloodStories:Record<Blood,string>={
A:'A型は日本の血液型占いで「細やかな調和」の象徴として語られることがあります。これは性格の事実ではなく、星詠みでは「どこで安心を感じるか」を想像するための物語として扱います。',
B:'B型は日本の血液型占いで「自由な発想」の象徴として描かれることがあります。実際の性格を決めるものではなく、「自分にとって自然なペースとは」を考えるための小さな鏡です。',
O:'O型は日本の血液型占いで「大らかな包容力」にたとえられることがあります。人の気質を判断する根拠ではなく、「大切なものをどう守るか」という物語のモチーフです。',
AB:'AB型は日本の血液型占いで「複数の視点を持つ人」にたとえられることがあります。実際の個人差とは別に、「二つの考えをどう両立するか」という問いを重ねます。',
unknown:'血液型は入力しなくても鑑定できます。血液型による性格判断には科学的な根拠がないため、入力は任意です。'
};
const relationNames:Record<Relation,string>={partner:'恋人・気になる人',friend:'友人',mother:'母親',father:'父親',child:'子ども',sibling:'きょうだい',colleague:'職場の相手'};
const relationshipThemes:Record<Relation,string>={
partner:'惹かれる理由と、親しくなるほど見えてくる違い。二人の星座を重ねるときは「同じものを望む」だけでなく「違うものを面白がる」という物語も生まれます。',
friend:'友人の縁は、似ているところだけでなく、互いに異なる世界を紹介し合うことでも深まります。二つの象徴を並べ、どんな会話が生まれやすい物語なのかを見つめます。',
mother:'親子の関係では、受け継いだ価値観と自分で選び直した価値観が交差します。星座は親の本心を当てる道具ではなく、世代ごとの物語を読み比べる素材になります。',
father:'父親との関係には、育てられた時代の価値観と現在の自分の選択が重なります。二つの星座を比較して、似ているところと違いの両方を読み解く物語をつくります。',
child:'子どもにはその子自身の人格と可能性があります。星座で特性を固定するのではなく、親子で異なる世界の見方を楽しむ読み物として考えます。',
sibling:'同じ家庭で過ごしても、きょうだいは同じ人生を歩むわけではありません。それぞれの星座の物語が、同じ景色を違った角度から見せることがあります。',
colleague:'仕事上の相性は能力の優劣ではなく、役割や価値観の違いを考える入口になります。星座の象徴を、異なる役回りが重なる物語として読みます。'
};
function yearNum(x:string){if(!/^\d{4}$/.test(x))return null;const n=Number(x);return n>=1900&&n<=2026?n:null}
function validDay(x:string){if(!/^\d{2}-\d{2}$/.test(x))return false;const[m,d]=x.split('-').map(Number);return m>=1&&m<=12&&d>=1&&d<=new Date(Date.UTC(2024,m,0)).getUTCDate()}
function reduce(n:number):number{while(n>9)n=String(n).split('').reduce((a,b)=>a+Number(b),0);return n}
function yearAnimal(y:number){return (y-4)%12}
function digitMeaning(y:number,md:string){const digits=(String(y)+md.replace('-','')).split('').reduce((a,c)=>a+Number(c),0);return reduce(digits)}
function modeTogether(a:string,b:string){const first=lore[a],second=lore[b];if(first.element===second.element)return '二人の星座はどちらも「'+first.element+'」の元素です。象徴の言葉が似ているため、同じ感覚を共有する物語として読むことができます。ただし、現実の相性を保証するものではありません。';return '一方は「'+first.element+'」、もう一方は「'+second.element+'」の元素。'+first.element+'の物語と'+second.element+'の物語は異なる視点を描きます。違いがあるからこそ、二人の関係に別の色が加わるという読み方ができます。'}
export function buildDeepReading(input:Input,extra:Extra):{title:string;intro:string;chapters:Chapter[];method:string;complete:boolean;summary:string[]}{
 const selfSign=sign(input.birthday),selfLore=lore[selfSign],y=yearNum(extra.birthYear),otherYear=yearNum(extra.otherYear),parentYear=yearNum(extra.parentYear);
 const otherValid=validDay(extra.otherBirthday),parentValid=validDay(extra.parentBirthday);
 const chapters:Chapter[]=[];
 chapters.push({label:'01｜太陽星座',title:selfSign+'が持つ象徴の奥行き',body:selfLore.origin+' '+selfLore.gift+' '+selfLore.shadow+' ここからは出生年や身近な人の星座を重ね、「'+selfLore.symbol+'」という物語に別の角度を加えていきます。'});
 if(y!==null){
 const z=yearAnimal(y),num=digitMeaning(y,input.birthday),n=numbers[num];
 chapters.push({label:'02｜生まれ年と干支',title:animals[z]+'年に重なる'+selfSign+'の物語',body:y+'年生まれの干支（暦年基準）は'+animals[z]+'。日本の十二支の象徴では'+animalStories[z]+' 一方、太陽星座の'+selfSign+'は「'+selfLore.symbol+'」を題材にします。二つを重ねるなら「'+selfLore.symbol+'を大切にしながら、'+animalStories[z].replace(/^「|」.*$/g,'')+'」という二重の物語です。※旧暦の旧正月や立春を境にする占術とは一致しない場合があります。'});
 chapters.push({label:'03｜生年月日から読む数秘',title:'数字'+num+'「'+n.name+'」',body:'生年月日'+y+'年'+input.birthday.replace('-','月')+'日 の各数字を加算し、一桁になるまで足した数は'+num+'です。星詠みの数秘物語での主題は「'+n.theme+'」。その陰には「'+n.shadow+'」という問いが並びます。'+selfSign+'の象徴「'+selfLore.symbol+'」と重ねると、同じ星座の人でも生まれ年によって異なる物語が開きます。'});
 }
 if(extra.blood!=='unknown')chapters.push({label:'04｜血液型を物語として重ねる',title:extra.blood+'型というもう一つのモチーフ',body:bloodStories[extra.blood]+' '+selfSign+'の「'+selfLore.symbol+'」と重ねるなら、互いに異なる言葉で同じ自分を照らしてみるための読み方です。血液型が性格・相性・運勢を予測するという科学的根拠はありません。'});
 if(otherValid){
 const otherSign=sign(extra.otherBirthday),o=lore[otherSign],related=relationNames[extra.relation];
 chapters.push({label:'05｜二人の星を読む',title:selfSign+' × '+otherSign+'｜'+related+'との関係',body:related+'として選んだ相手は'+otherSign+'。あなたの'+selfSign+'が「'+selfLore.symbol+'」なら、相手の'+otherSign+'は「'+o.symbol+'」。'+modeTogether(selfSign,otherSign)+' '+relationshipThemes[extra.relation]});
 chapters.push({label:'06｜関係を深く読む',title:'ふたつの星が映す、距離と縁のかたち',body:'あなたの星座が大切にする象徴は「'+selfLore.gift+'」。相手側の星座の象徴は「'+o.gift+'」。これらを並べると、一緒に大切にしたいことと、それぞれの持ち味を尊重することの二つが浮かびます。'+(otherYear!==null?'相手の'+otherYear+'年は'+animals[yearAnimal(otherYear)]+'年（暦年基準）で、「'+animalStories[yearAnimal(otherYear)]+'」という別の象徴も加わります。':'相手の生まれ年も入力すると、干支の物語まで重ねられます。')+(extra.otherBlood!=='unknown'?' 相手の'+extra.otherBlood+'型は血液型占いの比喩としてのみ扱い、本人の本心や性格を断定しません。':'')});
 }
 if(parentValid){
 const pSign=sign(extra.parentBirthday),pLore=lore[pSign];
 chapters.push({label:'07｜家族の星を重ねる',title:'あなたの星と、親の星が語る物語',body:'親の星座は'+pSign+'。「'+pLore.symbol+'」という象徴と、あなたの'+selfSign+'の「'+selfLore.symbol+'」が並びます。家族から受け継いだ世界観と、自分で選び取った世界観を、それぞれ異なる星の物語になぞらえて読みます。'+modeTogether(selfSign,pSign)+(parentYear!==null?' 親の生まれ年'+parentYear+'年（暦年基準）は'+animals[yearAnimal(parentYear)]+'。世代差が生む異なる物語をさらに想像できます。':'')+' 親の気持ちや親子関係の良し悪しは誕生日だけでは分かりません。'});
 }
 const summary=[selfSign+'｜'+selfLore.symbol,...(y!==null?[animals[yearAnimal(y)]+'年｜数秘'+digitMeaning(y,input.birthday)]:[]),...(extra.blood!=='unknown'?[extra.blood+'型（娯楽的解釈）']:[]),...(otherValid?[relationNames[extra.relation]+'：'+sign(extra.otherBirthday)]:[]),...(parentValid?['親：'+sign(extra.parentBirthday)]:[])];
 return {title:'星を重ねて読む、あなたと大切な人の物語',intro:'通常の太陽星座に、出生年・干支・数秘・任意の血液型・身近な人の星座を重ねて、一つの星座だけでは描けない物語を紡ぎます。',chapters,complete:y!==null,summary,method:'生まれ年の干支は日本の暦年（1月1日切替）で簡易計算。数秘は西暦生年月日の数字を加算し1〜9へ還元する星詠み独自の娯楽的読み方です。血液型と性格の関連は科学的に立証されていません。出生時刻・出生地を使う本格ホロスコープや旧暦・立春を基準にした四柱推命の計算ではありません。鑑定文は入力項目を組み合わせた創作的な解釈です。'};
}
