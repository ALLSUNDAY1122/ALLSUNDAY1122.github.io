const __rotationBaseSaveState = saveState;
const __rotationBasePublicStatus = publicStatus;

function rotationEntryId(worker) {
  return [worker.projectId, worker.id, worker.conversationId || 'no-conversation'].join(':');
}

function ensureRotationQueue(state) {
  if (!Array.isArray(state.rotationQueue)) state.rotationQueue = [];
  return state.rotationQueue;
}

function syncRotationQueue(state) {
  const queue = ensureRotationQueue(state);
  const now = nowIso();
  const activeWorkerIds = new Set(state.workers.map((worker) => worker.id));

  for (const worker of state.workers) {
    if (!String(worker.status || '').startsWith('ROTATE')) continue;
    const id = rotationEntryId(worker);
    let entry = queue.find((item) => item.id === id);
    if (!entry) {
      entry = {
        id,
        workerId: worker.id,
        projectId: worker.projectId,
        role: worker.role,
        remoteWorkerId: worker.remoteWorkerId,
        laneId: worker.laneId,
        label: worker.label,
        oldConversationUrl: worker.conversationUrl,
        oldConversationId: worker.conversationId,
        completedWaves: worker.sessionWaveCount,
        runLimit: worker.runLimit,
        state: 'PENDING_PROJECT_PROBE',
        probe: null,
        successorConversationUrl: null,
        successorConversationId: null,
        createdAt: now,
        updatedAt: now,
        error: null
      };
      queue.push(entry);
    } else {
      entry.completedWaves = worker.sessionWaveCount;
      entry.updatedAt = now;
    }
  }

  for (const entry of queue) {
    if (!activeWorkerIds.has(entry.workerId) && !['VERIFIED', 'SUPERSEDED', 'CANCELLED'].includes(entry.state)) {
      entry.state = 'CANCELLED';
      entry.error = 'worker_removed_before_rotation_completed';
      entry.updatedAt = now;
    }
  }

  if (queue.length > 100) {
    const terminal = queue.filter((item) => ['VERIFIED', 'SUPERSEDED', 'CANCELLED', 'FAILED'].includes(item.state));
    const active = queue.filter((item) => !['VERIFIED', 'SUPERSEDED', 'CANCELLED', 'FAILED'].includes(item.state));
    state.rotationQueue = terminal.slice(-50).concat(active).slice(-100);
  }
  return state.rotationQueue;
}

saveState = async function rotationAwareSaveState(state) {
  syncRotationQueue(state);
  return await __rotationBaseSaveState(state);
};

publicStatus = async function rotationAwarePublicStatus() {
  const result = await __rotationBasePublicStatus();
  const state = await getState();
  syncRotationQueue(state);
  result.rotationQueue = state.rotationQueue || [];
  result.pendingRotations = result.rotationQueue.filter((item) =>
    !['VERIFIED', 'SUPERSEDED', 'CANCELLED', 'FAILED'].includes(item.state)
  ).length;
  result.rotationEngine = 'probe_only';
  return result;
};
