// 合計整合検算を使ったOCR桁誤りの補正。
//
// 「支給合計 = 基本給+残業+その他」「控除合計 = 各控除」「差引 = 支給合計-控除合計」が
// 1桁の読み違いだけで崩れている場合、OCRが起こしやすい誤り（数字の置換・余分な数字）に
// 限定して修正候補を探索し、合計と完全に一致する組み合わせだけを採用する。
//
// 重要: 補正した値は必ず「要確認」として提示する。確定候補にはしない。

// OCRが混同しやすい数字の組み合わせ
const CONFUSION = {
  0: ['9', '6', '8', '3', 'o'],
  1: ['7', '4'],
  2: ['7', '3'],
  3: ['8', '9', '5', '2'],
  4: ['9', '1', '7'],
  5: ['6', '8', '3', '9'],
  6: ['5', '8', '0', '9'],
  7: ['1', '2', '9'],
  8: ['3', '6', '0', '5', '9'],
  9: ['0', '4', '3', '7', '8'],
};

// 逆引き: 読まれた数字 d が本当は何だった可能性があるか
const REVERSE = {};
for (const [truth, misread] of Object.entries(CONFUSION)) {
  for (const m of misread) {
    if (!/^\d$/.test(m)) continue;
    (REVERSE[m] = REVERSE[m] || []).push(truth);
  }
}

const SUBSTITUTION_COST = 1;
const DELETION_COST = 1.4;
const INSERTION_COST = 1.6;
// 最良解がこの倍率以内の別解を持つ場合は「曖昧」とみなして補正しない
const AMBIGUITY_MARGIN = 1.35;

/**
 * value を1文字だけ編集して得られる「本来の値」候補を列挙する。
 * @param {number} value OCRが読み取った値（非負）
 * @returns {Array<{value:number, cost:number, kind:string}>}
 */
export function editCandidates(value) {
  const digits = String(Math.abs(Math.trunc(value)));
  const out = new Map();
  const add = (text, cost, kind) => {
    if (!/^\d+$/.test(text) || text.length === 0) return;
    const v = parseInt(text, 10);
    if (!Number.isFinite(v) || v === Math.abs(value)) return;
    const prev = out.get(v);
    if (!prev || prev.cost > cost) out.set(v, { value: v, cost, kind });
  };

  for (let i = 0; i < digits.length; i++) {
    const d = digits[i];
    for (const alt of REVERSE[d] || []) {
      add(digits.slice(0, i) + alt + digits.slice(i + 1), SUBSTITUTION_COST, `sub:${d}->${alt}@${i}`);
    }
    if (digits.length > 1) {
      // OCRが余分な数字を作った場合（例: 13,700 -> 13,7009）
      add(digits.slice(0, i) + digits.slice(i + 1), DELETION_COST, `del:${d}@${i}`);
    }
  }
  // OCRが数字を1つ読み落とした場合（例: 11,400 -> 1,400）。
  // 探索が膨らむため、実際に起きやすい2形だけに絞る:
  //   - 先頭の桁が丸ごと落ちた
  //   - 同じ数字の並びが1つに潰れた（11 -> 1）
  for (let d = 1; d <= 9; d++) {
    add(String(d) + digits, INSERTION_COST, `ins:${d}@0`);
  }
  for (let i = 0; i < digits.length; i++) {
    add(digits.slice(0, i) + digits[i] + digits.slice(i), INSERTION_COST, `dup:${digits[i]}@${i}`);
  }
  // 並び順で補正結果が変わらないよう、常に同じ順序にそろえる（Swift移植版と合わせる）
  return [...out.values()].sort((a, b) => a.cost - b.cost || a.value - b.value);
}

/**
 * sum(sign * value) === 0 になるよう、各項の1桁補正の組み合わせを探索する。
 * @param {Array<{key:string, value:number, sign:number, correctable:boolean, ocrConf:number,
 *                candidateValues?:Array<{value:number, cost:number, kind:string}>}>} terms
 * @param {{maxCorrections?:number}} [options]
 * @returns {{corrections:Array, cost:number}|null}
 */
