function isVisible(element) {
  if (!element) return false;
  const style = window.getComputedStyle(element);
  if (style.display === "none" || style.visibility === "hidden") return false;
  const rect = element.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0;
}

function findComposer() {
  const candidates = [
    document.querySelector("#prompt-textarea"),
    document.querySelector('div[contenteditable="true"][data-lexical-editor="true"]'),
    document.querySelector('div[contenteditable="true"][data-virtualkeyboard="true"]'),
    document.querySelector('textarea[placeholder]'),
    document.querySelector("textarea")
  ];
  return candidates.find((element) => isVisible(element)) || null;
}

function findSendButton() {
  const selectors = [
    'button[data-testid="send-button"]',
    'button[aria-label="Send prompt"]',
    'button[aria-label="送信"]',
    'button[aria-label="Send message"]',
    'button[aria-label="メッセージを送信"]'
  ];
  for (const selector of selectors) {
    const button = document.querySelector(selector);
    if (isVisible(button)) return button;
  }
  return null;
}

function findStopButton() {
  const selectors = [
    'button[data-testid="stop-button"]',
    'button[aria-label="Stop generating"]',
    'button[aria-label="Stop streaming"]',
    'button[aria-label="応答を停止"]',
    'button[aria-label="生成を停止"]'
  ];
  for (const selector of selectors) {
    const button = document.querySelector(selector);
    if (isVisible(button)) return button;
  }
  return null;
}

function isBusy() {
  return Boolean(findStopButton());
}

function setNativeValue(element, value) {
  const prototype = Object.getPrototypeOf(element);
  const descriptor = Object.getOwnPropertyDescriptor(prototype, "value");
  if (descriptor?.set) {
    descriptor.set.call(element, value);
  } else {
    element.value = value;
  }
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
    composer.textContent = prompt;
    composer.dispatchEvent(new InputEvent("input", {
      bubbles: true,
      inputType: "insertText",
      data: prompt
    }));
  }
}

async function waitForSendButton(timeoutMs = 2500) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const button = findSendButton();
    if (button && !button.disabled && button.getAttribute("aria-disabled") !== "true") {
      return button;
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  return null;
}

async function insertPrompt(prompt) {
  const composer = findComposer();
  if (!composer) return { ok: false, error: "composer_not_found" };
  if (isBusy()) return { ok: false, error: "worker_busy" };

  composer.focus();
  if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
    setNativeValue(composer, prompt);
  } else {
    setContentEditableValue(composer, prompt);
  }

  const sendButton = await waitForSendButton();
  if (!sendButton) return { ok: false, error: "send_button_not_ready" };

  sendButton.click();
  return { ok: true };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message?.type === "GET_STATE") {
      const composer = findComposer();
      const busy = isBusy();
      sendResponse({
        ok: true,
        idle: Boolean(composer) && !busy,
        composerFound: Boolean(composer),
        busy,
        sendButtonFound: Boolean(findSendButton()),
        url: location.href
      });
      return;
    }

    if (message?.type === "DISPATCH") {
      const result = await insertPrompt(message.prompt || "");
      sendResponse(result);
      return;
    }

    if (message?.type === "PING") {
      sendResponse({ ok: true, url: location.href });
      return;
    }

    sendResponse({ ok: false, error: "unknown_message" });
  })().catch((error) => sendResponse({ ok: false, error: String(error) }));
  return true;
});
