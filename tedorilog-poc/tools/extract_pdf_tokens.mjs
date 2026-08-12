// PDFからテキストトークン（文字列＋座標）を抽出する。
// 本番iOSではPDFKitの同等機能を使う想定。ここでは pdf.js を使い、
// ブラウザPoC UIと同じ抽出ロジック（engine/pdf_tokens.js）を共有する。
//
// 使い方: node tools/extract_pdf_tokens.mjs <input.pdf> [出力.json]
// 何も出力先を渡さない場合は標準出力へJSONを書く。

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export async function extractPdfTokens(pdfPath) {
  const pdfjs = await import('pdfjs-dist/legacy/build/pdf.mjs');
  pdfjs.GlobalWorkerOptions.workerSrc = 'pdfjs-dist/legacy/build/pdf.worker.mjs';
  const data = new Uint8Array(fs.readFileSync(pdfPath));
  const doc = await pdfjs.getDocument({ data, useSystemFonts: false, isEvalSupported: false }).promise;
  const tokens = [];
  let pageCount = doc.numPages;
  for (let p = 1; p <= pageCount; p++) {
    const page = await doc.getPage(p);
    const viewport = page.getViewport({ scale: 1 });
    const content = await page.getTextContent();
    for (const item of content.items) {
      if (!item.str || !item.str.trim()) continue;
      const [a, , , d, e, f] = item.transform;
      const h = item.height || Math.abs(d) || Math.abs(a) || 9;
      const w = item.width || 0;
      tokens.push({
        text: item.str,
        x: e,
        y: viewport.height - f - h, // 左上原点へ変換（yはテキストボックス上端）
        w,
        h,
        page: p,
      });
    }
    page.cleanup();
  }
  await doc.destroy();
  return { tokens, pageCount };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [input, output] = process.argv.slice(2);
  if (!input) {
    console.error('usage: node tools/extract_pdf_tokens.mjs <input.pdf> [output.json]');
    process.exit(1);
  }
  const result = await extractPdfTokens(path.resolve(input));
  const json = JSON.stringify({ source: 'pdf_text', ...result }, null, 2);
  if (output) fs.writeFileSync(path.resolve(output), json);
  else process.stdout.write(json + '\n');
}
