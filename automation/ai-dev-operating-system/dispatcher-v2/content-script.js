function visible(element) {
  if (!element) return false;
  const style = window.getComputedStyle(element);
  if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') return false;
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}
const COMPOSER_SELECTORS = [
  '#prompt-textarea', '[data-testid="composer-text-input"]', 'div.ProseMirror[contenteditable="true"]',
  '[contenteditable="true"][role="textbox"]', 'div[contenteditable="true"][data-lexical-editor="true"]',
  'div[contenteditable="true"][data-virtualkeyboard="true"]', 'textarea[placeholder]', 'textarea'
];
const SEND_SELECTORS = [
  'button[data-testid="send-button"]', 'button[aria-label="Send prompt"]', 'button[aria-label="送信"]',
  'button[aria-label="Send message"]', 'button[aria-label="メッセージを送信"]'
];
function findComposer() {
  for (const selector of COMPOSER_SELECTORS) {
    const element = document.querySelector(selector);
    if (visible(element)) return { element, selector };
  }
  return { element: null, selector: null };
}
function findSendButton() {
  for (const selector of SEND_SELECTORS) {
    const button = document.querySelector(selector);
    if (visible(button)) return button;
  }
  return null;
}
function findStopButton() {
  const button = document.querySelector('button[data-testid="stop-button"]');
  return visible(button) ? button : null;
}
function diagnosticState() {
  const composer = findComposer();
  const stop = findStopButton();
  return {
    ok: true, idle: Boolean(composer.element) && !stop, composerFound: Boolean(composer.element),
    composerSelector: composer.selector, busy: Boolean(stop), stopButtonFound: Boolean(stop),
    sendButtonFound: Boolean(findSendButton()), url: location.href
  };
}
function safeText(value, max = 160) {
  return String(value || '').replace(/\s+/g, ' ').trim().slice(0, max);
}
function projectContextProbe() {
  const candidates = [];
  const seen = new Set();
  const matcher = /(project|projects|プロジェクト|new chat|new conversation|chat|チャット|work|新しいチャット|新規チャット)/i;
  const nodes = Array.from(document.querySelectorAll('a, button, [role="button"]'));
  for (const element of nodes) {
    const text = safeText(element.innerText || element.textContent || '');
    const ariaLabel = safeText(element.getAttribute('aria-label') || '');
    const dataTestId = safeText(element.getAttribute('data-testid') || '');
    const hrefRaw = element instanceof HTMLAnchorElement ? element.href : (element.getAttribute('href') || '');
    const href = safeText(hrefRaw, 300);
    const haystack = [text, ariaLabel, dataTestId, href].join(' ');
    if (!matcher.test(haystack)) continue;
    const key = [element.tagName, text, ariaLabel, dataTestId, href].join('|');
    if (seen.has(key)) continue;
    seen.add(key);
    candidates.push({
      tag: element.tagName.toLowerCase(),
      text,
      ariaLabel,
      dataTestId,
      href,
      visible: visible(element)
    });
    if (candidates.length >= 80) break;
  }

  const projectSignals = candidates.filter((item) =>
    /(project|projects|プロジェクト)/i.test([item.text, item.ariaLabel, item.dataTestId, item.href].join(' '))
  );
  const newChatSignals = candidates.filter((item) =>
    /(new chat|new conversation|新しいチャット|新規チャット)/i.test([item.text, item.ariaLabel, item.dataTestId].join(' '))
  );

  return {
    ok: true,
    probeVersion: 1,
    url: location.href,
    pathname: location.pathname,
    title: safeText(document.title, 200),
    conversationId: (location.pathname.match(/\/c\/([^/?#]+)/) || [null, ''])[1],
    composerFound: Boolean(findComposer().element),
    candidateCount: candidates.length,
    projectSignalCount: projectSignals.length,
    newChatSignalCount: newChatSignals.length,
    candidates,
    privacyNote: 'Probe returns navigation metadata only; message bodies are not collected.'
  };
}
function clearEditable(element) {
  element.focus();
  try {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(element);
    selection.removeAllRanges(); selection.addRange(range);
    document.execCommand('delete', false, null);
    selection.removeAllRanges();
  } catch (_) { element.replaceChildren(); }
  element.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'deleteContentBackward', data: null }));
}
function insertEditable(element, prompt) {
  element.focus();
  let inserted = false;
  try { inserted = document.execCommand('insertText', false, prompt); } catch (_) {}
  if (!inserted || !element.textContent || !element.textContent.trim()) element.replaceChildren(document.createTextNode(prompt));
  element.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: prompt }));
}
function setNativeValue(element, value) {
  const descriptor = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(element), 'value');
  if (descriptor && descriptor.set) descriptor.set.call(element, value); else element.value = value;
  element.dispatchEvent(new Event('input', { bubbles: true }));
  element.dispatchEvent(new Event('change', { bubbles: true }));
}
async function waitForSend(timeoutMs) {
  const until = Date.now() + timeoutMs;
  while (Date.now() < until) {
    const button = findSendButton();
    if (button && !button.disabled && button.getAttribute('aria-disabled') !== 'true') return button;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}
function userMessages() { return Array.from(document.querySelectorAll('[data-message-author-role="user"]')); }
async function confirmPost(beforeCount, prompt) {
  const until = Date.now() + 8000;
  while (Date.now() < until) {
    await new Promise((resolve) => setTimeout(resolve, 200));
    const messages = userMessages();
    if (messages.length <= beforeCount) continue;
    const text = (messages[messages.length - 1].innerText || messages[messages.length - 1].textContent || '').trim();
    if (prompt !== '次' || text === '次' || text.includes('次')) return true;
  }
  return false;
}
async function dispatch(prompt) {
  const initial = diagnosticState();
  if (!initial.composerFound) return { ok: false, error: 'composer_not_found', ...initial };
  if (initial.busy || !initial.idle) return { ok: false, error: 'worker_busy', ...initial };
  const beforeCount = userMessages().length;
  const composer = findComposer().element;
  if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
    setNativeValue(composer, ''); setNativeValue(composer, prompt);
  } else { clearEditable(composer); insertEditable(composer, prompt); }
  const send = await waitForSend(4000);
  if (!send) return { ok: false, error: 'send_button_not_ready', ...diagnosticState() };
  if (findStopButton()) return { ok: false, error: 'worker_became_busy', ...diagnosticState() };
  send.click();
  if (!(await confirmPost(beforeCount, prompt))) return { ok: false, error: 'post_not_confirmed', ...diagnosticState() };
  return { ok: true, confirmed: true, url: location.href };
}
chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message && (message.type === 'PING' || message.type === 'GET_STATE')) return sendResponse(diagnosticState());
    if (message && message.type === 'PROJECT_CONTEXT_PROBE') return sendResponse(projectContextProbe());
    if (message && message.type === 'DISPATCH') return sendResponse(await dispatch(String(message.prompt || '')));
    sendResponse({ ok: false, error: 'unknown_message' });
  })().catch((error) => sendResponse({ ok: false, error: String(error) }));
  return true;
});
