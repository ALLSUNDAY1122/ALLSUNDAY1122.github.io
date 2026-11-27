import type {Metadata} from 'next';import './style.css';
export const metadata:Metadata={title:'星詠み｜星座から大切な人との縁まで',description:'12星座の物語から干支、数秘、相手や家族との縁へ。静かな星の世界で楽しむ日本語の占い。',robots:{index:false,follow:false}};
export default function RootLayout({children}:{children:React.ReactNode}){
 return <html lang="ja"><body>
  <div className="cosmos" aria-hidden="true"><div className="nebula nebulaOne"/><div className="nebula nebulaTwo"/><div className="stars starsNear"/><div className="stars starsFar"/></div>
  <main className="site">
   <header className="hero"><a href="/" className="brand">✧ HOSHIYOMI ✧</a><div className="halo" aria-hidden="true"><div className="haloRing"><span>☾</span></div></div><div className="heroEyebrow">THE STORY OF YOUR STARS</div><h1>星が映す、<em>あなたの物語。</em></h1><p>ひとつの星から、まだ知らない縁の景色へ。</p><div className="heroDivider" aria-hidden="true">✦ ───── ✧ ───── ✦</div></header>
   {children}
   <footer>星詠みは娯楽としての占いです。診断を根拠に重大な判断をしないでください。<p><a href="/legal">料金と運営について</a></p></footer>
  </main>
 </body></html>
}