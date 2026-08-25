function isVisible(element) {
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
  'textarea[placeholder]',
  'textarea'
];

function findComposerWithSelector() {
  for (const selector of COMPOSER_SELECTORS) {
    const element = document.querySelector(selector);
    if (isVisible(element)) return { element, selector };
  }
  return { element: null, selector: null };
}

function findComposer() {
  return findComposerWithSelector().element;
}

const SEND_SELECTORS = [
  'button[data-testid="send-button"]',
  'button[aria-label="Send prompt"]',
  'button[aria-label="送信"]',
  'button[aria-label="Send message"]',
  'button[aria-label="メッセージを送信"]'
];

function findSendButton() {
  for (const selector of SEND_SELECTORS) {
    const button = document.querySelector(selector);
    if (isVisible(button)) return button;
  }
  return null;
}

function findStopButton() {
  const button = document.querySelector('button[data-testid="stop-button"]');
  return isVisible(button) ? button : null;
}

function isBusy() {
  return Boolean(findStopButton());
}

function setNativeValue(element, value) {
  const prototype = Object.getPrototypeOf(element);
  const descriptor = Object.getOwnPropertyDescriptor(prototype, "value");
  if (descriptor?.set) descriptor.set.call(element, value);
  else element.value = value;
  element.dispatchEvent(new Event("input", { bubbles: true }));
  element.dispatchEvent(new Event("change", { bubbles: true }));
}

function setContentEditableValue(composer, prompt) {
  composer.focus();
  const selection = window.getSelection();
  const range = document.createRange();
  range.selectNodeContents(composer);
  selection.removeAllRanges();
  selection.addRange(range);

  let inserted = false;
  try {
    inserted = document.execCommand("insertText", false, prompt);
  } catch (_) {
    inserted = false;
  }

  if (!inserted || !composer.textContent?.trim()) {
    composer.replaceChildren(document.createTextNode(prompt));
    composer.dispatchEvent(new InputEvent("input", {
      bubbles: true,
      inputType: "insertText",
      data: prompt
    }));
  }
}

async function waitForSendButton(timeoutMs = 4000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const button = findSendButton();
    if (button && !button.disabled && button.getAttribute("aria-disabled") !== "true") return button;
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}

function diagnosticState() {
  const found = findComposerWithSelector();
  return {
    ok: true,
    idle: Boolean(found.element) && !isBusy(),
    composerFound: Boolean(found.element),
    composerSelector: found.selector,
    busy: isBusy(),
    stopButtonFound: Boolean(findStopButton()),
    sendButtonFound: Boolean(findSendButton()),
    url: location.href,
    title: document.title
  };
}

async function insertPrompt(prompt) {
  const found = findComposerWithSelector();
  const composer = found.element;
  if (!composer) return { ok: false, error: "composer_not_found", ...diagnosticState() };
  if (isBusy()) return { ok: false, error: "worker_busy", ...diagnosticState() };

  if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
    composer.focus();
    setNativeValue(composer, prompt);
  } else {
    setContentEditableValue(composer, prompt);
  }

  const sendButton = await waitForSendButton();
  if (!sendButton) return { ok: false, error: "send_button_not_ready", ...diagnosticState() };
  sendButton.click();
  return { ok: true, composerSelector: found.selector, url: location.href };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message?.type === "GET_STATE" || message?.type === "DIAGNOSE") {
      sendResponse(diagnosticState());
      return;
    }
    if (message?.type === "DISPATCH") {
      sendResponse(await insertPrompt(message.prompt || ""));
      return;
    }
    if (message?.type === "PING") {
      sendResponse({ ok: true, version: "0.1.2", ...diagnosticState() });
      return;
    }
    sendResponse({ ok: false, error: "unknown_message" });
  })().catch((error) => sendResponse({ ok: false, error: String(error) }));
  return true;
});
