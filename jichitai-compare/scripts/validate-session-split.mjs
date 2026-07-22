import { readFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const PROJECT_DIR = resolve(SCRIPT_DIR, '..');
const POLICY_PATH = join(PROJECT_DIR, 'operations', 'municipality-assignment-policy.json');
const SPLIT_PATH = join(PROJECT_DIR, 'operations', 'session-split-policy.json');

const policy = JSON.parse(await readFile(POLICY_PATH, 'utf8'));
const split = JSON.parse(await readFile(SPLIT_PATH, 'utf8'));
const sessions = split.sessions ?? [];
const errors = [];

function error(message) {
  errors.push(message);
}

if (policy.sessionSplit?.required !== true) error('municipality-assignment-policy.jsonでsessionSplit.requiredが有効ではありません');
if (split.invocationIntervalMultiplier !== 2) error('invocationIntervalMultiplierは2である必要があります');
if (split.parentIntegrationBranchesRemainShared !== true) error('地方統合ブランチは親地方で共有する必要があります');
if (sessions.length !== 8) error(`セッション数は8件必要です: 実際=${sessions.length}`);

const seenSessionIds = new Set();
let assignedTotal = 0;
let startedTotal = 0;
let uninvestigatedTotal = 0;

for (const session of sessions) {
  if (seenSessionIds.has(session.sessionId)) error(`sessionIdが重複しています: ${session.sessionId}`);
  seenSessionIds.add(session.sessionId);
  assignedTotal += session.assignedMunicipalityCount ?? 0;
  startedTotal += session.startedMunicipalityCountAtSplit ?? 0;
  uninvestigatedTotal += session.uninvestigatedMunicipalityCountAtSplit ?? 0;

  if ((session.startedMunicipalityCountAtSplit ?? 0) + (session.uninvestigatedMunicipalityCountAtSplit ?? 0) !== session.assignedMunicipalityCount) {
    error(`${session.sessionId}: 着手済み数と未調査数の合計が担当総数と一致しません`);
  }

  const checkpoint = JSON.parse(await readFile(join(PROJECT_DIR, session.checkpointFile), 'utf8'));
  if (checkpoint.sessionId !== session.sessionId) error(`${session.sessionId}: checkpointのsessionIdが一致しません`);
  if (checkpoint.parentTeam !== session.parentTeam) error(`${session.sessionId}: checkpointのparentTeamが一致しません`);
  if (checkpoint.integrationBranch !== session.integrationBranch) error(`${session.sessionId}: checkpointのintegrationBranchが一致しません`);
  if (checkpoint.invocationIntervalMultiplier !== 2) error(`${session.sessionId}: checkpointの呼出間隔倍率が2ではありません`);
  if (JSON.stringify(checkpoint.prefectureCodes) !== JSON.stringify(session.prefectureCodes)) {
    error(`${session.sessionId}: checkpointのprefectureCodesが一致しません`);
  }
}

for (const team of policy.teams ?? []) {
  const children = sessions.filter((session) => session.parentTeam === team.team);
  if (children.length !== 2) error(`${team.team}: A/Bの2セッションが必要です`);

  const seenPrefectures = new Set();
  for (const session of children) {
    for (const prefectureCode of session.prefectureCodes ?? []) {
      if (seenPrefectures.has(prefectureCode)) error(`${team.team}: 都道府県コード${prefectureCode}がA/Bで重複しています`);
      seenPrefectures.add(prefectureCode);
    }
  }

  const expected = [...team.prefectureCodes].sort();
  const actual = [...seenPrefectures].sort();
  if (JSON.stringify(expected) !== JSON.stringify(actual)) error(`${team.team}: A/Bの都道府県コードが親調査班を完全に被覆していません`);

  const prefectureCount = new Map((policy.prefectures ?? []).map((prefecture) => [prefecture.prefectureCode, prefecture.assignedMunicipalityCount]));
  for (const session of children) {
    const expectedCount = session.prefectureCodes.reduce((sum, code) => sum + (prefectureCount.get(code) ?? 0), 0);
    if (expectedCount !== session.assignedMunicipalityCount) error(`${session.sessionId}: 担当自治体総数が都道府県別集計と一致しません`);
  }

  const [left, right] = children.map((session) => session.uninvestigatedMunicipalityCountAtSplit);
  if (Math.abs(left - right) > 2) error(`${team.team}: A/Bの未調査数差が2を超えています: ${left}対${right}`);
}

if (assignedTotal !== policy.totalAssignedMunicipalities) error(`8セッションの担当総数が全国総数と一致しません: ${assignedTotal}`);
if (startedTotal !== split.summary?.startedMunicipalityCountAtSplit) error('分割時の着手済み総数がsummaryと一致しません');
if (uninvestigatedTotal !== split.summary?.uninvestigatedMunicipalityCountAtSplit) error('分割時の未調査総数がsummaryと一致しません');
if (assignedTotal !== startedTotal + uninvestigatedTotal) error('全国担当総数が着手済み数と未調査数の合計に一致しません');

if (errors.length > 0) {
  errors.forEach((message) => console.error(`ERROR: ${message}`));
  process.exit(1);
}

console.log(`地方8セッション分割を検証しました: 未調査${uninvestigatedTotal}自治体、親地方内の最大差2自治体`);
