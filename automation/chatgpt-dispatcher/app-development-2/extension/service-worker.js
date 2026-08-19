try {
  importScripts("app2-workers.local.js");
} catch (_) {
  self.APP2_LOCAL_WORKERS = [];
  self.APP2_AUTOSTART = false;
}

const STATE_KEY = "app2_dispatcher_state_v1";
const ALARM_NAME = "app2_dispatcher_next_round";
const RUN_LIMIT = 5;
const INTERVAL_MS = 40 * 60 * 1000;
const DEFAULT_QUEUE_URL = "https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/refs/heads/automation/app-development-2-session-dispatcher/automation/chatgpt-dispatcher/app-development-2/queue.json";
const REQUIRED_ROLES = [
  "SHIWAKE", "NOMIDOKORO", "YORU", "YAKUZAISHI", "HM1", "HM2",
  "OTSU4", "ITPASS", "KANGOSHI", "TOUHAN", "TAKU", "NW", "SAGYO16"
];

chrome.runtime.onInstalled.addListener(() => initialize().catch(reportStartupError));
chrome.runtime.onStartup.addListener(() => resume().catch(reportStartupError));
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) runRound("alarm").catch(reportStartupError);
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message && message.type === "APP2_STATUS") {
      sendResponse(await publicStatus());
      return;
    }
    if (message && message.type === "APP2_PREFLIGHT") {
      sendResponse(await preflight());
      return;
    }
    if (message && message.type === "APP2_START") {
      sendResponse(await start());
      return;
    }
    if (message && message.type === "APP2_STOP") {
      sendResponse(await stop("operator_stop"));
      return;
    }
    if (message && message.type === "APP2_RESUME") {
      sendResponse(await resume());
      return;
    }
    sendResponse({ ok: false, error: "unknown_message" });
  })().catch((error) => sendResponse({ ok: false, error: String(error && error.message ? error.message : error) }));
  return true;
});

