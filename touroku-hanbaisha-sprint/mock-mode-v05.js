'use strict';
(function(){
  const app=document.getElementById('app');
  if(!app) return;
  let advancing=false;
  function sync(){
    const title=app.querySelector('.header h1');
    const isMock=!!title&&title.textContent.includes('本番模試｜120問');
    document.body.classList.toggle('mock-running',isMock);
    if(!isMock){advancing=false;return;}
    const wrap=app.querySelector('.quiz-wrap');
    if(wrap&&!wrap.querySelector('.mock-live-note')){
      const note=document.createElement('div');
      note.className='mock-live-note';
      note.textContent='模試中は正誤・解説を表示しません。選択すると次の問題へ進みます。';
      wrap.insertBefore(note,wrap.firstChild);
    }
    const feedback=app.querySelector('.feedback');
    const next=app.querySelector('#nextBtn');
    if(feedback&&next&&!advancing){
      advancing=true;
      queueMicrotask(()=>{try{next.click()}finally{advancing=false}});
    }
  }
  new MutationObserver(sync).observe(app,{childList:true,subtree:true});
  sync();
})();
