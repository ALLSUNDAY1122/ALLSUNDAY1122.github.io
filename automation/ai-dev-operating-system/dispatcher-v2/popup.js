async function ask(type) { return await chrome.runtime.sendMessage({ type }); }
function pct(value) { return Number.isFinite(value) ? value.toFixed(1) + '%' : '-'; }
async function render() {
  const status = await ask('PORTFOLIO_STATUS');
  document.querySelector('#enabled').textContent = status.enabled ? 'ON' : 'OFF';
  const g = status.lastGovernor;
  document.querySelector('#governor').textContent = g ? g.mode + ' / active ' + g.maxActive : '-';
  document.querySelector('#memory').textContent = g ? pct(g.snapshot.memoryUsedPct) : '-';
  document.querySelector('#cpu').textContent = g ? pct(g.snapshot.cpuUsedPct) : '-';
  document.querySelector('#tabs').textContent = g ? String(g.snapshot.chatgptTabCount) : '-';
  document.querySelector('#workers').textContent = String(status.workerCount || 0);
  const rotate = (status.workers || []).filter((w) => String(w.status).startsWith('ROTATE')).length;
  document.querySelector('#rotate').textContent = String(rotate);
  document.querySelector('#last').textContent = status.lastTick ? JSON.stringify(status.lastTick) : '-';
}
document.querySelector('#start').addEventListener('click', async () => { await ask('PORTFOLIO_START'); await render(); });
document.querySelector('#stop').addEventListener('click', async () => { await ask('PORTFOLIO_STOP'); await render(); });
document.querySelector('#tick').addEventListener('click', async () => { await ask('PORTFOLIO_TICK'); await render(); });
document.querySelector('#preflight').addEventListener('click', async () => { const x = await ask('PORTFOLIO_PREFLIGHT'); document.querySelector('#last').textContent = JSON.stringify(x); await render(); });
render();
