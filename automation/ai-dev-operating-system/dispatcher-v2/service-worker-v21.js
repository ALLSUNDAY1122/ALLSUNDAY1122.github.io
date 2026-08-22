try {
  importScripts('portfolio-workers.local.js');
} catch (_) {
  self.PORTFOLIO_WORKERS = [];
  self.PORTFOLIO_AUTOSTART = false;
}

const STATE_KEY = 'ai_dev_portfolio_dispatcher_v21';
const ALARM_NAME = 'ai_dev_portfolio_dispatcher_tick';
const DEFAULT_PORTFOLIO_URL = 'https://raw.githubusercontent.com/ALLSUNDAY1122/ALLSUNDAY1122.github.io/refs/heads/automation/ai-dev-operating-system/automation/ai-dev-operating-system/portfolio.json';
const DEFAULT_INTERVAL_MINUTES = 2;
const SESSION_RUN_LIMIT = 3;
const MAX_LOGS = 400;

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
      case 'PORTFOLIO_REGISTER_ACTIVE': sendResponse(await registerActiveTab(message.worker || {})); return;
      case 'PORTFOLIO_REMOVE_WORKER': sendResponse(await removeWorker(String(message.workerId || ''))); return;
      case 'PORTFOLIO_RESET_ROTATION': sendResponse(await resetRotation(String(message.workerId || ''))); return;
      default: sendResponse({ ok: false, error: 'unknown_message' });
    }
  })().catch((error) => sendResponse({ ok: false, error: errorText(error) }));
  return true;
});

