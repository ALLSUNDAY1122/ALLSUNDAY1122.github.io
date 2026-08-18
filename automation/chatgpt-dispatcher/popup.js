const $ = (id) => document.getElementById(id);

async function load() {
  const state = await chrome.storage.local.get([
    "enabled", "pollMinutes", "maxActive", "queueUrl",
    "workerTabs", "lastStatus", "lastRunAt"
  ]);

  $("enabled").checked = Boolean(state.enabled);
  $("pollMinutes").value = String(state.pollMinutes || 2);
  $("maxActive").value = String(state.maxActive || 1);
  $("queueUrl").value = state.queueUrl || "";
  renderWorkers(state.workerTabs || []);
  renderStatus(state);
}

function renderStatus(state) {
  $("status").textContent =
    `状態: ${state.lastStatus || "未開始"}\n` +
    `最終確認: ${state.lastRunAt || "なし"}`;
}

function renderWorkers(workers) {
  const root = $("workers");
  root.innerHTML = "";
  if (!workers.length) {
    root.textContent = "Worker未登録";
    return;
  }

  for (const worker of workers) {
    const row = document.createElement("div");
    row.className = "worker";
    const text = document.createElement("span");
    text.textContent = `${worker.label} [${worker.role}] tab=${worker.tabId}`;
    const remove = document.createElement("button");
    remove.textContent = "解除";
    remove.addEventListener("click", async () => {
      const current = await chrome.storage.local.get("workerTabs");
      const next = (current.workerTabs || []).filter((w) => w.tabId !== worker.tabId);
      await chrome.storage.local.set({ workerTabs: next });
      renderWorkers(next);
    });
    row.append(text, remove);
    root.append(row);
  }
}

$("registerWorker").addEventListener("click", async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  if (!tab?.id || !tab.url?.startsWith("https://chatgpt.com/")) {
    alert("ChatGPTの会話タブを開いた状態で登録してください。");
    return;
  }

  const response = await chrome.tabs.sendMessage(tab.id, { type: "PING" }).catch(() => null);
  if (!response?.ok) {
    alert("ChatGPTタブへ接続できません。ページを再読み込みして再試行してください。");
    return;
  }

  const current = await chrome.storage.local.get("workerTabs");
  const workers = (current.workerTabs || []).filter((w) => w.tabId !== tab.id);
  workers.push({
    tabId: tab.id,
    label: $("workerLabel").value.trim() || `Worker-${tab.id}`,
    role: $("workerRole").value || "ANY"
  });
  await chrome.storage.local.set({ workerTabs: workers });
  renderWorkers(workers);
});

$("save").addEventListener("click", async () => {
  await chrome.storage.local.set({
    enabled: $("enabled").checked,
    pollMinutes: Number($("pollMinutes").value),
    maxActive: Number($("maxActive").value),
    queueUrl: $("queueUrl").value.trim()
  });
  await chrome.runtime.sendMessage({ type: "SETTINGS_CHANGED" });
  await load();
});

$("dispatchNow").addEventListener("click", async () => {
  $("status").textContent = "確認中...";
  await chrome.runtime.sendMessage({ type: "DISPATCH_NOW" });
  await load();
});

$("clearLeases").addEventListener("click", async () => {
  await chrome.runtime.sendMessage({ type: "CLEAR_LEASES" });
  await load();
});

chrome.storage.onChanged.addListener(() => load());
load();
