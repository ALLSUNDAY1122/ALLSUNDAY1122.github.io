(() => {
  'use strict';

  const originalFetch = window.fetch.bind(window);
  const TARGET_TRANSACTIONS_PER_GRADE = 100;

  function scaleNumberToken(token, variantIndex) {
    const value = Number(token.replace(/,/g, ''));
    if (!Number.isFinite(value) || value <= 0) return token;

    const factor = 1 + ((variantIndex % 9) + 1) * 0.1;
    const unit = value >= 10000 ? 1000 : value >= 1000 ? 100 : value >= 100 ? 10 : 1;
    const scaled = Math.max(unit, Math.round((value * factor) / unit) * unit);
    return scaled.toLocaleString('ja-JP');
  }

  function varyAmounts(text, variantIndex) {
    return String(text).replace(/\d{1,3}(?:,\d{3})+|\d+/g, token => scaleNumberToken(token, variantIndex));
  }

  function makeVariant(row, variantIndex) {
    return {
      ...row,
      t: varyAmounts(row.t, variantIndex),
      j: varyAmounts(row.j, variantIndex),
      variant: variantIndex,
    };
  }

  function expandGrade(rows, grade) {
    const source = rows.filter(row => Number(row.g) === grade);
    if (!source.length) return [];

    const expanded = source.map(row => ({ ...row }));
    let variantIndex = 1;

    while (expanded.length < TARGET_TRANSACTIONS_PER_GRADE) {
      const sourceRow = source[(expanded.length - source.length) % source.length];
      expanded.push(makeVariant(sourceRow, variantIndex));
      variantIndex += 1;
    }

    return expanded.slice(0, TARGET_TRANSACTIONS_PER_GRADE);
  }

  window.fetch = async function expandedQuestionFetch(input, init) {
    const url = typeof input === 'string' ? input : input?.url || '';
    const response = await originalFetch(input, init);

    if (!url.includes('data/questions.json') || !response.ok) return response;

    try {
      const payload = await response.clone().json();
      const rows = Array.isArray(payload.transactions) ? payload.transactions : [];
      const transactions = [
        ...expandGrade(rows, 3),
        ...expandGrade(rows, 2),
      ];

      const body = JSON.stringify({
        ...payload,
        version: '2.0.0',
        generated: true,
        cardsPerGrade: TARGET_TRANSACTIONS_PER_GRADE * 2,
        transactions,
      });

      return new Response(body, {
        status: response.status,
        statusText: response.statusText,
        headers: { 'Content-Type': 'application/json; charset=utf-8' },
      });
    } catch (error) {
      console.error('問題バンクの拡張に失敗しました。', error);
      return response;
    }
  };
})();
