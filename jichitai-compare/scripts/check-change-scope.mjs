import { execFileSync } from 'node:child_process';

const baseSha = process.env.SCOPE_BASE_SHA?.trim();
const headSha = process.env.SCOPE_HEAD_SHA?.trim() || 'HEAD';
const allowedWorkflow = '.github/workflows/jichitai-compare.yml';

if (!baseSha || /^0+$/u.test(baseSha)) {
  console.warn('変更範囲検査を省略します: 比較元コミットがありません。');
  process.exit(0);
}

let output;
try {
  output = execFileSync('git', ['diff', '--name-only', baseSha, headSha], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  });
} catch (error) {
  const detail = error.stderr?.toString().trim() || error.message;
  console.error(`変更ファイルを取得できません: ${detail}`);
  process.exit(1);
}

const changedFiles = output
  .split(/\r?\n/u)
  .map((path) => path.trim())
  .filter(Boolean);

const forbiddenFiles = changedFiles.filter((path) => (
  !path.startsWith('jichitai-compare/') && path !== allowedWorkflow
));

if (forbiddenFiles.length > 0) {
  console.error('自治体比較PRに対象外ファイルが含まれています:');
  forbiddenFiles.forEach((path) => console.error(`- ${path}`));
  process.exit(1);
}

console.log(`変更範囲検査に成功しました: ${changedFiles.length}ファイル`);
