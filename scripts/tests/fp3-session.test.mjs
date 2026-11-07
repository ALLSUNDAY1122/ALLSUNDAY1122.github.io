import { readFileSync } from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import test from 'node:test';

const html = readFileSync(new URL('../../fp3-manabi-sprint/index.html', import.meta.url), 'utf8');
const code = html.match(/<script>\n([\s\S]*?)<\/script>/)[1].split("document.getElementById('start12').onclick=")[0];
const bank = JSON.parse(readFileSync(new URL('../../fp3-manabi-sprint/question_bank_180.payload.json', import.meta.url), 'utf8')).questions;
const q = bank.find(q => q.type === 'true_false' && q.status === 'active_core');

function app(storage = new Map()) {
  const elements = new Map();
  function element(id = '') {
    let contents = '';
    const flags = new Set();
    return {
      id, children: [], style: {}, dataset: {}, disabled: false, textContent: '',
      classList: { add: x => flags.add(x), remove: x => flags.delete(x), toggle: (x, value) => { if (value ?? !flags.has(x)) flags.add(x); else flags.delete(x); } },
      append(...items) { this.children.push(...items); for (const item of items) if (item?.id) elements.set(item.id, item); },
      appendChild(item) { this.append(item); }, replaceChildren(...items) { this.children = items; },
      get innerHTML() { return contents; }, set innerHTML(value) { contents = value; this.children = []; },
    };
  }
  const get = id => { if (!elements.has(id)) elements.set(id, element(id)); return elements.get(id); };
  // query-by-ID is a minimal DOM adapter; all session/scoring functions are real product code.
  const context = vm.createContext({
    Date, Math, URL,
    document: { getElementById: get, createElement: () => element(), createTextNode: text => ({ textContent: text }),
      querySelectorAll: selector => selector === '.choice' ? get('choices').children : [] },
    window: { scrollTo() {} },
    localStorage: { getItem: k => storage.get(k) ?? null, setItem: (k, v) => storage.set(k, v), removeItem: k => storage.delete(k) },
  });
  vm.runInContext(code, context);
  vm.runInContext('bank=' + JSON.stringify(bank), context);
  return { run: text => vm.runInContext(text, context), state: () => JSON.parse(vm.runInContext('JSON.stringify(st)', context)), storage, get };
}

test('restart after a scored answer restores feedback and prevents double counting', () => {
  let a = app();
  a.run(`begin([bank.find(q=>q.id===${JSON.stringify(q.id)})],'12問スプリント');answer(${q.answer},null,false)`);
  assert.equal(a.state().totalAnswered, 1);
  assert.equal(a.state().totalCorrect, 1);
  a = app(a.storage); a.run('resume()');
  assert.equal(a.run('answered'), true);
  assert.equal(a.get('unknown').disabled, true);
  a.run(`answer(${!q.answer},null,false)`);
  assert.equal(a.state().totalAnswered, 1);
  assert.equal(a.state().totalCorrect, 1);
  a.run('next()');
  assert.equal(a.state().resume, null);
  assert.equal(a.state().history[0].correct, 1);
});

test('unknown and hesitant answers retain weakness counts through restart', () => {
  let a = app();
  a.run(`begin([bank.find(q=>q.id===${JSON.stringify(q.id)})],'12問スプリント');answer(null,null,true)`);
  a = app(a.storage); a.run('resume()');
  assert.equal(a.state().weak[q.id].reason, 'unknown');
  assert.equal(a.run('newWeak'), 1);
  a.run(`begin([bank.find(q=>q.id===${JSON.stringify(q.id)})],'12問スプリント');answer(${q.answer},null,false);markWeak()`);
  a = app(a.storage); a.run('resume()');
  assert.equal(a.state().resume.markedWeak, true);
  assert.equal(a.get('markWeak').className, 'markweak');
});

test('weakness requires three real correct answers, not three resumes', () => {
  let a = app();
  a.run(`registerWeak(bank.find(q=>q.id===${JSON.stringify(q.id)}),'wrong');save()`);
  for (let i = 1; i <= 3; i++) {
    a.run(`begin([bank.find(q=>q.id===${JSON.stringify(q.id)})],'苦手復習');answer(${q.answer},null,false)`);
    a = app(a.storage); a.run('resume()');
    assert.equal(a.state().weak[q.id]?.streak, i < 3 ? i : undefined);
    a.run('next()');
  }
  assert.equal(a.state().totalAnswered, 3);
});

test('a partially missing bank cannot silently shift the resumed question', () => {
  const a = app();
  a.run(`begin([bank[0],bank[1]],'12問スプリント');st.resume.ids[0]='removed-id';resume()`);
  assert.equal(a.state().resume, null);
});

test('legacy ambiguous answer state is discarded without changing cumulative stats', () => {
  const a = app();
  a.run(`begin([bank[0]],'12問スプリント');st.totalAnswered=7;delete st.resume.answered;resume()`);
  assert.equal(a.state().resume, null);
  assert.equal(a.state().totalAnswered, 7);
});

test('a saved terminal index completes without replaying the last question', () => {
  const a = app();
  a.run(`begin([bank[0]],'12問スプリント');st.resume.idx=1;st.resume.correct=1;resume()`);
  assert.equal(a.state().resume, null);
  assert.equal(a.state().history[0].correct, 1);
});
