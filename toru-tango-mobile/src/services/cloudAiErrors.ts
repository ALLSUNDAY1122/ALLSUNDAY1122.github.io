export function cloudAiErrorMessage(status: number, payload: Record<string,unknown>):string {
  const code=String(payload.code ?? '');
  if(status===429 && code==='AI_MONTHLY_LIMIT') {
    const usage=payload.usage as Record<string,unknown>|undefined;
    const limit=Number(usage?.limit)||5;
    const tier=String(usage?.tier ?? 'free');
    return tier==='free'
      ? '今月の無料回数（5回）を使い切りました。プランで追加利用できます。（AI_MONTHLY_LIMIT）'
      : `今月の利用上限（${limit}回）に達しました。次の更新期間までお待ちください。（AI_MONTHLY_LIMIT）`;
  }
  if(status===401)return '購入情報を確認できませんでした。プラン画面から購入状態を確認してください。（AUTH）';
  if(code.startsWith('GEMINI_UPSTREAM_HTTP_')) return `Gemini側で一時的なエラーが発生しました。（${code}）`;
  return typeof payload.error==='string'?payload.error:`AI通信に失敗しました。（HTTP ${status}）`;
}
