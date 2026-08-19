const status = document.getElementById("status");
const version = document.getElementById("version");

function line(value) {
  return value === null || value === undefined || value === "" ? "-" : String(value);
}

function render(state) {
  version.textContent = "v" + chrome.runtime.getManifest().version;
  const workers = Array.isArray(state.workers) ? state.workers : [];
  const stopped = workers.filter((worker) => worker.stopped).map((worker) => worker.role).join(", ");
  const last = state.lastRound || {};
  status.textContent = [
    "状態: " + line(state.lastStatus),
    "run_count: " + line(state.runCount) + "/" + line(state.runLimit),
    "次回: " + line(state.nextRunAt),
    "Worker: " + line(state.workerCount) + "/13",
    "停止Worker: " + (stopped || "-"),
    "最終Round: sent=" + line(last.sent) + " skip=" + line(last.skipped)
  ].join("\n");
}

async function load() {
  const state = await chrome.runtime.sendMessage({ type: "APP2_STATUS" });
  render(state || {});
}

document.getElementById("diagnose").addEventListener("click", async () => {
  status.textContent = "診断中...";
  const result = await chrome.runtime.sendMessage({ type: "APP2_PREFLIGHT" });
  const passed = result && result.passed !== undefined ? result.passed : 0;
  const total = result && result.total !== undefined ? result.total : 13;
  status.textContent = "診断: " + passed + "/" + total + " ready";
  await load();
});

document.getElementById("start").addEventListener("click", async () => {
  status.textContent = "Round 1を開始中...";
  await chrome.runtime.sendMessage({ type: "APP2_START" });
  await load();
});

document.getElementById("stop").addEventListener("click", async () => {
  await chrome.runtime.sendMessage({ type: "APP2_STOP" });
  await load();
});

chrome.storage.onChanged.addListener(() => load());
load();
