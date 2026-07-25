(() => {
  'use strict';

  const feedback = document.getElementById('feedbackPanel');
  const nextButton = document.getElementById('nextButton');
  const gameScreen = document.getElementById('gameScreen');
  if (!feedback || !nextButton || !gameScreen) return;

  let advanceTimer = null;
  let lastVisible = false;

  const scheduleAdvance = () => {
    window.clearTimeout(advanceTimer);
    feedback.classList.add('quick-feedback');
    advanceTimer = window.setTimeout(() => {
      if (!gameScreen.classList.contains('is-hidden') && !feedback.classList.contains('is-hidden')) {
        nextButton.click();
      }
    }, 720);
  };

  const observer = new MutationObserver(() => {
    const visible = !feedback.classList.contains('is-hidden');
    if (visible && !lastVisible) scheduleAdvance();
    if (!visible) {
      window.clearTimeout(advanceTimer);
      feedback.classList.remove('quick-feedback');
    }
    lastVisible = visible;
  });

  observer.observe(feedback, { attributes: true, attributeFilter: ['class'] });

  window.addEventListener('pagehide', () => window.clearTimeout(advanceTimer));
})();
