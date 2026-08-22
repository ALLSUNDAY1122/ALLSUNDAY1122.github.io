async function ask(type, extra = {}) { return await chrome.runtime.sendMessage({ type, ...extra }); }
function pct(value) { return Number.isFinite(value) ? value.toFixed(1) + '%' : '-'; }
function el(id) { return document.querySelector('#' + id); }

function workerRow(worker) {
  const row = document.createElement('div');
  row.className = 'worker';
  const text = document.createElement('div');
  text.textContent = `${worker.label || worker.id} | ${worker.projectId} | ${worker.role || '-'} | ${worker.status} | ${worker.sessionWaveCount}/${worker.runLimit}`;
  const remove = document.createElement('button');
  remove.textContent = '削除';
  remove.addEventListener('click', async () => {
    await ask('PORTFOLIO_REMOVE_WORKER', { workerId: worker.id });
    await render();
  });
  row.append(text, remove);
  return row;
}

async function render() {
  const status = await ask('PORTFOLIO_STATUS');
  el('enabled').textContent = status.enabled ? 'ON' : 'OFF';
  const g = status.lastGovernor;
  el('governor').textContent = g ? g.mode + ' / active ' + g.maxActive : '-';
  el('memory').textContent = g ? pct(g.snapshot.memoryUsedPct) : '-';
  el('cpu').textContent = g ? pct(g.snapshot.cpuUsedPct) : '-';
  el('tabs').textContent = g ? String(g.snapshot.chatgptTabCount) : '-';
  el('workers').textContent = String(status.workerCount || 0);
  const rotate = (status.workers || []).filter((w) => String(w.status).startsWith('ROTATE')).length;
  el('rotate').textContent = String(rotate);
  el('last').textContent = status.lastTick ? JSON.stringify(status.lastTick, null, 2) : '-';

  const list = el('workerList');
  list.replaceChildren();
  for (const worker of status.workers || []) list.appendChild(workerRow(worker));
}

async function activeProjectProbe() {
  const tabs = await chrome.tabs.query({ active: true, currentWindow: true });
  const tab = tabs[0];
  if (!tab || !tab.id || !String(tab.url || '').startsWith('https://chatgpt.com/')) {
    return { ok: false, error: 'active_tab_is_not_chatgpt' };
  }
  try {
    return await chrome.tabs.sendMessage(tab.id, { type: 'PROJECT_CONTEXT_PROBE' });
  } catch (error) {
    return { ok: false, error: String(error && error.message ? error.message : error) };
  }
}

el('start').addEventListener('click', async () => { await ask('PORTFOLIO_START'); await render(); });
el('stop').addEventListener('click', async () => { await ask('PORTFOLIO_STOP'); await render(); });
el('tick').addEventListener('click', async () => { await ask('PORTFOLIO_TICK'); await render(); });
el('preflight').addEventListener('click', async () => {
  const result = await ask('PORTFOLIO_PREFLIGHT');
  await render();
  el('last').textContent = JSON.stringify(result, null, 2);
});
el('projectProbe').addEventListener('click', async () => {
  const result = await activeProjectProbe();
  el('last').textContent = JSON.stringify(result, null, 2);
});
el('register').addEventListener('click', async () => {
  const worker = {
    id: el('workerId').value.trim(),
    projectId: el('projectId').value,
    role: el('role').value.trim(),
    remoteWorkerId: el('remoteWorkerId').value.trim(),
    laneId: el('laneId').value.trim(),
    label: el('label').value.trim(),
    runLimit: Number(el('runLimit').value || 3),
    heavyIo: el('heavyIo').checked
  };
  const result = await ask('PORTFOLIO_REGISTER_ACTIVE', { worker });
  el('last').textContent = JSON.stringify(result, null, 2);
  if (result.ok) await render();
});

render();
