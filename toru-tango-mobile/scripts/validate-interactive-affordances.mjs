import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(import.meta.dirname, '..');
const appDir = path.join(root, 'app');
const uiPath = path.join(root, 'src/components/ui.tsx');
const cardsPath = path.join(appDir, '(tabs)/cards.tsx');

function walk(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return walk(full);
    return /\.(tsx|ts)$/.test(entry.name) ? [full] : [];
  });
}

const failures = [];
for (const file of walk(appDir)) {
  const source = fs.readFileSync(file, 'utf8');
  for (const match of source.matchAll(/<AppButton\b[\s\S]*?\/>/g)) {
    if (!/\bonPress\s*=/.test(match[0])) {
      failures.push(`${path.relative(root, file)}: visible AppButton without onPress`);
    }
  }
}

const ui = fs.readFileSync(uiPath, 'utf8');
if (!/accessibilityLabel=\{accessibilityLabel \?\? label\}/.test(ui)) {
  failures.push('src/components/ui.tsx: AppButton must expose a deterministic accessibility label');
}
if (!/accessibilityState=\{\{ disabled \}\}/.test(ui)) {
  failures.push('src/components/ui.tsx: AppButton must expose disabled accessibility state');
}

const cards = fs.readFileSync(cardsPath, 'utf8');
const required = [
  "import * as Speech from 'expo-speech'",
  'label="🔊 表を読む"',
  'accessibilityLabel="表面を読み上げる"',
  'onPress={() => speak(card.question)}',
  'label="🔊 裏を読む"',
  'accessibilityLabel="裏面を読み上げる"',
  'onPress={() => speak(card.answer)}'
];
for (const token of required) {
  if (!cards.includes(token)) failures.push(`app/(tabs)/cards.tsx: missing regression token ${token}`);
}

if (failures.length) {
  console.error('Interactive affordance regression gate FAILED');
  failures.forEach((failure) => console.error(`- ${failure}`));
  process.exit(1);
}
console.log('Interactive affordance regression gate PASS');