function nowIso() { return new Date().toISOString(); }
function errorText(error) { return String(error && error.message ? error.message : error); }
function clamp(value, min, max) { return Math.max(min, Math.min(max, value)); }
function sleep(ms) { return new Promise((resolve) => setTimeout(resolve, ms)); }
function conversationId(url) {
  try {
    const match = new URL(url).pathname.match(/\/c\/([^/?#]+)/);
    return match ? match[1] : '';
  } catch (_) { return ''; }
}
function taskId(task) {
  return String(task && (task.task_id || task.id) || '').trim();
}
function priorityValue(task, project) {
  const raw = task && task.priority !== undefined ? task.priority : project && project.priority;
  if (typeof raw === 'number') return -raw;
  const rank = { critical: 0, high: 1, medium: 2, low: 3 };
  return rank[String(raw || '').toLowerCase()] ?? 4;
}
function isHumanStatus(status) {
  return ['HUMAN_REQUIRED', 'BLOCKED_HUMAN'].includes(String(status || '').toUpperCase());
}

function normalizeWorker(raw) {
  const conversationUrl = String(raw && raw.conversationUrl || '').trim();
  const id = String(raw && raw.id || '').trim();
  return {
    id,
    projectId: String(raw && raw.projectId || '').trim(),
    role: String(raw && raw.role || '').trim(),
    remoteWorkerId: String(raw && raw.remoteWorkerId || raw && raw.role || '').trim(),
    laneId: String(raw && raw.laneId || '').trim(),
    label: String(raw && raw.label || '').trim(),
    conversationUrl,
    conversationId: conversationId(conversationUrl),
    tabId: Number.isInteger(raw && raw.tabId) ? raw.tabId : null,
    sessionWaveCount: Number(raw && raw.sessionWaveCount || 0),
    runLimit: Number(raw && raw.runLimit || SESSION_RUN_LIMIT),
    status: String(raw && raw.status || 'READY'),
    heavyIo: Boolean(raw && raw.heavyIo),
    lastDispatchAt: raw && raw.lastDispatchAt || null,
    lastResult: String(raw && raw.lastResult || ''),
    lastUnitKey: String(raw && raw.lastUnitKey || '')
  };
}

function freshState() {
  return {
    version: '2.1',
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
    cache: 'no-store',
    headers: { Accept: 'application/json' }
  });
  if (!response.ok) throw new Error('HTTP ' + response.status + ' ' + url);
  return await response.json();
}

async function cpuInfo() {
  const info = await chrome.system.cpu.getInfo();
  return {
    processors: info.processors.map((processor) => ({
      total: Number(processor.usage.total || 0),
      idle: Number(processor.usage.idle || 0)
    })),
    numOfProcessors: info.numOfProcessors
  };
}
function cpuDeltaPct(before, after) {
  if (!before || !after || before.processors.length !== after.processors.length) return 0;
  let totalDelta = 0;
  let idleDelta = 0;
  for (let i = 0; i < after.processors.length; i += 1) {
    totalDelta += Math.max(0, after.processors[i].total - before.processors[i].total);
    idleDelta += Math.max(0, after.processors[i].idle - before.processors[i].idle);
  }
  return totalDelta > 0 ? clamp(((totalDelta - idleDelta) / totalDelta) * 100, 0, 100) : 0;
}
async function getResourceSnapshot(state) {
  const memory = await chrome.system.memory.getInfo();
  const memoryUsedPct = memory.capacity > 0
    ? ((memory.capacity - memory.availableCapacity) / memory.capacity) * 100
    : 0;

  const first = await cpuInfo();
  let before = state.lastCpuSample;
  if (!before || !Array.isArray(before.processors) || before.processors.length !== first.processors.length) {
    await sleep(500);
    before = first;
  }
  const second = before === first ? await cpuInfo() : first;
  const cpuUsedPct = cpuDeltaPct(before, second);
  state.lastCpuSample = { at: nowIso(), processors: second.processors };

  const chatgptTabs = await chrome.tabs.query({ url: ['https://chatgpt.com/*'] });
  return {
    at: nowIso(),
    memoryUsedPct: Math.round(memoryUsedPct * 10) / 10,
    memoryAvailableBytes: memory.availableCapacity,
    memoryCapacityBytes: memory.capacity,
    cpuUsedPct: Math.round(cpuUsedPct * 10) / 10,
    logicalProcessors: second.numOfProcessors,
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
    at: nowIso(), mode, maxActive, maxHeavyIo: GOVERNOR.maxHeavyIo,
    recentDispatchFailureRate: Math.round(failureRate * 1000) / 1000,
    reasons, snapshot
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
async function sendPrompt(tabId, prompt) {
  try { return await chrome.tabs.sendMessage(tabId, { type: 'DISPATCH', prompt }); }
  catch (error) { return { ok: false, error: errorText(error) }; }
}

function queueUrlOf(project) {
  const value = String(project && project.queue_locator || '');
  return /^https:\/\//.test(value) ? value : '';
}
function workUrlOf(project) {
  const value = String(project && (project.work_locator || project.queue_locator) || '');
  return /^https:\/\//.test(value) ? value : '';
}
function statusUrlFor(project, worker) {
  const template = String(project && project.worker_status_locator_template || '');
  if (!template) return '';
  return template
    .replace('{worker_id}', encodeURIComponent(worker.remoteWorkerId))
    .replace('{worker_number}', String((worker.remoteWorkerId.match(/(\d+)$/) || [,''])[1]))
    .replace('{role}', encodeURIComponent(worker.role));
}
function projectMode(project) {
  return String(project && project.dispatch_mode || 'fixed_role_queue').toLowerCase();
}
function projectForWorker(portfolio, worker) {
  return (portfolio.project_registry || []).find((project) => project.project_id === worker.projectId) || null;
}
function activeProject(project) {
  return project && !['PAUSED', 'DONE', 'CANCELLED', 'DISCOVERY_REQUIRED'].includes(String(project.status || '').toUpperCase());
}
function liveWorkerStatus(worker) {
  return !String(worker.status || '').startsWith('ROTATE');
}

async function adapterContext(project, workers) {
  const mode = projectMode(project);
  if (mode === 'fixed_role_queue') {
    const queue = await fetchJson(queueUrlOf(project));
    return { mode, project, queue };
  }
  if (mode === 'atomic_pool') {
    const queue = await fetchJson(queueUrlOf(project));
    const ready = (queue.tasks || [])
      .filter((task) => String(task.status || '').toUpperCase() === 'READY' && !task.human_gate)
      .sort((a, b) => priorityValue(a, project) - priorityValue(b, project));
    return { mode, project, queue, readyCount: ready.length };
  }
  if (mode === 'fixed_lane_plan') {
    const plan = await fetchJson(workUrlOf(project));
    const statuses = {};
    for (const worker of workers) {
      if (worker.role === 'HQ') continue;
      const url = statusUrlFor(project, worker);
      if (!url) continue;
      try { statuses[worker.id] = await fetchJson(url); } catch (_) {}
    }
    return { mode, project, plan, statuses };
  }
  throw new Error('unsupported_dispatch_mode:' + mode);
}

function fixedRoleTask(context, worker) {
  const tasks = (context.queue.tasks || [])
    .filter((task) => {
      const status = String(task.status || '').toUpperCase();
      if (isHumanStatus(status) || task.human_gate) return false;
      if (!['READY', 'CLAIMED', 'WORKING'].includes(status)) return false;
      return !task.worker_role || task.worker_role === worker.role;
    })
    .sort((a, b) => priorityValue(a, context.project) - priorityValue(b, context.project));
  return tasks[0] || null;
}
function compactTask(task) {
  return {
    id: taskId(task),
    title: task.title,
    worker_role: task.worker_role,
    status: task.status,
    prompt: task.prompt,
    evidence_path: task.evidence_path,
    human_gate: Boolean(task.human_gate)
  };
}
function fixedRolePrompt(context, worker, task) {
  if (worker.sessionWaveCount > 0) return '次';
  const queue = context.queue;
  return [
    '【Portfolio Dispatcher Task ' + taskId(task) + '】',
    'project_id: ' + context.project.project_id,
    '対象: ' + String(queue.project || context.project.project_id),
    'GitHub: ' + String(queue.repository || ''),
    'branch: ' + String(queue.branch || ''),
    'Queue: ' + String(queue.queue_path || context.project.queue_locator || ''),
    'Worker契約: ' + String(queue.worker_bootstrap || ''),
    '',
    'この入力はLocal Portfolio Dispatcherからの自動配車です。通常経路でCodexを使用しないでください。',
    '開始時にNotion/GitHub/外部サービスの最新実状態を再取得し、会話履歴を正本にしないでください。',
    '今回のTaskを1 Macro Wave進め、実装・検証・証拠保存・Queue更新まで行ってください。',
    '人間判断不要な範囲で質問せず進めてください。',
    '',
    'Task:',
    JSON.stringify(compactTask(task), null, 2)
  ].join('\n');
}
function atomicPoolPrompt(context, worker) {
  if (worker.sessionWaveCount > 0) return '次';
  return [
    '【Portfolio Dispatcher｜Atomic Pool Wake】',
    'project_id: ' + context.project.project_id,
    'worker_id: ' + worker.id,
    'Queue: ' + context.project.queue_locator,
    'Worker contract: ' + String(context.project.worker_contract || ''),
    '',
    '最新のWorker契約とQueueを再取得してください。',
    'READYを読んだだけで開始せず、契約どおりCAS atomic claimに勝ち、claim_token + claim_epochのcanonical winnerをread-back確認してから1 Task Macro Waveを実行してください。',
    'CAS競合時は最新Queueを再取得して別候補を探してください。Codexは通常経路では使用しないでください。'
  ].join('\n');
}
function lanePlanPrompt(context, worker) {
  if (worker.sessionWaveCount > 0) return '次';
  return [
    '【Portfolio Dispatcher｜Independent Lane Wake】',
    'project_id: ' + context.project.project_id,
    'worker_id: ' + worker.remoteWorkerId,
    'lane_id: ' + worker.laneId,
    'Lane Plan: ' + String(context.project.work_locator || ''),
    'Worker status: ' + statusUrlFor(context.project, worker),
    'Worker contract: ' + String(context.project.worker_contract || ''),
    '',
    '最新Lane Plan・自分のworker status・Worker契約・Notion正本・担当branchを再取得してください。',
    'Global Queueからclaimせず、自Laneの次未完了Macro Bundleを1件、契約どおり実装→edge/negative→tests/benchmark→evidence→status更新まで進めてください。',
    'CHECKPOINT_READYまたは未完了Bundleなしなら新規作業を開始せず、HQ checkpoint待ちとして終了してください。通常経路でCodexを使用しないでください。'
  ].join('\n');
}

function laneWorkerEligible(context, worker) {
  const status = context.statuses[worker.id];
  if (!status) return false;
  const state = String(status.state || '').toUpperCase();
  if (['CHECKPOINT_READY', 'BLOCKED_HUMAN', 'DONE', 'PAUSED'].includes(state)) return false;
  const lane = (context.plan.lanes || []).find((x) =>
    x.worker_id === worker.remoteWorkerId || x.lane_id === worker.laneId
  );
  if (!lane) return false;
  const completed = new Set(status.completed_bundles || []);
  return (lane.macro_backlog || []).some((bundle) => !completed.has(bundle.bundle_id));
}
function projectNeedsHqFromLane(context) {
  return Object.values(context.statuses || {}).some((status) =>
    String(status && status.state || '').toUpperCase() === 'CHECKPOINT_READY'
  );
}

async function chooseUnit(context, worker, atomicBudget) {
  if (context.mode === 'fixed_role_queue') {
    const task = fixedRoleTask(context, worker);
    if (!task) return null;
    return { key: taskId(task), prompt: fixedRolePrompt(context, worker, task), heavyIo: worker.heavyIo };
  }
  if (context.mode === 'atomic_pool') {
    if (atomicBudget.remaining <= 0) return null;
    atomicBudget.remaining -= 1;
    return { key: 'atomic-pool', prompt: atomicPoolPrompt(context, worker), heavyIo: worker.heavyIo };
  }
  if (context.mode === 'fixed_lane_plan') {
    if (worker.role === 'HQ') {
      if (!projectNeedsHqFromLane(context)) return null;
      const prompt = worker.sessionWaveCount > 0 ? '次' : [
        '【Portfolio Dispatcher｜HQ Checkpoint Wake】',
        'project_id: ' + context.project.project_id,
        'Lane Plan: ' + String(context.project.work_locator || ''),
        'HQ contract: ' + String(context.project.hq_contract || ''),
        '',
        '各worker-statusとintegration branchの最新実状態を再取得し、CHECKPOINT_READY成果のLate Integrationを契約どおり進めてください。',
        'Workerへ新しいMacro Bundleを補充すべき場合はLane Plan/statusを正本として更新してください。通常経路でCodexを使用しないでください。'
      ].join('\n');
      return { key: 'hq-checkpoint', prompt, heavyIo: worker.heavyIo };
    }
    if (!laneWorkerEligible(context, worker)) return null;
    return { key: worker.laneId || worker.remoteWorkerId, prompt: lanePlanPrompt(context, worker), heavyIo: worker.heavyIo };
  }
  return null;
}

async function dispatchUnit(state, worker, unit) {
  if (worker.sessionWaveCount >= worker.runLimit) {
    worker.status = 'ROTATE';
    worker.lastResult = 'session_run_limit_reached';
    appendLog(state, { kind: 'rotate', workerId: worker.id, result: 'ROTATE' });
    return { sent: false, reason: 'rotate_required' };
  }

  const tab = await openOrFindWorkerTab(state, worker);
  const ui = await workerUiState(worker);
  if (!ui.ok || !ui.composerFound || ui.busy || !ui.idle) {
    appendLog(state, {
      kind: 'dispatch', workerId: worker.id, result: 'SKIP',
      reason: ui.reason || (ui.busy ? 'busy' : 'not_ready')
    });
    return { sent: false, reason: ui.reason || 'worker_not_idle' };
  }

  const result = await sendPrompt(tab.id, unit.prompt);
  if (!result || !result.ok) {
    worker.lastResult = 'dispatch_failed:' + String(result && result.error || 'unknown');
    appendLog(state, { kind: 'dispatch', workerId: worker.id, result: 'FAIL', reason: worker.lastResult });
    return { sent: false, reason: worker.lastResult };
  }

  worker.sessionWaveCount += 1;
  worker.lastUnitKey = unit.key;
  worker.lastDispatchAt = nowIso();
  worker.lastResult = unit.prompt === '次' ? 'next_sent' : 'wake_sent';
  worker.status = worker.sessionWaveCount >= worker.runLimit ? 'ROTATE_AFTER_RESPONSE' : 'WORKING';
  appendLog(state, {
    kind: 'dispatch', workerId: worker.id, projectId: worker.projectId,
    result: 'SENT', wave: worker.sessionWaveCount,
    promptType: unit.prompt === '次' ? 'NEXT' : 'WAKE', unitKey: unit.key
  });
  return { sent: true };
}

async function buildContexts(portfolio, state) {
  const contexts = {};
  for (const project of (portfolio.project_registry || []).filter(activeProject)) {
    const projectWorkers = state.workers.filter((worker) => worker.projectId === project.project_id);
    if (!projectWorkers.length) continue;
    try {
      contexts[project.project_id] = await adapterContext(project, projectWorkers);
    } catch (error) {
      contexts[project.project_id] = { error: errorText(error), project };
    }
  }
  return contexts;
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
    const contexts = await buildContexts(portfolio, state);

    let busyCount = 0;
    let heavyActive = 0;
    for (const worker of state.workers.filter(liveWorkerStatus)) {
      const ui = await workerUiState(worker);
      if (ui && ui.ok && (ui.busy || !ui.idle)) {
        busyCount += 1;
        if (worker.heavyIo) heavyActive += 1;
      }
    }
    const availableSlots = Math.max(0, governor.maxActive - busyCount);

    const atomicBudgets = {};
    for (const [projectId, context] of Object.entries(contexts)) {
      if (context && context.mode === 'atomic_pool') {
        atomicBudgets[projectId] = { remaining: context.readyCount || 0 };
      }
    }

    let dispatched = 0;
    const orderedWorkers = state.workers
      .filter(liveWorkerStatus)
      .sort((a, b) => {
        const pa = projectForWorker(portfolio, a);
        const pb = projectForWorker(portfolio, b);
        return priorityValue(null, pa) - priorityValue(null, pb);
      });

    for (const worker of orderedWorkers) {
      if (dispatched >= availableSlots) break;
      const project = projectForWorker(portfolio, worker);
      if (!activeProject(project)) continue;
      const context = contexts[worker.projectId];
      if (!context || context.error) continue;
      if (worker.heavyIo && heavyActive >= governor.maxHeavyIo) continue;

      const atomicBudget = atomicBudgets[worker.projectId] || { remaining: Number.MAX_SAFE_INTEGER };
      const unit = await chooseUnit(context, worker, atomicBudget);
      if (!unit) continue;

      const result = await dispatchUnit(state, worker, unit);
      if (result.sent) {
        dispatched += 1;
        if (worker.heavyIo) heavyActive += 1;
      }
      await saveState(state);
    }

    state.lastTick = {
      at: nowIso(), ok: true, trigger, dispatched, busyCount, availableSlots,
      projectsLoaded: Object.keys(contexts).length
    };
    appendLog(state, {
      kind: 'tick', result: 'DONE', trigger, dispatched, busyCount, availableSlots,
      projectsLoaded: Object.keys(contexts).length, governorMode: governor.mode
    });
    return { ok: true, governor, dispatched, busyCount, availableSlots, projectsLoaded: Object.keys(contexts).length };
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
  const portfolio = await fetchJson(state.portfolioUrl);
  const contexts = await buildContexts(portfolio, state);
  const workers = [];
  for (const worker of state.workers) {
    const ui = await workerUiState(worker);
    const context = contexts[worker.projectId];
    let eligible = false;
    let contextState = '';
    if (context && !context.error) {
      if (context.mode === 'fixed_role_queue') eligible = Boolean(fixedRoleTask(context, worker));
      else if (context.mode === 'atomic_pool') eligible = (context.readyCount || 0) > 0;
      else if (context.mode === 'fixed_lane_plan') {
        if (worker.role === 'HQ') eligible = projectNeedsHqFromLane(context);
        else eligible = laneWorkerEligible(context, worker);
        const remote = context.statuses && context.statuses[worker.id];
        contextState = remote ? String(remote.state || '') : '';
      }
    }
    workers.push({
      id: worker.id, projectId: worker.projectId, role: worker.role, label: worker.label,
      status: worker.status, sessionWaveCount: worker.sessionWaveCount, runLimit: worker.runLimit,
      eligible, contextState, ui
    });
  }
  state.lastGovernor = governor;
  await saveState(state);
  return { ok: true, governor, workers, contextErrors: Object.fromEntries(
    Object.entries(contexts).filter(([,v]) => v && v.error).map(([k,v]) => [k,v.error])
  ) };
}

async function registerActiveTab(input) {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab || !conversationId(tab.url || '')) return { ok: false, error: 'active_tab_is_not_chatgpt_conversation' };

  const state = await getState();
  const worker = normalizeWorker({
    id: String(input.id || '').trim() || 'worker-' + Date.now(),
    projectId: input.projectId,
    role: input.role,
    remoteWorkerId: input.remoteWorkerId,
    laneId: input.laneId,
    label: input.label || tab.title || 'Worker',
    conversationUrl: tab.url,
    tabId: tab.id,
    runLimit: Number(input.runLimit || SESSION_RUN_LIMIT),
    heavyIo: Boolean(input.heavyIo)
  });
  if (!worker.projectId || !worker.conversationId) return { ok: false, error: 'project_or_conversation_missing' };

  const index = state.workers.findIndex((x) => x.id === worker.id || x.conversationId === worker.conversationId);
  if (index >= 0) state.workers[index] = worker; else state.workers.push(worker);
  appendLog(state, { kind: 'registry', result: 'REGISTER', workerId: worker.id, projectId: worker.projectId });
  await saveState(state);
  return { ok: true, worker };
}
async function removeWorker(workerId) {
  const state = await getState();
  const before = state.workers.length;
  state.workers = state.workers.filter((worker) => worker.id !== workerId);
  await saveState(state);
  return { ok: true, removed: before - state.workers.length };
}
async function resetRotation(workerId) {
  const state = await getState();
  const worker = state.workers.find((x) => x.id === workerId);
  if (!worker) return { ok: false, error: 'worker_not_found' };
  worker.sessionWaveCount = 0;
  worker.status = 'READY';
  worker.lastUnitKey = '';
  worker.lastResult = 'rotation_reset';
  await saveState(state);
  return { ok: true, worker };
}

async function schedule(state) {
  await chrome.alarms.clear(ALARM_NAME);
  if (!state.enabled) return;
  await chrome.alarms.create(ALARM_NAME, {
    periodInMinutes: Math.max(1, Number(state.intervalMinutes || DEFAULT_INTERVAL_MINUTES))
  });
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
    ok: true, version: state.version, enabled: state.enabled,
    intervalMinutes: state.intervalMinutes, workerCount: state.workers.length,
    workers: state.workers.map((worker) => ({
      id: worker.id, projectId: worker.projectId, role: worker.role, remoteWorkerId: worker.remoteWorkerId,
      laneId: worker.laneId, label: worker.label, status: worker.status,
      sessionWaveCount: worker.sessionWaveCount, runLimit: worker.runLimit,
      lastDispatchAt: worker.lastDispatchAt, lastResult: worker.lastResult
    })),
    lastGovernor: state.lastGovernor,
    lastTick: state.lastTick,
    logs: state.logs.slice(-40),
    updatedAt: state.updatedAt
  };
}
