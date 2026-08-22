try {
  importScripts('portfolio-workers.local.js');
} catch (_) {
  self.PORTFOLIO_WORKERS = [];
  self.PORTFOLIO_AUTOSTART = false;
}

const STATE_KEY = 'ai_dev_portfolio_dispatcher_v2';
const ALARM_NAME = 'ai_dev_portfolio_dispatcher_tick';
const DEFAULT_PORTFOLIO_URL = 'https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/refs/heads/automation/ai-dev-operating-system/automation/ai-dev-operating-system/portfolio.json';
const DEFAULT_INTERVAL_MINUTES = 2;
const SESSION_RUN_LIMIT = 3;
const MAX_LOGS = 300;

const GOVERNOR = {
  memoryWarnPct: 70,
  memoryThrottlePct: 80,
  memoryStopPct: 90,
  cpuWarnPct: 75,
  cpuThrottlePct: 85,
  cpuStopPct: 95,
  maxActiveGreen: 3,
  maxActiveWarn: 2,
  maxActiveThrottle: 1,
  maxHeavyIo: 1,
  chatgptTabsWarn: 12,
  chatgptTabsThrottle: 20,
  recentFailureWindow: 20,
  recentFailureThrottleRate: 0.30
};

chrome.runtime.onInstalled.addListener(() => initialize().catch(recordFatal));
chrome.runtime.onStartup.addListener(() => resume().catch(recordFatal));
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_NAME) tick('alarm').catch(recordFatal);
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  (async () => {
    switch (message && message.type) {
      case 'PORTFOLIO_STATUS': sendResponse(await publicStatus()); return;
      case 'PORTFOLIO_START': sendResponse(await start()); return;
      case 'PORTFOLIO_STOP': sendResponse(await stop('operator_stop')); return;
      case 'PORTFOLIO_TICK': sendResponse(await tick('manual')); return;
      case 'PORTFOLIO_PREFLIGHT': sendResponse(await preflight()); return;
      default: sendResponse({ ok: false, error: 'unknown_message' });
    }
  })().catch((error) => sendResponse({ ok: false, error: errorText(error) }));
  return true;
});