function nowIso() {
  return new Date().toISOString();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function freshState() {
  return {
    version: 1,
    queueUrl: DEFAULT_QUEUE_URL,
    enabled: false,
    runCount: 0,
    runLimit: RUN_LIMIT,
    intervalMinutes: INTERVAL_MS / 60000,
    startedAt: null,
    nextRunAt: null,
    completedAt: null,
    workers: [],
    stoppedRoles: {},
    activeRound: null,
    lastRound: null,
    lastStatus: "未構成",
    logs: [],
    updatedAt: nowIso()
  };
}

function conversationId(url) {
  try {
    const match = new URL(url).pathname.match(/\/c\/([^/?#]+)/);
    return match ? match[1] : "";
  } catch (_) {
    return "";
  }
}

function normalizeWorker(raw) {
  const id = String(raw && raw.id || "").trim();
  const role = String(raw && raw.role || "").trim();
  const label = String(raw && raw.label || "").trim();
  const conversationUrl = String(raw && raw.conversationUrl || "").trim();
  return {
    id,
    role,
    label,
    conversationUrl,
    conversationId: conversationId(conversationUrl),
    tabId: Number.isInteger(raw && raw.tabId) ? raw.tabId : null,
    stopped: Boolean(raw && raw.stopped),
    stoppedReason: String(raw && raw.stoppedReason || "")
  };
}

function localWorkers() {
  const raw = Array.isArray(self.APP2_LOCAL_WORKERS) ? self.APP2_LOCAL_WORKERS : [];
  return raw.map(normalizeWorker);
}

function validateWorkers(workers) {
  if (!Array.isArray(workers) || workers.length !== REQUIRED_ROLES.length) {
    return { ok: false, error: "worker_count_must_be_13" };
  }
  const roles = new Set();
  const ids = new Set();
  const conversationIds = new Set();
  for (const worker of workers) {
    if (!worker.id || !worker.label || !worker.conversationUrl || !worker.conversationId) {
      return { ok: false, error: "worker_metadata_missing" };
    }
    if (!REQUIRED_ROLES.includes(worker.role)) return { ok: false, error: "unknown_role:" + worker.role };
    if (roles.has(worker.role)) return { ok: false, error: "duplicate_role:" + worker.role };
    if (ids.has(worker.id)) return { ok: false, error: "duplicate_worker_id:" + worker.id };
    if (conversationIds.has(worker.conversationId)) return { ok: false, error: "duplicate_conversation:" + worker.id };
    roles.add(worker.role);
    ids.add(worker.id);
    conversationIds.add(worker.conversationId);
  }
  for (const role of REQUIRED_ROLES) {
    if (!roles.has(role)) return { ok: false, error: "missing_role:" + role };
  }
  return { ok: true };
}

function mergeState(raw) {
  const base = freshState();
  const state = Object.assign(base, raw && typeof raw === "object" ? raw : {});
  state.workers = Array.isArray(state.workers) ? state.workers.map(normalizeWorker) : [];
  state.stoppedRoles = state.stoppedRoles && typeof state.stoppedRoles === "object" ? state.stoppedRoles : {};
  state.logs = Array.isArray(state.logs) ? state.logs : [];
  return state;
}

async function getState() {
  const stored = await chrome.storage.local.get(STATE_KEY);
  return mergeState(stored[STATE_KEY]);
}

async function saveState(state) {
  state.updatedAt = nowIso();
  await chrome.storage.local.set({ [STATE_KEY]: state });
}

function appendLog(state, entry) {
  state.logs.push(Object.assign({ at: nowIso(), duplicate: false }, entry));
  if (state.logs.length > 300) state.logs = state.logs.slice(-300);
}

function hydrateWorkers(state) {
  if (state.workers.length) return false;
  const workers = localWorkers();
  const validation = validateWorkers(workers);
  if (!validation.ok) {
    state.lastStatus = "Worker構成エラー: " + validation.error;
    return false;
  }
  state.workers = workers;
  state.lastStatus = "13 Worker構成済み。事前診断を実行してください。";
  return true;
}

async function initialize() {
  const state = await getState();
  hydrateWorkers(state);
  await saveState(state);
  if (state.enabled) await resume();
}

async function reportStartupError(error) {
  const state = await getState();
  state.lastStatus = "ERROR: " + String(error && error.message ? error.message : error);
  appendLog(state, { kind: "error", reason: state.lastStatus });
  await saveState(state);
}

async function lookupTab(worker) {
  if (worker.tabId) {
    try {
      const tab = await chrome.tabs.get(worker.tabId);
      if (tab && conversationId(tab.url || "") === worker.conversationId) return tab;
    } catch (_) {}
  }
  const tabs = await chrome.tabs.query({ url: ["https://chatgpt.com/*"] });
  return tabs.find((tab) => conversationId(tab.url || "") === worker.conversationId) || null;
}

async function keepTabLive(tabId) {
  try {
    await chrome.tabs.update(tabId, { autoDiscardable: false });
  } catch (_) {}
}

async function openOrFindWorkerTab(state, worker) {
  let tab = await lookupTab(worker);
  if (!tab) {
    tab = await chrome.tabs.create({ url: worker.conversationUrl, active: false });
  }
  worker.tabId = tab.id;
  await keepTabLive(tab.id);
  await saveState(state);
  return tab;
}

async function getWorkerState(tabId) {
  try {
    return await chrome.tabs.sendMessage(tabId, { type: "GET_STATE" });
  } catch (error) {
    return { ok: false, error: String(error && error.message ? error.message : error) };
  }
}

async function waitForWorkerReady(tab, worker) {
  const deadline = Date.now() + 30000;
  while (Date.now() < deadline) {
    try {
      const live = await chrome.tabs.get(tab.id);
      if (conversationId(live.url || "") !== worker.conversationId) {
        return { ok: false, reason: "conversation_url_changed" };
      }
    } catch (_) {
      return { ok: false, reason: "tab_closed" };
    }
    const state = await getWorkerState(tab.id);
    if (state && state.ok) return { ok: true, state };
    await sleep(500);
  }
  return { ok: false, reason: "content_script_timeout" };
}

function stateReason(state) {
  if (!state || !state.ok) return "state_unavailable";
  if (!state.composerFound) return "composer_missing";
  if (state.busy || state.stopButtonFound) return "busy";
  if (!state.idle) return "not_idle";
  return "";
}

async function preflight() {
  const state = await getState();
  hydrateWorkers(state);
  const validation = validateWorkers(state.workers);
  if (!validation.ok) {
    state.lastStatus = "事前診断FAIL: " + validation.error;
    await saveState(state);
    return { ok: false, error: validation.error, workers: [] };
  }

  const results = [];
  for (const worker of state.workers) {
    try {
      const tab = await openOrFindWorkerTab(state, worker);
      const ready = await waitForWorkerReady(tab, worker);
      const reason = ready.ok ? stateReason(ready.state) : ready.reason;
      results.push({
        id: worker.id,
        label: worker.label,
        role: worker.role,
        tabId: tab.id,
        ok: ready.ok && !reason,
        reason: reason || "ready"
      });
    } catch (error) {
      results.push({
        id: worker.id,
        label: worker.label,
        role: worker.role,
        tabId: worker.tabId,
        ok: false,
        reason: String(error && error.message ? error.message : error)
      });
    }
  }
  const passed = results.filter((result) => result.ok).length;
  state.lastStatus = "事前診断 " + passed + "/" + results.length + " ready";
  await saveState(state);
  return { ok: passed === results.length, workers: results, passed, total: results.length };
}

async function fetchQueue(queueUrl) {
  const separator = queueUrl.includes("?") ? "&" : "?";
  const response = await fetch(queueUrl + separator + "t=" + Date.now(), {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });
  if (!response.ok) throw new Error("Queue HTTP " + response.status);
  const queue = await response.json();
  if (!queue || !Array.isArray(queue.tasks)) throw new Error("Queue tasks missing");
  return queue;
}

function taskForRole(queue, role) {
  return (queue.tasks || []).find((task) => task.worker_role === role) || null;
}

function isStoppedByQueue(task) {
  return Boolean(task && (task.status === "HUMAN_REQUIRED" || task.human_gate === true));
}

function isDone(task) {
  return Boolean(task && ["DONE", "KILLED"].includes(task.status));
}

function compactTask(task) {
  return {
    id: task.id,
    title: task.title,
    worker_role: task.worker_role,
    prompt: task.prompt,
    evidence_path: task.evidence_path,
    human_gate: Boolean(task.human_gate)
  };
}

function taskPrompt(queue, task) {
  return [
    "【Dispatcher Task " + task.id + "】",
    "対象: " + String(queue.project || "アプリ開発②"),
    "GitHub: " + String(queue.repository || ""),
    "branch: " + String(queue.branch || ""),
    "Queue: " + String(queue.queue_path || ""),
    "Worker契約: " + String(queue.worker_bootstrap || ""),
    "",
    "この入力はChrome Dispatcherからの自動配車です。Codexは使わないでください。",
    "開始時にNotion/GitHub/App Store Connect/Codemagicの最新状態を再取得し、会話履歴を正本にしないでください。",
    "Worker契約とQueueを読み、今回のTaskだけを担当してください。人間判断が不要な範囲は質問せずMacro Loopで進めてください。",
    "Task完了時は証拠をGitHubへ保存し、Queueの自分のTaskだけを更新してremoteをread-backしてください。",
    "",
    "Task:",
    JSON.stringify(compactTask(task), null, 2)
  ].join("\n");
}

async function sendPrompt(tabId, prompt) {
  try {
    return await chrome.tabs.sendMessage(tabId, { type: "DISPATCH", prompt });
  } catch (error) {
    return { ok: false, error: String(error && error.message ? error.message : error) };
  }
}

function outcome(worker, result, reason) {
  return {
    session: worker.label,
    role: worker.role,
    result,
    reason: reason || "",
    duplicate: false
  };
}

async function recoverActiveRound(state) {
  if (!state.activeRound) return false;
  const round = Number(state.activeRound.round) || 0;
  if (round > state.runCount) {
    state.runCount = round;
    appendLog(state, {
      kind: "round",
      runCount: round,
      result: "RECOVERED",
      reason: "interrupted_round_finalized_without_resend"
    });
  }
  state.activeRound = null;
  state.lastStatus = "中断Roundを二重送信なしで確定";
  await saveState(state);
  return true;
}

async function runRound(trigger) {
  const state = await getState();
  hydrateWorkers(state);
  if (!state.enabled && trigger !== "start") return { ok: true, status: "disabled" };
  if (state.runCount >= RUN_LIMIT) return stop("run_limit_reached");

  if (state.activeRound) {
    await recoverActiveRound(state);
    return scheduleNext(state, "recovered");
  }

  const round = state.runCount + 1;
  state.activeRound = {
    round,
    trigger,
    startedAt: nowIso(),
    attemptedWorkerIds: [],
    outcomes: []
  };
  state.lastStatus = "Round " + round + " 実行中";
  await saveState(state);

  let queue = null;
  let queueError = "";
  try {
    queue = await fetchQueue(state.queueUrl);
    if (queue.paused) queueError = "queue_paused";
  } catch (error) {
    queueError = String(error && error.message ? error.message : error);
  }

  for (const worker of state.workers) {
    let result;
    if (state.activeRound.attemptedWorkerIds.includes(worker.id)) {
      result = outcome(worker, "SKIP", "duplicate_guard");
      result.duplicate = true;
    } else if (worker.stopped || state.stoppedRoles[worker.role]) {
      result = outcome(worker, "SKIP", worker.stoppedReason || state.stoppedRoles[worker.role] || "human_required");
    } else if (queueError) {
      result = outcome(worker, "SKIP", queueError);
    } else {
      const task = taskForRole(queue, worker.role);
      if (!task) {
        result = outcome(worker, "SKIP", "role_task_missing");
      } else if (isStoppedByQueue(task)) {
        worker.stopped = true;
        worker.stoppedReason = "HUMAN_REQUIRED";
        state.stoppedRoles[worker.role] = "HUMAN_REQUIRED";
        result = outcome(worker, "SKIP", "HUMAN_REQUIRED");
      } else if (isDone(task)) {
        result = outcome(worker, "SKIP", "task_done");
      } else {
        state.activeRound.attemptedWorkerIds.push(worker.id);
        await saveState(state);
        try {
          const tab = await openOrFindWorkerTab(state, worker);
          const ready = await waitForWorkerReady(tab, worker);
          const reason = ready.ok ? stateReason(ready.state) : ready.reason;
          if (reason) {
            result = outcome(worker, "SKIP", reason);
          } else {
            const prompt = round === 1 ? taskPrompt(queue, task) : "次";
            const sent = await sendPrompt(tab.id, prompt);
            if (sent && sent.ok && sent.confirmed) {
              result = outcome(worker, "SENT", round === 1 ? task.id : "次");
            } else {
              result = outcome(worker, "SKIP", "send_failed:" + String(sent && (sent.error || sent.reason) || "unknown"));
            }
          }
        } catch (error) {
          result = outcome(worker, "SKIP", "worker_error:" + String(error && error.message ? error.message : error));
        }
      }
    }
    state.activeRound.outcomes.push(result);
    appendLog(state, Object.assign({ kind: "worker", runCount: round }, result));
    await saveState(state);
  }

  const sentCount = state.activeRound.outcomes.filter((item) => item.result === "SENT").length;
  const skippedCount = state.activeRound.outcomes.length - sentCount;
  state.runCount = round;
  state.lastRound = {
    runCount: round,
    finishedAt: nowIso(),
    sent: sentCount,
    skipped: skippedCount,
    outcomes: state.activeRound.outcomes
  };
  appendLog(state, {
    kind: "round",
    runCount: round,
    result: "COMPLETE",
    reason: "sent=" + sentCount + " skipped=" + skippedCount
  });
  state.activeRound = null;
  state.lastStatus = "Round " + round + " 完了: sent=" + sentCount + " skip=" + skippedCount;
  await saveState(state);

  if (state.runCount >= RUN_LIMIT) return stop("run_limit_reached");
  return scheduleNext(state, "round_complete");
}

async function scheduleNext(state, reason) {
  if (!state.enabled || state.runCount >= RUN_LIMIT) return stop("run_limit_reached");
  const startedMs = new Date(state.startedAt || nowIso()).getTime();
  const plannedMs = startedMs + (state.runCount * INTERVAL_MS);
  const nextMs = plannedMs > Date.now() + 1000 ? plannedMs : Date.now() + INTERVAL_MS;
  state.nextRunAt = new Date(nextMs).toISOString();
  state.lastStatus = state.lastStatus + " / next=" + state.nextRunAt;
  await saveState(state);
  await chrome.alarms.clear(ALARM_NAME);
  await chrome.alarms.create(ALARM_NAME, { when: nextMs });
  return { ok: true, status: reason, runCount: state.runCount, nextRunAt: state.nextRunAt };
}

async function start() {
  const state = await getState();
  if (state.enabled && state.runCount < RUN_LIMIT) {
    return { ok: false, error: "already_enabled", runCount: state.runCount };
  }
  const diagnosis = await preflight();
  if (!diagnosis.ok) return { ok: false, error: "preflight_failed", diagnosis };
  const ready = await getState();
  ready.enabled = true;
  ready.runCount = 0;
  ready.startedAt = nowIso();
  ready.nextRunAt = ready.startedAt;
  ready.completedAt = null;
  ready.activeRound = null;
  ready.lastRound = null;
  ready.stoppedRoles = {};
  for (const worker of ready.workers) {
    worker.stopped = false;
    worker.stoppedReason = "";
  }
  appendLog(ready, { kind: "dispatcher", result: "START", reason: "40min_x_5" });
  ready.lastStatus = "開始: Round 1を実行";
  await saveState(ready);
  return runRound("start");
}

async function stop(reason) {
  const state = await getState();
  state.enabled = false;
  state.nextRunAt = null;
  if (state.runCount >= RUN_LIMIT && !state.completedAt) state.completedAt = nowIso();
  state.lastStatus = reason === "run_limit_reached" ? "run_count=5 到達。自動停止。" : "停止: " + reason;
  appendLog(state, { kind: "dispatcher", result: "STOP", reason });
  await saveState(state);
  await chrome.alarms.clear(ALARM_NAME);
  return { ok: true, status: state.lastStatus, runCount: state.runCount };
}

async function resume() {
  const state = await getState();
  hydrateWorkers(state);
  if (!state.enabled) {
    await saveState(state);
    return { ok: true, status: "disabled" };
  }
  if (state.runCount >= RUN_LIMIT) return stop("run_limit_reached");
  if (state.activeRound) return runRound("recovery");
  if (!state.nextRunAt || new Date(state.nextRunAt).getTime() <= Date.now()) return runRound("recovery");
  await saveState(state);
  await chrome.alarms.clear(ALARM_NAME);
  await chrome.alarms.create(ALARM_NAME, { when: new Date(state.nextRunAt).getTime() });
  return { ok: true, status: "scheduled", runCount: state.runCount, nextRunAt: state.nextRunAt };
}

async function publicStatus() {
  const state = await getState();
  hydrateWorkers(state);
  await saveState(state);
  return {
    ok: true,
    enabled: state.enabled,
    runCount: state.runCount,
    runLimit: state.runLimit,
    intervalMinutes: state.intervalMinutes,
    startedAt: state.startedAt,
    nextRunAt: state.nextRunAt,
    completedAt: state.completedAt,
    workerCount: state.workers.length,
    workers: state.workers.map((worker) => ({
      id: worker.id,
      label: worker.label,
      role: worker.role,
      tabId: worker.tabId,
      stopped: worker.stopped,
      stoppedReason: worker.stoppedReason
    })),
    lastRound: state.lastRound,
    lastStatus: state.lastStatus,
    logs: state.logs.slice(-80)
  };
}
