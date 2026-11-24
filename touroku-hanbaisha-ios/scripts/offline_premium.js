
let premiumUnlocked=false;
function canStudy(q){return !!q&&(premiumUnlocked||freeIds.has(q.id))}
function requestPremium(){window.webkit?.messageHandlers?.premiumPaywall?.postMessage('open')}
window.setPremiumEntitlement=(v)=>{premiumUnlocked=v===true;const active=document.getElementById('quiz');if(active&&!active.classList.contains('hidden')&&subset.some(q=>!canStudy(q)))beginSetup();if(records.length){updateCount();if(!document.getElementById('home').classList.contains('hidden'))showHome()}document.getElementById('premiumStatus').textContent=premiumUnlocked?'全599問利用中':'無料50問・追加549問はプレミアム';};
document.getElementById('premiumButton').onclick=requestPremium;
