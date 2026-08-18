const DEFAULTS = {
  enabled: false,
  pollMinutes: 2,
  maxActive: 1,
  leaseMinutes: 90,
  queueUrl: "https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/learning-sprint-16-sagyo-dispatcher/automation/chatgpt-dispatcher/learning-sprint-16/queue.json",
  workerTabs: [],
  leases: {},
  lastStatus: "未開始",
  lastRunAt: null
};

const ALARM_NAME = "chatgpt-queue-dispatcher";

chrome.runtime.onInstalled.addListener(async () => {
  await ensureDefaults();
  await ensureAlarm();
});

chrome.runtime.onStartup.addListener(async () => {
  await ensureDefaults();
  await ensureAlarm();
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === ALARM_NAME) {
    await dispatchOnce("alarm");
  }
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    if (message?.type === "DISPATCH_NOW") {
      await dispatchOnce("manual");
      sendResponse({ ok: true });
      return;
    }
    if (message?.type === "CONFIG_CHANGED" || message?.type === "SETTINGS_CHANGED") {
      await ensureAlarm();
      sendResponse({ ok: true });
      return;
    }
    if (message?.type === "CLEAR_LEASES") {
      await chrome.storage.local.set({ leases: {}, lastStatus: "leaseを解除しました" });
      sendResponse({ ok: true });
      return;
    }
    sendResponse({ ok: false, error: "unknown message" });
  })().catch((error) => sendResponse({ ok: false, error: String(error) }));
  return true;
});

async function ensureDefaults() {
  const current = await chrome.storage.local.get(Object.keys(DEFAULTS));
  const patch = {};
  for (const [key, value] of Object.entries(DEFAULTS)) {
    if (current[key] === undefined) patch[key] = value;
  }
  if (Object.keys(patch).length) await chrome.storage.local.set(patch);
}

async function ensureAlarm() {
  const { pollMinutes = DEFAULTS.pollMinutes } = await chrome.storage.local.get("pollMinutes");
  const periodInMinutes = Math.max(1, Number(pollMinutes) || DEFAULTS.pollMinutes);
  const existing = await chrome.alarms.get(ALARM_NAME);
  if (!existing || existing.periodInMinutes !== periodInMinutes) {
    if (existing) await chrome.alarms.clear(ALARM_NAME);
    await chrome.alarms.create(ALARM_NAME, { delayInMinutes: 0.1, periodInMinutes });
  }
}

function nowIso() {
  return new Date().toISOString();
}

function isLeaseActive(lease, leaseMinutes) {
  if (!lease?.startedAt) return false;
  const ageMs = Date.now() - new Date(lease.startedAt).getTime();
  return Number.isFinite(ageMs) && ageMs >= 0 && ageMs < leaseMinutes * 60_000;
}

function taskMap(tasks) {
  return new Map(tasks.map((task) => [task.id, task]));
}

function dependenciesDone(task, byId) {
  return (task.depends_on || []).every((id) => byId.get(id)?.status === "DONE");
}

function chooseTask(queue, leases, leaseMinutes) {
  const tasks = Array.isArray(queue.tasks) ? queue.tasks : [];
  const byId = taskMap(tasks);
  return tasks.find((task) => {
    if (task.status !== "READY") return false;
    if (!dependenciesDone(task, byId)) return false;
    if (isLeaseActive(leases[task.id], leaseMinutes)) return false;
    return true;
  }) || null;
}

async function fetchQueue(queueUrl) {
  const separator = queueUrl.includes("?") ? "&" : "?";
  const response = await fetch(`${queueUrl}${separator}t=${Date.now()}`, {
    cache: "no-store",
    headers: { Accept: "application/json" }
  });
  if (!response.ok) throw new Error(`Queue HTTP ${response.status}`);
  return response.json();
}

async function getWorkerState(tabId) {
  try {
    return await chrome.tabs.sendMessage(tabId, { type: "GET_STATE" });
  } catch (error) {
    return { ok: false, idle: false, error: String(error) };
  }
}

function roleMatches(workerRole, taskRole) {
  return !taskRole || workerRole === "ANY" || workerRole === taskRole;
}