export function solveDigitErrors(terms, options = {}) {
  const maxCorrections = options.maxCorrections ?? 4;
  const base = terms.reduce((s, t) => s + t.sign * t.value, 0);
  if (base === 0) return { corrections: [], cost: 0 };

  const optionsPerTerm = terms.map((t) => {
    const list = [{ delta: 0, cost: 0, correction: null }];
    if (!t.correctable) return list;
    const cands = t.candidateValues || editCandidates(t.value);
    for (const c of cands) {
      // 読み取り信頼度が低いトークンほど安く直せる
      const confPenalty = 0.6 + 1.4 * Math.min(1, Math.max(0, t.ocrConf ?? 1));
      list.push({
        delta: t.sign * (c.value - t.value),
        cost: c.cost * confPenalty,
        correction: { key: t.key, from: t.value, to: c.value, kind: c.kind },
      });
    }
    return list;
  });

  // 探索量を抑えるため、候補数が多い項を左右へ交互に振り分ける
  const order = optionsPerTerm
    .map((opts, i) => ({ i, n: opts.length }))
    .sort((a, b) => b.n - a.n);
  const groups = [[], []];
  const sizes = [1, 1];
  for (const { i, n } of order) {
    const target = sizes[0] <= sizes[1] ? 0 : 1;
    groups[target].push(i);
    sizes[target] *= n;
  }

  const enumerate = (indexes) => {
    let states = [{ delta: 0, cost: 0, corrections: [] }];
    for (const i of indexes) {
      const next = [];
      for (const state of states) {
        for (const opt of optionsPerTerm[i]) {
          const corrections = opt.correction ? [...state.corrections, opt.correction] : state.corrections;
          if (corrections.length > maxCorrections) continue;
          next.push({ delta: state.delta + opt.delta, cost: state.cost + opt.cost, corrections });
        }
      }
      states = next;
    }
    return states;
  };

  const left = enumerate(groups[0]);
  const right = enumerate(groups[1]);
  const rightByDelta = new Map();
  for (const state of right) {
    const cur = rightByDelta.get(state.delta);
    if (!cur || cur.cost > state.cost) rightByDelta.set(state.delta, state);
  }

  let best = null;
  let runnerUp = null;
  const sameFix = (a, b) =>
    a.length === b.length &&
    a.every((c, i) => c.key === b[i].key && c.to === b[i].to);

  for (const state of left) {
    const need = -(base + state.delta);
    const match = rightByDelta.get(need);
    if (!match) continue;
    const corrections = [...state.corrections, ...match.corrections];
    if (!corrections.length || corrections.length > maxCorrections) continue;
    const cost = state.cost + match.cost + corrections.length * 0.4;
    const candidate = { corrections, cost };
    if (!best || cost < best.cost) {
      if (best && !sameFix(best.corrections, corrections)) runnerUp = best;
      best = candidate;
    } else if ((!runnerUp || cost < runnerUp.cost) && !sameFix(best.corrections, corrections)) {
      runnerUp = candidate;
    }
  }
  if (!best) return null;

  // 同じくらい尤もらしい別解がある場合は「どれを直せばよいか分からない」ので補正しない。
  // 誤って正しい値を書き換える方が、直さないより危険なため。
  const ambiguous = Boolean(runnerUp && runnerUp.cost < best.cost * AMBIGUITY_MARGIN);
  return { ...best, ambiguous, alternativeCost: runnerUp ? runnerUp.cost : null };
}

/**
 * 集計項目（複数行の合算）の補正候補。構成要素のどれか1つを1桁直した合計を返す。
 */
export function aggregateCandidates(parts) {
  const total = parts.reduce((s, p) => s + Math.abs(p.value), 0);
  const out = new Map();
  parts.forEach((part, index) => {
    for (const cand of editCandidates(Math.abs(part.value))) {
      const value = total - Math.abs(part.value) + cand.value;
      if (value < 0) continue;
      const prev = out.get(value);
      const cost = cand.cost;
      if (!prev || prev.cost > cost) out.set(value, { value, cost, kind: `${cand.kind}#${index}` });
    }
  });
  return [...out.values()].sort((a, b) => a.cost - b.cost || a.value - b.value);
}
