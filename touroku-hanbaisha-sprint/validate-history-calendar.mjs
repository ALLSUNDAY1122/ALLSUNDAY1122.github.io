import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync(new URL('./history-calendar-v02.js', import.meta.url), 'utf8');
const marker = '\n})();';
if (!source.endsWith(marker + '\n') && !source.endsWith(marker)) throw new Error('Unexpected history-calendar-v02.js wrapper');
const instrumented = source.replace(/\n\}\)\(\);\s*$/, '\n  globalThis.__historyTest={activityByDay,keyForDate};\n})();');

const noop = () => {};
const app = {
  querySelector: () => null,
  querySelectorAll: () => [],
};
const sandbox = {
  console,
  localStorage: { getItem: () => null },
  document: { getElementById: () => app, createElement: () => ({ innerHTML: '', firstElementChild: null }) },
  MutationObserver: class { observe() {} },
  requestAnimationFrame: fn => fn(),
  setTimeout: noop,
};
sandbox.globalThis = sandbox;
vm.createContext(sandbox);
vm.runInContext(instrumented, sandbox, { filename: 'history-calendar-v02.js' });
const { activityByDay, keyForDate } = sandbox.__historyTest;

function assert(cond, message) {
  if (!cond) throw new Error(message);
}

const now = new Date();
const today = keyForDate(now);

let map = activityByDay({ stats: { history: [{ date: now.toISOString(), correct: 8, total: 10 }] } });
assert(map[today]?.sessions === 1, 'completed session must appear today');
assert(map[today]?.correct === 8 && map[today]?.total === 10, 'completed score mismatch');

map = activityByDay({
  stats: { history: [] },
  inProgress: {
    startedAt: now.getTime(),
    correct: 4,
    chapterAnswered: { '第1章': 3, '第2章': 2 },
  },
});
assert(map[today]?.sessions === 0, 'in-progress must not count as completed session');
assert(map[today]?.correct === 4 && map[today]?.total === 5, 'in-progress answers must appear immediately');
assert(map[today]?.inProgress === true, 'in-progress marker missing');

map = activityByDay({
  stats: { history: [{ date: now.toISOString(), correct: 6, total: 8 }] },
  inProgress: {
    startedAt: now.getTime(),
    correct: 2,
    chapterAnswered: { '第3章': 3 },
  },
});
assert(map[today]?.sessions === 1, 'completed+in-progress session count mismatch');
assert(map[today]?.correct === 8 && map[today]?.total === 11, 'completed+in-progress aggregation mismatch');
assert(map[today]?.inProgress === true, 'combined activity must show in-progress');

map = activityByDay({
  stats: { history: [] },
  inProgress: { startedAt: now.getTime(), correct: 0, chapterAnswered: {} },
});
assert(!map[today], 'zero-answer in-progress must not create calendar activity');

console.log('PASS: history calendar reflects same-day completed and in-progress answers using production logic');
