(() => {
  'use strict';

  const originalFetch = window.fetch.bind(window);
  const TARGET_TRANSACTIONS = 100;

  const industrialSeeds = [
    ['材料費','材料200,000円を掛けで購入した。','材料','買掛金','資産である材料が増加するため借方です。','負債である買掛金が増加するため貸方です。','材料 200,000 ／ 買掛金 200,000'],
    ['材料費','直接材料150,000円を製造工程へ払い出した。','仕掛品','材料','製造中の製品原価である仕掛品が増加するため借方です。','材料を消費したため材料が減少し貸方です。','仕掛品 150,000 ／ 材料 150,000'],
    ['材料費','間接材料30,000円を製造工程へ払い出した。','製造間接費','材料','間接材料費を製造間接費として集計するため借方です。','材料を消費したため材料が減少し貸方です。','製造間接費 30,000 ／ 材料 30,000'],
    ['労務費','工員の賃金180,000円を現金で支払った。','賃金','現金','賃金勘定が増加するため借方です。','現金が減少するため貸方です。','賃金 180,000 ／ 現金 180,000'],
    ['労務費','直接工の直接作業賃金120,000円を仕掛品へ振り替えた。','仕掛品','賃金','直接労務費を仕掛品へ集計するため借方です。','賃金勘定から振り替えるため貸方です。','仕掛品 120,000 ／ 賃金 120,000'],
    ['労務費','間接作業賃金40,000円を製造間接費へ振り替えた。','製造間接費','賃金','間接労務費を製造間接費へ集計するため借方です。','賃金勘定から振り替えるため貸方です。','製造間接費 40,000 ／ 賃金 40,000'],
    ['経費','工場の電力料25,000円を普通預金から支払った。','製造間接費','普通預金','工場経費を製造間接費へ集計するため借方です。','普通預金が減少するため貸方です。','製造間接費 25,000 ／ 普通預金 25,000'],
    ['製造間接費','製造間接費300,000円を予定配賦した。','仕掛品','製造間接費','予定配賦額を仕掛品へ加算するため借方です。','製造間接費を仕掛品へ配賦するため貸方です。','仕掛品 300,000 ／ 製造間接費 300,000'],
    ['製造間接費','製造間接費の実際発生額が予定配賦額を20,000円上回った。','製造間接費配賦差異','製造間接費','不利差異を配賦差異勘定の借方に計上します。','製造間接費勘定を締め切るため貸方です。','製造間接費配賦差異 20,000 ／ 製造間接費 20,000'],
    ['完成品','完成した製品500,000円を倉庫へ振り替えた。','製品','仕掛品','完成品原価を製品へ振り替えるため借方です。','仕掛品が完成したため仕掛品を減額し貸方です。','製品 500,000 ／ 仕掛品 500,000'],
    ['売上原価','製品原価320,000円の商品を500,000円で掛け販売した。','売掛金','売上','売掛金が増加するため借方です。','売上が発生するため貸方です。','売掛金 500,000 ／ 売上 500,000'],
    ['売上原価','掛け販売した製品の原価320,000円を売上原価へ振り替えた。','売上原価','製品','販売した製品原価を費用へ振り替えるため借方です。','製品が減少するため貸方です。','売上原価 320,000 ／ 製品 320,000'],
    ['個別原価計算','仕損品の評価額10,000円を材料として回収した。','材料','仕掛品','回収材料が増加するため借方です。','仕掛品原価を減額するため貸方です。','材料 10,000 ／ 仕掛品 10,000'],
    ['本社工場会計','工場が本社から材料250,000円を受け入れた。','材料','本社','工場側で材料が増加するため借方です。','本社に対する内部勘定を貸方に計上します。','材料 250,000 ／ 本社 250,000'],
    ['本社工場会計','本社が工場へ現金100,000円を送金した。','工場','現金','本社側で工場勘定を増額するため借方です。','現金が減少するため貸方です。','工場 100,000 ／ 現金 100,000'],
    ['標準原価計算','材料消費価格差異15,000円の不利差異を計上した。','材料消費価格差異','材料','不利差異を借方に計上します。','材料勘定を標準価格へ調整するため貸方です。','材料消費価格差異 15,000 ／ 材料 15,000'],
    ['標準原価計算','材料消費数量差異12,000円の不利差異を計上した。','材料消費数量差異','材料','不利差異を借方に計上します。','材料勘定を標準消費量へ調整するため貸方です。','材料消費数量差異 12,000 ／ 材料 12,000'],
    ['標準原価計算','賃率差異8,000円の有利差異を計上した。','賃金','賃率差異','実際賃金を標準額へ調整するため賃金を借方に計上します。','有利差異を貸方に計上します。','賃金 8,000 ／ 賃率差異 8,000'],
    ['標準原価計算','作業時間差異9,000円の不利差異を計上した。','作業時間差異','賃金','不利差異を借方に計上します。','賃金勘定を標準作業時間へ調整するため貸方です。','作業時間差異 9,000 ／ 賃金 9,000'],
    ['月末仕掛品','月末に未完成の製品原価140,000円を仕掛品として翌月へ繰り越した。','次月繰越','仕掛品','仕掛品勘定を締め切るため次月繰越を借方に記入します。','月末仕掛品を翌月へ繰り越すため貸方です。','次月繰越 140,000 ／ 仕掛品 140,000']
  ].map(([c,t,d,k,de,ce,j]) => ({ g: 2, s: 'industrial', c, t, d, k, de, ce, j }));

  function scale(token, variant) {
    const value = Number(token.replace(/,/g, ''));
    if (!Number.isFinite(value) || value <= 0) return token;
    const factor = 1 + ((variant % 11) + 1) * 0.08;
    const unit = value >= 10000 ? 1000 : value >= 1000 ? 100 : value >= 100 ? 10 : 1;
    return (Math.max(unit, Math.round(value * factor / unit) * unit)).toLocaleString('ja-JP');
  }
  const vary = (text, variant) => String(text).replace(/\d{1,3}(?:,\d{3})+|\d+/g, token => scale(token, variant));
  const variant = (row, i) => ({ ...row, t: vary(row.t, i), j: vary(row.j, i), variant: i });
  function expand(source, track) {
    if (!source.length) return [];
    const result = source.map(row => ({ ...row, s: track }));
    let i = 1;
    while (result.length < TARGET_TRANSACTIONS) {
      result.push(variant({ ...source[(result.length - source.length) % source.length], s: track }, i++));
    }
    return result.slice(0, TARGET_TRANSACTIONS);
  }

  window.fetch = async function (input, init) {
    const url = typeof input === 'string' ? input : input?.url || '';
    const response = await originalFetch(input, init);
    if (!url.includes('data/questions.json') || !response.ok) return response;
    try {
      const payload = await response.clone().json();
      const rows = Array.isArray(payload.transactions) ? payload.transactions : [];
      const grade3 = rows.filter(row => Number(row.g) === 3);
      const commercial = rows.filter(row => Number(row.g) === 2).map(row => ({ ...row, s: 'commercial' }));
      const transactions = [...expand(grade3, 'grade3'), ...expand(commercial, 'commercial'), ...expand(industrialSeeds, 'industrial')];
      return new Response(JSON.stringify({ ...payload, version: '3.0.0', generated: true, cardsPerTrack: 200, transactions }), {
        status: response.status, statusText: response.statusText, headers: { 'Content-Type': 'application/json; charset=utf-8' }
      });
    } catch (error) {
      console.error('問題バンクの拡張に失敗しました。', error);
      return response;
    }
  };
})();