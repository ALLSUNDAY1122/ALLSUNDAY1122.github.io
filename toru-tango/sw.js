const CACHE='toru-tango-v4';
const ASSETS=[
  './',
  './index.html',
  './folders-addon.js',
  './privacy-policy.html',
  './manifest.webmanifest',
  './generator-v2.js',
  './generator-test.html'
];

self.addEventListener('install',event=>{
  event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)));
  self.skipWaiting();
});

self.addEventListener('activate',event=>{
  event.waitUntil(
    caches.keys().then(keys=>Promise.all(keys.filter(key=>key!==CACHE).map(key=>caches.delete(key))))
  );
  self.clients.claim();
});

async function getNavigationResponse(request){
  let response;
  try{
    response=await fetch(request,{cache:'no-store'});
  }catch{
    response=await caches.match('./index.html')||await caches.match('./');
  }
  if(!response)return new Response('オフラインです。',{status:503,headers:{'Content-Type':'text/plain; charset=utf-8'}});
  const html=await response.text();
  const injected=html.includes('generator-v2.js')
    ?html
    :html.replace('</body>','<script src="generator-v2.js?v=20260726"></script></body>');
  const headers=new Headers(response.headers);
  headers.set('Content-Type','text/html; charset=utf-8');
  headers.delete('Content-Length');
  headers.delete('Content-Encoding');
  return new Response(injected,{status:response.status,statusText:response.statusText,headers});
}

self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  const isAppNavigation=event.request.mode==='navigate'&&
    (url.pathname.endsWith('/toru-tango/')||url.pathname.endsWith('/toru-tango/index.html'));
  if(isAppNavigation){
    event.respondWith(getNavigationResponse(event.request));
    return;
  }
  event.respondWith(
    fetch(event.request).then(response=>{
      const copy=response.clone();
      caches.open(CACHE).then(cache=>cache.put(event.request,copy));
      return response;
    }).catch(()=>caches.match(event.request).then(cached=>cached||caches.match('./')))
  );
});
