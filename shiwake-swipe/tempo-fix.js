(() => {
  'use strict';

  const feedback = document.getElementById('feedbackPanel');
  const nextButton = document.getElementById('nextButton');
  const gameScreen = document.getElementById('gameScreen');
  const questionCard = document.getElementById('questionCard');
  const debitButton = document.getElementById('debitButton');
  const creditButton = document.getElementById('creditButton');
  if (!feedback || !nextButton || !gameScreen) return;

  let advanceTimer = null;

  const clearAdvance = () => {
    window.clearTimeout(advanceTimer);
    advanceTimer = null;
    feedback.classList.remove('quick-feedback');
  };

  const scheduleIfAnswered = () => {
    window.setTimeout(() => {
      if (gameScreen.classList.contains('is-hidden') || feedback.classList.contains('is-hidden')) return;
      window.clearTimeout(advanceTimer);
      feedback.classList.add('quick-feedback');
      advanceTimer = window.setTimeout(() => {
        if (!gameScreen.classList.contains('is-hidden') && !feedback.classList.contains('is-hidden')) {
          nextButton.click();
        }
        clearAdvance();
      }, 720);
    }, 0);
  };

  debitButton?.addEventListener('click', scheduleIfAnswered);
  creditButton?.addEventListener('click', scheduleIfAnswered);
  questionCard?.addEventListener('pointerup', scheduleIfAnswered);

  window.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') scheduleIfAnswered();
  });
  window.addEventListener('pagehide', clearAdvance);
})();
