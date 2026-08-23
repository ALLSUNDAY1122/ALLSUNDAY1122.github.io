// vendor/pdfjs を node_modules から更新する。
// PoC UIはCDNを一切使わない（明細を扱う画面で外部リクエストを発生させないため）。
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const SRC = path.join(ROOT, 'node_modules', 'pdfjs-dist', 'build');
const DEST = path.join(ROOT, 'vendor', 'pdfjs');

fs.mkdirSync(DEST, { recursive: true });
for (const file of ['pdf.min.mjs', 'pdf.worker.min.mjs']) {
  fs.copyFileSync(path.join(SRC, file), path.join(DEST, file));
  console.log(`copied ${file}`);
}
const version = JSON.parse(
  fs.readFileSync(path.join(ROOT, 'node_modules', 'pdfjs-dist', 'package.json'), 'utf8'),
).version;
fs.writeFileSync(
  path.join(DEST, 'README.txt'),
  `pdf.js ${version} (Apache-2.0) を同梱している理由: 明細PDFの解析中に外部CDNへ一切リクエストしないため。\n更新方法: npm install && node tools/vendor_pdfjs.mjs\n`,
);
console.log(`pdfjs-dist ${version}`);