async function chooseWorker(workerTabs, task, activeTabIds) {
  for (const worker of workerTabs) {
    if (!worker?.tabId || activeTabIds.has(worker.tabId)) continue;
    if (!roleMatches(worker.role || "ANY", task.worker_role)) continue;

    let tab;
    try {
      tab = await chrome.tabs.get(worker.tabId);
    } catch {
      continue;
    }
    if (!tab?.url?.startsWith("https://chatgpt.com/")) continue;

    const state = await getWorkerState(worker.tabId);
    if (state?.ok && state.idle) {
      return { ...worker, state };
    }
  }
  return null;
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

function buildPrompt(queue, task) {
  const project = queue.project || "学びスプリント";
  const repo = queue.repository;
  const branch = queue.branch;
  const queuePath = queue.queue_path;
  const bootstrap = queue.worker_bootstrap;

  return [
    `【Dispatcher Task ${task.id}】`,
    `対象: ${project}`,
    `GitHub: ${repo}`,
    `branch: ${branch}`,
    `Queue: ${queuePath}`,
    `Worker契約: ${bootstrap}`,
    "",
    "この入力はChrome Dispatcherからの自動配車です。Codexは使わないでください。",
    "開始時にNotion/GitHub/branchの最新状態を再取得し、会話履歴を正本にしないでください。",
    "Worker契約とQueueを読み、今回のTaskだけを担当してください。人間判断が不要な範囲は質問せずMacro Loopで進めてください。",
    "実装を伴う場合はローカルGitで作業し、標準手順のcheckpointルールに従ってGitHubへ保存してください。",
    "Task完了時は証拠をGitHubへ保存し、Queueの自分のTaskだけを READY から DONE に更新して completed_at を入れ、remoteをread-backしてください。",
    "HUMAN_REQUIREDへ到達した場合はTaskをHUMAN_REQUIREDにし、Queueのpausedをtrueにしてください。",
    "",
    "Task:",
    JSON.stringify(compactTask(task), null, 2)
  ].join("\n");
}

async function markLocalLease(task, worker, leases) {
  const next = { ...leases };
  next[task.id] = {
    taskId: task.id,
    tabId: worker.tabId,
    workerLabel: worker.label || String(worker.tabId),
    startedAt: nowIso()
  };
  await chrome.storage.local.set({ leases: next });
  return next;
}

async function releaseLease(taskId) {
  const { leases = {} } = await chrome.storage.local.get("leases");
  const next = { ...leases };
  delete next[taskId];
  await chrome.storage.local.set({ leases: next });
}

async function cleanLeases(queue, leases, leaseMinutes) {
  const tasks = taskMap(Array.isArray(queue.tasks) ? queue.tasks : []);
  const next = {};
  let changed = false;
  for (const [taskId, lease] of Object.entries(leases || {})) {
    const task = tasks.get(taskId);
    if (task?.status === "READY" && isLeaseActive(lease, leaseMinutes)) {
      next[taskId] = lease;
    } else {
      changed = true;
    }
  }
  if (changed) await chrome.storage.local.set({ leases: next });
  return next;
}

async function sendTask(worker, prompt) {
  const result = await chrome.tabs.sendMessage(worker.tabId, {
    type: "DISPATCH",
    prompt
  });
  if (!result?.ok) throw new Error(result?.error || "ChatGPTへの送信に失敗");
  return result;
}

async function dispatchOnce(trigger) {
  await ensureDefaults();
  const cfg = await chrome.storage.local.get([
    "enabled", "queueUrl", "workerTabs", "leases", "maxActive", "leaseMinutes"
  ]);

  const stamp = nowIso();
  if (!cfg.enabled && trigger !== "manual") {
    await chrome.storage.local.set({ lastRunAt: stamp, lastStatus: "無効: 自動配車OFF" });
    return;
  }

  if (!cfg.queueUrl) {
    await chrome.storage.local.set({ lastRunAt: stamp, lastStatus: "Queue URL未設定" });
    return;
  }

  try {
    const queue = await fetchQueue(cfg.queueUrl);
    if (queue.paused) {
      await chrome.storage.local.set({ lastRunAt: stamp, lastStatus: "Queue paused" });
      return;
    }

    const leaseMinutes = Math.max(5, Number(cfg.leaseMinutes) || DEFAULTS.leaseMinutes);
    const leases = await cleanLeases(queue, cfg.leases || {}, leaseMinutes);
    const activeLeases = Object.values(leases).filter((lease) => isLeaseActive(lease, leaseMinutes));
    const maxActive = Math.max(1, Number(cfg.maxActive) || 1);

    if (activeLeases.length >= maxActive) {
      await chrome.storage.local.set({
        lastRunAt: stamp,
        lastStatus: `待機: ACTIVE ${activeLeases.length}/${maxActive}`
      });
      return;
    }

    const task = chooseTask(queue, leases, leaseMinutes);
    if (!task) {
      const unfinished = (queue.tasks || []).filter((t) => !["DONE", "KILLED"].includes(t.status));
      await chrome.storage.local.set({
        lastRunAt: stamp,
        lastStatus: unfinished.length ? "依存待ち/実行可能Taskなし" : "全Task完了"
      });
      return;
    }

    const activeTabIds = new Set(activeLeases.map((lease) => lease.tabId));
    const worker = await chooseWorker(cfg.workerTabs || [], task, activeTabIds);
    if (!worker) {
      await chrome.storage.local.set({
        lastRunAt: stamp,
        lastStatus: `待機: ${task.id}を受け取れる空きWorkerなし`
      });
      return;
    }

    const nextLeases = await markLocalLease(task, worker, leases);
    try {
      await sendTask(worker, buildPrompt(queue, task));
    } catch (error) {
      await releaseLease(task.id);
      throw error;
    }

    await chrome.storage.local.set({
      leases: nextLeases,
      lastRunAt: stamp,
      lastStatus: `配車済み: ${task.id} → ${worker.label || worker.tabId}`
    });
  } catch (error) {
    await chrome.storage.local.set({
      lastRunAt: stamp,
      lastStatus: `ERROR: ${String(error?.message || error)}`
    });
  }
}
