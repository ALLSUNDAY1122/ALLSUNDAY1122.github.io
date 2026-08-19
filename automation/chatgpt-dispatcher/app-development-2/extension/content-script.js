function visible(element) {
  if (!element) return false;
  const style = window.getComputedStyle(element);
  if (style.display === "none" || style.visibility === "hidden" || style.opacity === "0") return false;
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}

const COMPOSER_SELECTORS = [
  "#prompt-textarea",
  '[data-testid="composer-text-input"]',
  'div.ProseMirror[contenteditable="true"]',
  '[contenteditable="true"][role="textbox"]',
  'div[contenteditable="true"][data-lexical-editor="true"]',
  'div[contenteditable="true"][data-virtualkeyboard="true"]',
  "textarea[placeholder]",
  "textarea"
];

const SEND_SELECTORS = [
  'button[data-testid="send-button"]',
  'button[aria-label="Send prompt"]',
  'button[aria-label="送信"]',
  'button[aria-label="Send message"]',
  'button[aria-label="メッセージを送信"]'
];

function findComposerWithSelector() {
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
  const found = findComposerWithSelector();
  const stop = findStopButton();
  const send = findSendButton();
  return {
    ok: true,
    idle: Boolean(found.element) && !Boolean(stop),
    composerFound: Boolean(found.element),
    composerSelector: found.selector,
    busy: Boolean(stop),
    stopButtonFound: Boolean(stop),
    sendButtonFound: Boolean(send),
    url: location.href
  };
}

function clearContentEditable(composer) {
  composer.focus();
  try {
    const selection = window.getSelection();
    const range = document.createRange();
    range.selectNodeContents(composer);
    selection.removeAllRanges();
    selection.addRange(range);
    document.execCommand("delete", false, null);
    selection.removeAllRanges();
  } catch (_) {
    composer.replaceChildren();
  }
  composer.dispatchEvent(new InputEvent("input", {
    bubbles: true,
    inputType: "deleteContentBackward",
    data: null
  }));
}

function insertContentEditable(composer, prompt) {
  composer.focus();
  let inserted = false;
  try {
    inserted = document.execCommand("insertText", false, prompt);
  } catch (_) {
    inserted = false;
  }
  if (!inserted || !composer.textContent || !composer.textContent.trim()) {
    composer.replaceChildren(document.createTextNode(prompt));
  }
  composer.dispatchEvent(new InputEvent("input", {
    bubbles: true,
    inputType: "insertText",
    data: prompt
  }));
}

function setNativeValue(element, value) {
  const prototype = Object.getPrototypeOf(element);
  const descriptor = Object.getOwnPropertyDescriptor(prototype, "value");
  if (descriptor && descriptor.set) descriptor.set.call(element, value);
  else element.value = value;
  element.dispatchEvent(new Event("input", { bubbles: true }));
  element.dispatchEvent(new Event("change", { bubbles: true }));
}

async function waitForSendButton(timeoutMs) {
  const until = Date.now() + timeoutMs;
  while (Date.now() < until) {
    const button = findSendButton();
    if (button && !button.disabled && button.getAttribute("aria-disabled") !== "true") return button;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}

function userMessages() {
  return Array.from(document.querySelectorAll('[data-message-author-role="user"]'));
}

async function confirmPost(beforeCount, prompt) {
  const until = Date.now() + 8000;
  while (Date.now() < until) {
    await new Promise((resolve) => setTimeout(resolve, 200));
    const messages = userMessages();
    if (messages.length <= beforeCount) continue;
    const last = messages[messages.length - 1];
    const lastText = (last.innerText || last.textContent || "").trim();
    if (prompt === "次") {
      if (lastText === prompt || lastText.includes(prompt)) {
        return { confirmed: true, lastText: prompt };
      }
      continue;
    }
    return { confirmed: true, lastText: "task_posted" };
  }
  return { confirmed: false };
}

async function dispatch(prompt) {
  const initial = diagnosticState();
  if (!initial.composerFound) return { ok: false, error: "composer_not_found", ...initial };
  if (initial.busy || !initial.idle) return { ok: false, error: "worker_busy", ...initial };

  const beforeCount = userMessages().length;
  const composer = findComposerWithSelector().element;
  if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
    setNativeValue(composer, "");
    setNativeValue(composer, prompt);
  } else {
    clearContentEditable(composer);
    insertContentEditable(composer, prompt);
  }

  const send = await waitForSendButton(4000);
  if (!send) return { ok: false, error: "send_button_not_ready", ...diagnosticState() };
  if (findStopButton()) return { ok: false, error: "worker_became_busy", ...diagnosticState() };

  send.click();
  const confirmation = await confirmPost(beforeCount, prompt);
  if (!confirmation.confirmed) return { ok: false, error: "post_not_confirmed", ...diagnosticState() };
  return { ok: true, confirmed: true, composerSelector: initial.composerSelector, url: location.href };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message && (message.type === "PING" || message.type === "GET_STATE")) {
      sendResponse(diagnosticState());
      return;
    }
    if (message && message.type === "DISPATCH") {
      sendResponse(await dispatch(String(message.prompt || "")));
      return;
    }
    sendResponse({ ok: false, error: "unknown_message" });
  })().catch((error) => sendResponse({ ok: false, error: String(error) }));
  return true;
});
