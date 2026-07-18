import { execFileSync } from 'node:child_process';

const baseSha = process.env.SCOPE_BASE_SHA?.trim();
const headSha = process.env.SCOPE_HEAD_SHA?.trim() || 'HEAD';
const allowedWorkflow = '.github/workflows/jichitai-compare.yml';

if (!baseSha || /^0+$/u.test(baseSha)) {
  console.warn('変更範囲検査を省略します: 比較元コミットがありません。');
  process.exit(0);
}

function runGit(args, failureMessage) {
  try {
    return execFileSync('git', args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe']
    }).trim();
  } catch (error) {
    const detail = error.stderr?.toString().trim() || error.message;
    console.error(`${failureMessage}: ${detail}`);
    process.exit(1);
  }
}

const mergeBase = runGit(
  ['merge-base', baseSha, headSha],
  '比較元と作業ブランチの共通祖先を取得できません'
);
const output = runGit(
  ['diff', '--name-only', mergeBase, headSha],
  '変更ファイルを取得できません'
);

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

console.log(`変更範囲検査に成功しました: ${changedFiles.length}ファイル（共通祖先 ${mergeBase}）`);
