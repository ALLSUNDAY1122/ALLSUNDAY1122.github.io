(() => {
  'use strict';

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const score = document.getElementById('scoreValue');
  const combo = document.getElementById('comboValue');
  const feedback = document.getElementById('feedbackPanel');
  const card = document.getElementById('questionCard');
  const result = document.getElementById('resultScreen');
  const layer = document.createElement('div');
  layer.className = 'celebration-layer';
  layer.setAttribute('aria-hidden', 'true');
  document.body.appendChild(layer);

  function bump(element) {
    if (!element || reducedMotion) return;
    element.classList.remove('is-bumping');
    void element.offsetWidth;
    element.classList.add('is-bumping');
    window.setTimeout(() => element.classList.remove('is-bumping'), 240);
  }

  function sparks(count = 18, originX = innerWidth / 2, originY = innerHeight * 0.38) {
    if (reducedMotion) return;
    const fragment = document.createDocumentFragment();
    for (let i = 0; i < count; i += 1) {
      const spark = document.createElement('i');
      const angle = (Math.PI * 2 * i) / count + Math.random() * 0.3;
      const distance = 70 + Math.random() * 150;
      spark.className = 'spark';
      spark.style.left = `${originX}px`;
      spark.style.top = `${originY}px`;
      spark.style.setProperty('--dx', `${Math.cos(angle) * distance}px`);
      spark.style.setProperty('--dy', `${Math.sin(angle) * distance + 40}px`);
      spark.style.setProperty('--rot', `${Math.round(Math.random() * 620 - 310)}deg`);
      spark.style.background = i % 3 === 0 ? 'var(--debit)' : i % 3 === 1 ? 'var(--credit)' : 'var(--accent)';
      fragment.appendChild(spark);
      window.setTimeout(() => spark.remove(), 900);
    }
    layer.appendChild(fragment);
  }

  function comboPop(value) {
    if (reducedMotion || value < 5 || value % 5 !== 0) return;
    const pop = document.createElement('div');
    pop.className = 'combo-pop';
    pop.textContent = `${value} COMBO!`;
    document.body.appendChild(pop);
    sparks(value >= 20 ? 28 : 18);
    window.setTimeout(() => pop.remove(), 760);
  }

  let previousScore = Number(score?.textContent.replace(/,/g, '')) || 0;
  let previousCombo = Number(combo?.textContent) || 0;

  const statusObserver = new MutationObserver(() => {
    const nextScore = Number(score?.textContent.replace(/,/g, '')) || 0;
    const nextCombo = Number(combo?.textContent) || 0;
    if (nextScore !== previousScore) bump(score);
    if (nextCombo !== previousCombo) {
      bump(combo);
      comboPop(nextCombo);
    }
    previousScore = nextScore;
    previousCombo = nextCombo;
  });
  if (score) statusObserver.observe(score, { childList: true, characterData: true, subtree: true });
  if (combo) statusObserver.observe(combo, { childList: true, characterData: true, subtree: true });

  if (feedback) {
    new MutationObserver(() => {
      if (feedback.classList.contains('is-hidden')) return;
      if (feedback.classList.contains('is-correct')) {
        const rect = card?.getBoundingClientRect();
        sparks(12, rect ? rect.left + rect.width / 2 : innerWidth / 2, rect ? rect.top + rect.height / 2 : innerHeight * 0.4);
      }
    }).observe(feedback, { attributes: true, attributeFilter: ['class'] });
  }

  if (result) {
    new MutationObserver(() => {
      if (!result.classList.contains('is-hidden')) sparks(34, innerWidth / 2, innerHeight * 0.32);
    }).observe(result, { attributes: true, attributeFilter: ['class'] });
  }

  document.querySelectorAll('button').forEach(button => {
    button.addEventListener('pointerdown', () => {
      if (navigator.vibrate && !reducedMotion) navigator.vibrate(8);
    }, { passive: true });
  });
})();