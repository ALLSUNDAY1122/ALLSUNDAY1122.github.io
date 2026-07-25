(() => {
  'use strict';

  const card = document.getElementById('questionCard');
  const debitButton = document.getElementById('debitButton');
  const creditButton = document.getElementById('creditButton');
  if (!card || !debitButton || !creditButton) return;

  let startX = null;
  let startY = null;
  let currentX = 0;
  let horizontal = false;

  const reset = () => {
    startX = null;
    startY = null;
    currentX = 0;
    horizontal = false;
    card.classList.remove('is-dragging');
    card.style.transform = '';
    card.removeAttribute('data-direction');
  };

  card.style.touchAction = 'none';

  card.addEventListener('touchstart', event => {
    if (event.touches.length !== 1 || debitButton.disabled || creditButton.disabled) return;
    const touch = event.touches[0];
    startX = touch.clientX;
    startY = touch.clientY;
    currentX = 0;
    horizontal = false;
    card.classList.add('is-dragging');
  }, { passive: true });

  card.addEventListener('touchmove', event => {
    if (startX === null || event.touches.length !== 1) return;
    const touch = event.touches[0];
    const dx = touch.clientX - startX;
    const dy = touch.clientY - startY;
    if (!horizontal && Math.abs(dx) < 8 && Math.abs(dy) < 8) return;
    horizontal = Math.abs(dx) > Math.abs(dy);
    if (!horizontal) return;
    event.preventDefault();
    currentX = dx;
    const rotation = Math.max(-12, Math.min(12, dx / 18));
    card.style.transform = `translate3d(${dx}px,0,0) rotate(${rotation}deg)`;
    if (Math.abs(dx) >= 24) card.dataset.direction = dx < 0 ? 'debit' : 'credit';
    else card.removeAttribute('data-direction');
  }, { passive: false });

  card.addEventListener('touchend', event => {
    if (startX === null) return;
    const dx = currentX;
    reset();
    if (!horizontal) return;
    if (dx <= -56) debitButton.click();
    else if (dx >= 56) creditButton.click();
    event.preventDefault();
  }, { passive: false });

  card.addEventListener('touchcancel', reset, { passive: true });
})();
