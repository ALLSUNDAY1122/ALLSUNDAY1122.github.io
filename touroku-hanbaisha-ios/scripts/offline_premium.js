let premiumUnlocked=false;
function canStudy(q){return !!q&&(premiumUnlocked||freeIds.has(q.id))}
function requestPremium(){window.webkit?.messageHandlers?.premiumPaywall?.postMessage('open')}
window.setPremiumEntitlement=(v)=>{
  premiumUnlocked=v===true;
  const active=document.getElementById('quiz');
  if(active&&!active.classList.contains('hidden')&&subset.some(q=>!canStudy(q)))beginSetup();
  if(records.length){updateCount();if(!document.getElementById('home').classList.contains('hidden'))showHome()}
  const status=premiumUnlocked?'Premium利用中：全599問を利用できます':'無料プラン：対象50問を利用できます';
  document.getElementById('premiumStatus').textContent=status;
  document.getElementById('settingsPremiumStatus').textContent=status;
  renderMockYears();
};
document.getElementById('premiumButton').onclick=requestPremium;
document.getElementById('settingsPremium').onclick=requestPremium;

// Keep the attribution element mounted between questions while showing it inside the judgement card.
const attributionNode=$('attribution');
const renderQuestionBase=show;
show=function(...args){
  const card=$('quiz').querySelector('article.card');
  card.append(attributionNode);
  const result=renderQuestionBase(...args);
  // A new question must never retain the previous judgement card's attribution.
  $('feedback').querySelector('#attribution')?.remove();
  card.append(attributionNode);
  attributionNode.classList.add('hidden');
  return result;
};
const renderJudgementBase=renderAnswer;
renderAnswer=function(i){
  const result=renderJudgementBase(i);
  // Keep the source links inside the judgement card until the next question.
  $('feedback').append(attributionNode);
  attributionNode.classList.remove('hidden');
  return result;
};
