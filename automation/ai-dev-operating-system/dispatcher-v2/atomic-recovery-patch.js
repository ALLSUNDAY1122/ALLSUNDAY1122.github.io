const __v21AdapterContext = adapterContext;
const __v21ChooseUnit = chooseUnit;
const __v21PublicStatus = publicStatus;

function leaseExpired(task, nowMs = Date.now()) {
  const raw = task && task.lease_expires_at;
  if (!raw) return false;
  const ms = Date.parse(raw);
  return Number.isFinite(ms) && ms <= nowMs;
}

function atomicContinuationTask(context, worker) {
  return (context.claimedActive || []).find((task) =>
    String(task.claimed_by || '') === worker.id && !leaseExpired(task)
  ) || null;
}

function atomicStaleTask(context) {
  context._staleReserved = context._staleReserved || new Set();
  const task = (context.staleClaims || []).find((candidate) => !context._staleReserved.has(taskId(candidate)));
  if (!task) return null;
  context._staleReserved.add(taskId(task));
  return task;
}

function atomicContinuationPrompt(context, worker, task) {
  if (worker.sessionWaveCount > 0) return '次';
  return [
    '【Portfolio Dispatcher｜Atomic Claim Continuation】',
    'project_id: ' + context.project.project_id,
    'worker_id: ' + worker.id,
    'task_id: ' + taskId(task),
    'Queue: ' + context.project.queue_locator,
    '',
    'このTaskはQueue上であなたのCLAIMED/WORKINGとして残っています。',
    '最新Queueを再取得し、claim_token + claim_epoch + leaseが現在もcanonicalかread-back確認してください。',
    '有効なら同じTaskを未完了地点から1 Macro Wave継続し、heartbeat/evidence/Queueを契約どおり更新してください。',
    'canonicalでなければ旧attemptからproduction/Queue確定を行わず、新しい正本状態に従ってください。'
  ].join('\n');
}

function atomicStaleRecoveryPrompt(context, worker, task) {
  return [
    '【Portfolio Dispatcher｜Expired Lease Recovery】',
    'project_id: ' + context.project.project_id,
    'worker_id: ' + worker.id,
    'stale_task_id: ' + taskId(task),
    'Queue: ' + context.project.queue_locator,
    'Worker contract: ' + String(context.project.worker_contract || ''),
    '',
    'Queue上でlease期限切れのCLAIMED/WORKING Taskを検出しました。',
    '最新Queue/blob SHAを再取得し、Worker契約のfencing規則に従ってこのstale attemptを再claim可能か確認してください。',
    '再claimする場合はclaim_epochを必ず増やし、新claim_token/lease/heartbeat/attempt branchをCASで一体更新し、read-backでcanonical winner確認後だけ作業してください。',
    'CAS競合または既に別winnerが存在する場合はその正本に従い、旧epochから外部副作用やMERGED/VERIFIEDを確定しないでください。',
    '通常経路でCodexは使用しないでください。'
  ].join('\n');
}

adapterContext = async function patchedAdapterContext(project, workers) {
  const mode = projectMode(project);
  if (mode !== 'atomic_pool') return await __v21AdapterContext(project, workers);

  const queue = await fetchJson(queueUrlOf(project));
  const tasks = Array.isArray(queue.tasks) ? queue.tasks : [];
  const ready = tasks
    .filter((task) => String(task.status || '').toUpperCase() === 'READY' && !task.human_gate)
    .sort((a, b) => priorityValue(a, project) - priorityValue(b, project));
  const claimedActive = tasks.filter((task) =>
    ['CLAIMED', 'WORKING'].includes(String(task.status || '').toUpperCase()) &&
    !task.human_gate &&
    !leaseExpired(task)
  );
  const staleClaims = tasks.filter((task) =>
    ['CLAIMED', 'WORKING'].includes(String(task.status || '').toUpperCase()) &&
    !task.human_gate &&
    leaseExpired(task)
  );
  return {
    mode, project, queue,
    readyCount: ready.length,
    claimedActive,
    staleClaims,
    _staleReserved: new Set()
  };
};

chooseUnit = async function patchedChooseUnit(context, worker, atomicBudget) {
  if (context.mode !== 'atomic_pool') {
    return await __v21ChooseUnit(context, worker, atomicBudget);
  }

  const continuation = atomicContinuationTask(context, worker);
  if (continuation) {
    return {
      key: 'atomic-continue:' + taskId(continuation),
      prompt: atomicContinuationPrompt(context, worker, continuation),
      heavyIo: worker.heavyIo
    };
  }

  const stale = atomicStaleTask(context);
  if (stale) {
    return {
      key: 'atomic-recover:' + taskId(stale),
      prompt: atomicStaleRecoveryPrompt(context, worker, stale),
      heavyIo: worker.heavyIo
    };
  }

  if (atomicBudget.remaining <= 0) return null;
  atomicBudget.remaining -= 1;
  return {
    key: 'atomic-pool',
    prompt: atomicPoolPrompt(context, worker),
    heavyIo: worker.heavyIo
  };
};

publicStatus = async function patchedPublicStatus() {
  const result = await __v21PublicStatus();
  result.engine = '2.2';
  result.atomicRecovery = true;
  return result;
};
