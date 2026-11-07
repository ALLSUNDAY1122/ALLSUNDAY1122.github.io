// 保存ガード。
// PoCの最重要ルール「認識値をユーザー確認なしで確定保存しない」をコードで保証する層。
// UIはこの関数を通してしか保存データを作れない。

import { ITEM_KEYS, ITEM_LABELS } from './lexicon.js';
import { STATUS } from './extract.js';

/**
 * @param {object} result extractPayslip の結果
 * @param {Record<string, {value:number|null, confirmed:boolean, edited?:boolean}>} confirmations
 *        画面Bでユーザーが確認・修正した内容
 * @returns {{ok:boolean, blocked:Array<{key:string,label:string,reason:string}>, payload:object|null}}
 */
export function buildSaveDraft(result, confirmations = {}) {
  const blocked = [];
  const entries = {};

  for (const key of ITEM_KEYS) {
    const item = (result && result.items && result.items[key]) || null;
    const input = confirmations[key];
    const suggested = item ? item.value : null;
    const value = !input || input.value === undefined ? null : input.value;
    const confirmed = Boolean(input && input.confirmed);

    if (value === null || value === undefined) {
      if (suggested !== null && !confirmed) {
        // 候補があるのに確認されていない = 画面Bを通っていない。保存させない。
        blocked.push({
          key,
          label: ITEM_LABELS[key],
          reason: '解析候補が未確認です。確認するか、未設定に戻してください',
        });
        continue;
      }
      // 未検出のまま、または明示的に未設定へ戻した場合は空欄で保存できる
      entries[key] = { key, label: ITEM_LABELS[key], value: null, source: 'empty' };
      continue;
    }
    if (!Number.isFinite(value)) {
      blocked.push({ key, label: ITEM_LABELS[key], reason: '数値ではありません' });
      continue;
    }
    if (!confirmed) {
      blocked.push({
        key,
        label: ITEM_LABELS[key],
        reason: item && item.status === STATUS.CONFIRMED_CANDIDATE
          ? '確定候補でも、ユーザー確認なしには保存できません'
          : '要確認の項目です。内容を確認してください',
      });
      continue;
    }
    const edited = input.edited !== undefined ? Boolean(input.edited) : value !== suggested;
    entries[key] = {
      key,
      label: ITEM_LABELS[key],
      value,
      source: edited ? 'user_edited' : 'user_confirmed',
      suggested,
    };
  }

  if (blocked.length) return { ok: false, blocked, payload: null };

  return {
    ok: true,
    blocked: [],
    payload: {
      items: entries,
      route: result ? result.route : null,
      confirmedAt: new Date().toISOString(),
      // 解析メタ情報のみ保持し、明細画像・原文テキストは保存しない
      meta: result
        ? { tokenCount: result.stats.tokenCount, checks: result.checks.map((c) => ({ id: c.id, ok: c.ok })) }
        : null,
    },
  };
}
