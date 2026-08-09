'use strict';
(function(){
  try {
    if (typeof TSUKANSHI_QUESTIONS !== 'undefined') window.TSUKANSHI_QUESTIONS = TSUKANSHI_QUESTIONS;
    if (typeof TSUKANSHI_CONTENT_VERSION !== 'undefined') window.TSUKANSHI_CONTENT_VERSION = TSUKANSHI_CONTENT_VERSION;
    if (typeof TSUKANSHI_LAW_BASELINE !== 'undefined') window.TSUKANSHI_LAW_BASELINE = TSUKANSHI_LAW_BASELINE;
    window.__TSUKANSHI_BOOTSTRAP = {
      questionCount: Array.isArray(window.TSUKANSHI_QUESTIONS) ? window.TSUKANSHI_QUESTIONS.length : 0,
      contentVersion: window.TSUKANSHI_CONTENT_VERSION || null,
      lawBaseline: window.TSUKANSHI_LAW_BASELINE || null
    };
  } catch (error) {
    console.error('Tsukanshi bootstrap failed', error);
  }
})();