function nowIso() { return new Date().toISOString(); }
function errorText(error) { return String(error && error.message ? error.message : error); }
function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function conversationId(url) {
  try {
    const match = new URL(url).pathname.match(/\/c\/([^/?#]+)/);
    return match ? match[1] : '';
  } catch (_) { return ''; }
}

function normalizeWorker(raw) {
  const conversationUrl = String(raw && raw.conversationUrl || '').trim();
  return {
    id: String(raw && raw.id || '').trim(),
    projectId: String(raw && raw.projectId || '').trim(),
    role: String(raw && raw.role || '').trim(),
    label: String(raw && raw.label || '').trim(),
    conversationUrl,
    conversationId: conversationId(conversationUrl),
    tabId: Number.isInteger(raw && raw.tabId) ? raw.tabId : null,
    currentTaskId: String(raw && raw.currentTaskId || ''),
    taskRunCount: Number(raw && raw.taskRunCount || 0),
    runLimit: Number(raw && raw.runLimit || SESSION_RUN_LIMIT),
    status: String(raw && raw.status || 'READY'),
    heavyIo: Boolean(raw && raw.heavyIo),
    lastDispatchAt: raw && raw.lastDispatchAt || null,
    lastResult: String(raw && raw.lastResult || '')
  };
}

function freshState() {
  return {
    version: 2,
    enabled: false,
    portfolioUrl: DEFAULT_PORTFOLIO_URL,
    intervalMinutes: DEFAULT_INTERVAL_MINUTES,
    workers: [],
    lastCpuSample: null,
    lastGovernor: null,
    lastTick: null,
    activeTick: false,
    logs: [],
    updatedAt: nowIso()
  };
}

function mergeState(raw) {
  const state = Object.assign(freshState(), raw && typeof raw === 'object' ? raw : {});
  state.workers = Array.isArray(state.workers) ? state.workers.map(normalizeWorker) : [];
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
  state.logs.push(Object.assign({ at: nowIso() }, entry));
  if (state.logs.length > MAX_LOGS) state.logs = state.logs.slice(-MAX_LOGS);
}

function localWorkers() {
  return (Array.isArray(self.PORTFOLIO_WORKERS) ? self.PORTFOLIO_WORKERS : []).map(normalizeWorker);
}
function hydrateWorkers(state) {
  if (state.workers.length) return;
  state.workers = localWorkers();
}

async function initialize() {
  const state = await getState();
  hydrateWorkers(state);
  await saveState(state);
  if (self.PORTFOLIO_AUTOSTART || state.enabled) await start();
}

async function recordFatal(error) {
  const state = await getState();
  appendLog(state, { kind: 'fatal', error: errorText(error) });
  state.lastTick = { at: nowIso(), ok: false, error: errorText(error) };
  state.activeTick = false;
  await saveState(state);
}

async function fetchJson(url) {
  const separator = url.includes('?') ? '&' : '?';
  const response = await fetch(url + separator + 't=' + Date.now(), {
    cache: 'no-store', headers: { Accept: 'application/json' }
  });
  if (!response.ok) throw new Error('HTTP ' + response.status + ' ' + url);
  return await response.json();
}

async function getResourceSnapshot(state) {
  const memory = await chrome.system.memory.getInfo();
  const memoryUsedPct = memory.capacity > 0
    ? ((memory.capacity - memory.availableCapacity) / memory.capacity) * 100
    : 0;

  let cpuUsedPct = 0;
  const cpu = await chrome.system.cpu.getInfo();
  const current = cpu.processors.map((processor) => ({
    total: Number(processor.usage.total || 0),
    idle: Number(processor.usage.idle || 0)
  }));
  if (state.lastCpuSample && Array.isArray(state.lastCpuSample.processors) && state.lastCpuSample.processors.length === current.length) {
    let totalDelta = 0;
    let idleDelta = 0;
    for (let i = 0; i < current.length; i += 1) {
      totalDelta += Math.max(0, current[i].total - state.lastCpuSample.processors[i].total);
      idleDelta += Math.max(0, current[i].idle - state.lastCpuSample.processors[i].idle);
    }
    if (totalDelta > 0) cpuUsedPct = clamp(((totalDelta - idleDelta) / totalDelta) * 100, 0, 100);
  }
  state.lastCpuSample = { at: nowIso(), processors: current };

  const chatgptTabs = await chrome.tabs.query({ url: ['https://chatgpt.com/*'] });
  return {
    at: nowIso(),
    memoryUsedPct: Math.round(memoryUsedPct * 10) / 10,
    memoryAvailableBytes: memory.availableCapacity,
    memoryCapacityBytes: memory.capacity,
    cpuUsedPct: Math.round(cpuUsedPct * 10) / 10,
    logicalProcessors: cpu.numOfProcessors,
    chatgptTabCount: chatgptTabs.length
  };
}

function recentDispatchFailureRate(state) {
  const dispatches = state.logs.filter((item) => item.kind === 'dispatch').slice(-GOVERNOR.recentFailureWindow);
  if (!dispatches.length) return 0;
  return dispatches.filter((item) => item.result !== 'SENT').length / dispatches.length;
}

function governorDecision(state, snapshot) {
  let maxActive = GOVERNOR.maxActiveGreen;
  let mode = 'GREEN';
  const reasons = [];

  if (snapshot.memoryUsedPct >= GOVERNOR.memoryStopPct || snapshot.cpuUsedPct >= GOVERNOR.cpuStopPct) {
    maxActive = 0; mode = 'STOP'; reasons.push('resource_stop_threshold');
  } else if (snapshot.memoryUsedPct >= GOVERNOR.memoryThrottlePct || snapshot.cpuUsedPct >= GOVERNOR.cpuThrottlePct) {
    maxActive = GOVERNOR.maxActiveThrottle; mode = 'THROTTLE'; reasons.push('resource_throttle_threshold');
  } else if (snapshot.memoryUsedPct >= GOVERNOR.memoryWarnPct || snapshot.cpuUsedPct >= GOVERNOR.cpuWarnPct) {
    maxActive = GOVERNOR.maxActiveWarn; mode = 'WARN'; reasons.push('resource_warn_threshold');
  }

  if (snapshot.chatgptTabCount > GOVERNOR.chatgptTabsThrottle) {
    maxActive = Math.min(maxActive, 1); mode = mode === 'STOP' ? mode : 'THROTTLE'; reasons.push('too_many_chatgpt_tabs');
  } else if (snapshot.chatgptTabCount > GOVERNOR.chatgptTabsWarn) {
    maxActive = Math.min(maxActive, 2); if (mode === 'GREEN') mode = 'WARN'; reasons.push('chatgpt_tab_pressure');
  }

  const failureRate = recentDispatchFailureRate(state);
  if (failureRate >= GOVERNOR.recentFailureThrottleRate) {
    maxActive = Math.max(0, maxActive - 1);
    if (mode === 'GREEN') mode = 'WARN';
    reasons.push('dispatch_failure_rate');
  }

  return {
    at: nowIso(), mode, maxActive,
    maxHeavyIo: GOVERNOR.maxHeavyIo,
    recentDispatchFailureRate: Math.round(failureRate * 1000) / 1000,
    reasons,
    snapshot
  };
}

async function lookupTab(worker) {
  if (worker.tabId) {
    try {
      const tab = await chrome.tabs.get(worker.tabId);
      if (conversationId(tab.url || '') === worker.conversationId) return tab;
    } catch (_) {}
  }
  const tabs = await chrome.tabs.query({ url: ['https://chatgpt.com/*'] });
  return tabs.find((tab) => conversationId(tab.url || '') === worker.conversationId) || null;
}

async function openOrFindWorkerTab(state, worker) {
  let tab = await lookupTab(worker);
  if (!tab) tab = await chrome.tabs.create({ url: worker.conversationUrl, active: false });
  worker.tabId = tab.id;
  try { await chrome.tabs.update(tab.id, { autoDiscardable: false }); } catch (_) {}
  await saveState(state);
  return tab;
}

async function workerUiState(worker) {
  const tab = await lookupTab(worker);
  if (!tab) return { ok: false, idle: false, reason: 'tab_missing' };
  try {
    const result = await chrome.tabs.sendMessage(tab.id, { type: 'GET_STATE' });
    return Object.assign({ tabId: tab.id }, result || {});
  } catch (error) {
    return { ok: false, idle: false, reason: errorText(error), tabId: tab.id };
  }
}

function queueUrlOf(project) {
  const value = String(project && project.queue_locator || '');
  return /^https:\/\//.test(value) ? value : '';
}

function priorityRank(value) {
  return ({ critical: 0, high: 1, medium: 2, low: 3 })[String(value || '').toLowerCase()] ?? 4;
}

function eligibleTasks(project, queue) {
  return (queue.tasks || [])
    .filter((task) => task && ['READY', 'CLAIMED', 'WORKING'].includes(String(task.status || '').toUpperCase()) && task.human_gate !== true)
    .map((task) => ({ project, queue, task }))
    .sort((a, b) => priorityRank(a.task.priority || project.priority) - priorityRank(b.task.priority || project.priority));
}

function taskForWorker(workItems, worker) {
  return workItems.find((item) => {
    if (item.project.project_id !== worker.projectId) return false;
    if (item.task.worker_role && item.task.worker_role !== worker.role) return false;
    const status = String(item.task.status || '').toUpperCase();
    const claimedBy = String(item.task.claimed_by || item.task.claimedBy || '');
    if (status !== 'READY' && claimedBy && claimedBy !== worker.id) return false;
    return true;
  }) || null;
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

function initialPrompt(item) {
  const { project, queue, task } = item;
  return [
    '【Portfolio Dispatcher Task ' + task.id + '】',
    'project_id: ' + project.project_id,
    '対象: ' + String(queue.project || project.project_id),
    'GitHub: ' + String(queue.repository || ''),
    'branch: ' + String(queue.branch || ''),
    'Queue: ' + String(queue.queue_path || project.queue_locator || ''),
    'Worker契約: ' + String(queue.worker_bootstrap || ''),
    '',
    'この入力はLocal Portfolio Dispatcherからの自動配車です。通常経路でCodexを使用しないでください。',
    '開始時にNotion/GitHub/外部サービスの最新実状態を再取得し、会話履歴を正本にしないでください。',
    '今回のTaskを1 Macro Wave進め、実装・検証・証拠保存・Queue更新まで行ってください。',
    '人間判断不要な範囲で質問せず進めてください。Task完了だけを理由に人間へ確認を求めないでください。',
    '',
    'Task:',
    JSON.stringify(compactTask(task), null, 2)
  ].join('\n');
}

async function sendPrompt(tabId, prompt) {
  try { return await chrome.tabs.sendMessage(tabId, { type: 'DISPATCH', prompt }); }
  catch (error) { return { ok: false, error: errorText(error) }; }
}

async function dispatchItem(state, worker, item) {
  if (worker.currentTaskId && worker.currentTaskId !== item.task.id) {
    worker.taskRunCount = 0;
  }
  worker.currentTaskId = item.task.id;

  if (worker.taskRunCount >= worker.runLimit) {
    worker.status = 'ROTATE';
    worker.lastResult = 'session_run_limit_reached';
    appendLog(state, { kind: 'rotate', workerId: worker.id, taskId: item.task.id, result: 'ROTATE' });
    return { sent: false, reason: 'rotate_required' };
  }

  const tab = await openOrFindWorkerTab(state, worker);
  const ui = await workerUiState(worker);
  if (!ui.ok || !ui.composerFound || ui.busy || !ui.idle) {
    appendLog(state, { kind: 'dispatch', workerId: worker.id, taskId: item.task.id, result: 'SKIP', reason: ui.reason || (ui.busy ? 'busy' : 'not_ready') });
    return { sent: false, reason: ui.reason || 'worker_not_idle' };
  }

  const prompt = worker.taskRunCount === 0 ? initialPrompt(item) : '次';
  const result = await sendPrompt(tab.id, prompt);
  if (!result || !result.ok) {
    worker.lastResult = 'dispatch_failed:' + String(result && result.error || 'unknown');
    appendLog(state, { kind: 'dispatch', workerId: worker.id, taskId: item.task.id, result: 'FAIL', reason: worker.lastResult });
    return { sent: false, reason: worker.lastResult };
  }

  worker.taskRunCount += 1;
  worker.lastDispatchAt = nowIso();
  worker.lastResult = prompt === '次' ? 'next_sent' : 'task_sent';
  worker.status = worker.taskRunCount >= worker.runLimit ? 'ROTATE_AFTER_RESPONSE' : 'WORKING';
  appendLog(state, { kind: 'dispatch', workerId: worker.id, taskId: item.task.id, result: 'SENT', wave: worker.taskRunCount, promptType: prompt === '次' ? 'NEXT' : 'TASK' });
  return { sent: true, promptType: prompt === '次' ? 'NEXT' : 'TASK' };
}

async function loadWorkItems(portfolio) {
  const projects = (portfolio.project_registry || [])
    .filter((project) => !['PAUSED', 'DONE', 'CANCELLED'].includes(String(project.status || '').toUpperCase()))
    .filter((project) => queueUrlOf(project));
  const work = [];
  for (const project of projects.sort((a, b) => priorityRank(a.priority) - priorityRank(b.priority))) {
    try {
      const queue = await fetchJson(queueUrlOf(project));
      if (!queue.paused && Array.isArray(queue.tasks)) work.push(...eligibleTasks(project, queue));
    } catch (_) {}
  }
  return work;
}

async function tick(trigger) {
  const state = await getState();
  hydrateWorkers(state);
  if (!state.enabled && trigger !== 'manual') return { ok: true, status: 'disabled' };
  if (state.activeTick) return { ok: true, status: 'tick_already_active' };
  state.activeTick = true;
  await saveState(state);

  try {
    const snapshot = await getResourceSnapshot(state);
    const governor = governorDecision(state, snapshot);
    state.lastGovernor = governor;

    if (governor.maxActive <= 0) {
      state.lastTick = { at: nowIso(), ok: true, trigger, dispatched: 0, reason: 'governor_stop' };
      appendLog(state, { kind: 'governor', result: 'STOP', reasons: governor.reasons });
      return { ok: true, governor, dispatched: 0 };
    }

    const portfolio = await fetchJson(state.portfolioUrl);
    const workItems = await loadWorkItems(portfolio);

    let busyCount = 0;
    let heavyActive = 0;
    for (const worker of state.workers) {
      if (worker.status === 'ROTATE' || worker.status === 'ROTATE_AFTER_RESPONSE') continue;
      const ui = await workerUiState(worker);
      if (ui && ui.ok && (ui.busy || !ui.idle)) {
        busyCount += 1;
        if (worker.heavyIo) heavyActive += 1;
      }
    }

    const availableSlots = Math.max(0, governor.maxActive - busyCount);
    let dispatched = 0;
    for (const worker of state.workers) {
      if (dispatched >= availableSlots) break;
      if (worker.status === 'ROTATE' || worker.status === 'ROTATE_AFTER_RESPONSE') continue;
      const item = taskForWorker(workItems, worker);
      if (!item) continue;
      if (worker.heavyIo && heavyActive >= governor.maxHeavyIo) continue;

      const result = await dispatchItem(state, worker, item);
      if (result.sent) {
        dispatched += 1;
        if (worker.heavyIo) heavyActive += 1;
      }
      await saveState(state);
    }

    state.lastTick = { at: nowIso(), ok: true, trigger, dispatched, busyCount, availableSlots, readyTasks: workItems.length };
    appendLog(state, { kind: 'tick', result: 'DONE', trigger, dispatched, busyCount, availableSlots, readyTasks: workItems.length, governorMode: governor.mode });
    return { ok: true, governor, dispatched, busyCount, availableSlots, readyTasks: workItems.length };
  } catch (error) {
    state.lastTick = { at: nowIso(), ok: false, trigger, error: errorText(error) };
    appendLog(state, { kind: 'tick', result: 'FAIL', trigger, error: errorText(error) });
    return { ok: false, error: errorText(error) };
  } finally {
    state.activeTick = false;
    await saveState(state);
  }
}

async function preflight() {
  const state = await getState();
  hydrateWorkers(state);
  const snapshot = await getResourceSnapshot(state);
  const governor = governorDecision(state, snapshot);
  const workers = [];
  for (const worker of state.workers) {
    const ui = await workerUiState(worker);
    workers.push({ id: worker.id, projectId: worker.projectId, role: worker.role, label: worker.label, status: worker.status, taskRunCount: worker.taskRunCount, runLimit: worker.runLimit, ui });
  }
  state.lastGovernor = governor;
  await saveState(state);
  return { ok: true, governor, workers };
}

async function schedule(state) {
  await chrome.alarms.clear(ALARM_NAME);
  if (!state.enabled) return;
  await chrome.alarms.create(ALARM_NAME, { periodInMinutes: Math.max(1, Number(state.intervalMinutes || DEFAULT_INTERVAL_MINUTES)) });
}

async function start() {
  const state = await getState();
  hydrateWorkers(state);
  state.enabled = true;
  await schedule(state);
  await saveState(state);
  return await tick('start');
}

async function stop(reason) {
  const state = await getState();
  state.enabled = false;
  state.activeTick = false;
  appendLog(state, { kind: 'lifecycle', result: 'STOP', reason });
  await chrome.alarms.clear(ALARM_NAME);
  await saveState(state);
  return { ok: true, reason };
}

async function resume() {
  const state = await getState();
  hydrateWorkers(state);
  if (state.enabled || self.PORTFOLIO_AUTOSTART) {
    state.enabled = true;
    await schedule(state);
  }
  await saveState(state);
  return { ok: true, enabled: state.enabled };
}

async function publicStatus() {
  const state = await getState();
  return {
    ok: true,
    enabled: state.enabled,
    intervalMinutes: state.intervalMinutes,
    workerCount: state.workers.length,
    workers: state.workers.map((worker) => ({
      id: worker.id, projectId: worker.projectId, role: worker.role, label: worker.label,
      status: worker.status, currentTaskId: worker.currentTaskId, taskRunCount: worker.taskRunCount,
      runLimit: worker.runLimit, lastDispatchAt: worker.lastDispatchAt, lastResult: worker.lastResult
    })),
    lastGovernor: state.lastGovernor,
    lastTick: state.lastTick,
    logs: state.logs.slice(-30),
    updatedAt: state.updatedAt
  };
}
