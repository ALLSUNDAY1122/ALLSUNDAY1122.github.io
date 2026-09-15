// ブラウザ側のPDFテキスト抽出（同梱pdf.jsを使用、外部通信なし）。
// Node側の tools/extract_pdf_tokens.mjs と同じトークン形式を返す。

const PDFJS_URL = new URL('../vendor/pdfjs/pdf.min.mjs', import.meta.url).href;
const WORKER_URL = new URL('../vendor/pdfjs/pdf.worker.min.mjs', import.meta.url).href;

let pdfjsPromise = null;

async function loadPdfjs() {
  if (!pdfjsPromise) {
    pdfjsPromise = import(PDFJS_URL).then((mod) => {
      mod.GlobalWorkerOptions.workerSrc = WORKER_URL;
      return mod;
    });
  }
  return pdfjsPromise;
}

/**
 * @param {ArrayBuffer} buffer PDFのバイト列
 * @returns {Promise<{tokens:Array, pageCount:number, pages:Array<{width:number,height:number}>, doc:object}>}
 */
export async function extractPdfTokens(buffer) {
  const pdfjs = await loadPdfjs();
  const doc = await pdfjs.getDocument({
    data: new Uint8Array(buffer),
    isEvalSupported: false,
    disableAutoFetch: true,
  }).promise;

  const tokens = [];
  const pages = [];
  for (let p = 1; p <= doc.numPages; p++) {
    const page = await doc.getPage(p);
    const viewport = page.getViewport({ scale: 1 });
    pages.push({ width: viewport.width, height: viewport.height });
    const content = await page.getTextContent();
    for (const item of content.items) {
      if (!item.str || !item.str.trim()) continue;
      const [a, , , d, e, f] = item.transform;
      const h = item.height || Math.abs(d) || Math.abs(a) || 9;
      tokens.push({
        text: item.str,
        x: e,
        y: viewport.height - f - h,
        w: item.width || 0,
        h,
        page: p,
      });
    }
  }
  return { tokens, pageCount: doc.numPages, pages, doc };
}

/** 1ページ目をcanvasへ描画して、原文確認用の画像にする。 */
export async function renderFirstPage(doc, canvas, scale = 1.5) {
  const page = await doc.getPage(1);
  const viewport = page.getViewport({ scale });
  canvas.width = viewport.width;
  canvas.height = viewport.height;
  await page.render({ canvasContext: canvas.getContext('2d'), viewport }).promise;
  return { width: viewport.width, height: viewport.height, scale };
}
