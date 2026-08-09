import { cp, mkdir, rm, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const appRoot = resolve(here, '..');
const sourceFull = resolve(appRoot, 'full');
const out = resolve(here, 'www');
const outFull = resolve(out, 'full');

await rm(out, { recursive: true, force: true });
await mkdir(outFull, { recursive: true });

const fullFiles = [
  'index.html',
  'style.css',
  'app.js',
  'patch-2140.js',
  'iap-v1.js',
  'sw.js',
  'manifest.json'
];

for (const file of fullFiles) {
  await cp(resolve(sourceFull, file), resolve(outFull, file));
}

for (let i = 0; i < 6; i++) {
  await cp(resolve(appRoot, `q${i}.txt`), resolve(out, `q${i}.txt`));
}

await writeFile(resolve(out, 'index.html'), `<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>情報処理安全確保支援士</title></head><body><script>location.replace('./full/');</script><noscript><a href="./full/">アプリを開く</a></noscript></body></html>\n`);

console.log('Prepared bundled offline web assets in native/www');
