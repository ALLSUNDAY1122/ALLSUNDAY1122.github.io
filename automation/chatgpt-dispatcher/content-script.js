function findComposer() {
  return (
    document.querySelector("#prompt-textarea") ||
    document.querySelector('div[contenteditable="true"][data-virtualkeyboard="true"]') ||
    document.querySelector('div[contenteditable="true"]') ||
    document.querySelector("textarea")
  );
}

function findSendButton() {
  const direct =
    document.querySelector('button[data-testid="send-button"]') ||
    document.querySelector('button[aria-label="Send prompt"]') ||
    document.querySelector('button[aria-label*="Send"]') ||
    document.querySelector('button[aria-label*="送信"]');
  if (direct) return direct;

  const buttons = [...document.querySelectorAll("button")];
  return buttons.find((button) => {
    const label = `${button.getAttribute("aria-label") || ""} ${button.textContent || ""}`;
    return /send|送信/i.test(label);
  }) || null;
}

function isBusy() {
  const stopButton =
    document.querySelector('button[data-testid="stop-button"]') ||
    document.querySelector('button[aria-label*="Stop"]') ||
    document.querySelector('button[aria-label*="停止"]');
  return Boolean(stopButton);
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

async function insertPrompt(prompt) {
  const composer = findComposer();
  if (!composer) return { ok: false, error: "composer_not_found" };
  if (isBusy()) return { ok: false, error: "worker_busy" };

  composer.focus();

  if (composer instanceof HTMLTextAreaElement || composer instanceof HTMLInputElement) {
    setNativeValue(composer, prompt);
  } else {
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
      composer.dispatchEvent(
        new InputEvent("input", {
          bubbles: true,
          inputType: "insertText",
          data: prompt
        })
      );
    }
  }

  await new Promise((resolve) => setTimeout(resolve, 500));
  const sendButton = findSendButton();
  if (!sendButton) return { ok: false, error: "send_button_not_found" };
  if (sendButton.disabled || sendButton.getAttribute("aria-disabled") === "true") {
    return { ok: false, error: "send_button_disabled" };
  }

  sendButton.click();
  return { ok: true };
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message?.type === "GET_STATE") {
      const composer = findComposer();
      sendResponse({
        ok: true,
        idle: Boolean(composer) && !isBusy(),
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
