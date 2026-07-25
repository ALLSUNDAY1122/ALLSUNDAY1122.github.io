import fs from 'node:fs';
import path from 'node:path';

const projectDir = path.resolve('jichitai-compare');
const today = '2026-07-25';
const replacements = new Map([
  ['https://www.city.osaki.miyagi.jp/shisei/lifescenebetsudesagasu/ninshin_shussan_kosodate/7/2/16068.html', 'https://www.city.osaki.miyagi.jp/shisei/soshikikarasagasu/minseibu/kosodateshienka/3/6/1_1/15981.html'],
  ['https://www.town.zao.miyagi.jp/kurashi_guide/sangyo_kensetsu/nougyou/bousaizyuutameike.html', 'https://www.town.zao.miyagi.jp/kurashi_guide/sangyo_kensetsu/nougyou/bousaizyuutentameike.html'],
  ['https://www.town.miyagi-matsushima.lg.jp/index.cfm/6%2C39792%2Cc%2Chtml/39792/20260324-113052.pdf', 'https://www.town.miyagi-matsushima.lg.jp/uploaded/attachment/5524.pdf'],
  ['https://www.town.taiwa.miyagi.jp/material/files/group/15/sangokea.pdf', 'https://www.town.taiwa.miyagi.jp/material/files/group/15/r7-8sangokeajigyotirasi.pdf'],
  ['https://www.village.ohira.miyagi.jp/soshiki/10/9146.html', 'https://www.village.ohira.miyagi.jp/9/9/148.html'],
  ['https://www.town.kami.miyagi.jp/soshikikarasagasu/kikikanrishitsu/syobobosai/3505.html', 'https://www.town.kami.miyagi.jp/soshikikarasagasu/kikikanrishitsu/syobobosai/hazardmap/3505.html'],
  ['https://www.city.oga.akita.jp/material/files/group/3/06kokuji43.pdf', 'https://www.city.oga.akita.jp/ijuteiju/live/support_R7.html'],
  ['https://www.city.yonezawa.yamagata.jp/kosodate/ninshin_shussan_kenko/5301.html', 'https://www.city.yonezawa.yamagata.jp/soshiki/4/1016/ninshin/1750.html'],
  ['https://www.town.yamanobe.yamagata.jp/soshiki/10/zyuutaku7.html', 'https://www.town.yamanobe.yamagata.jp/uploaded/attachment/8508.pdf']
]);
const removals = new Set([
  'https://www.town.ogawara.miyagi.jp/7788.htm',
  'https://www.town.miyagi-matsushima.lg.jp/index.cfm/6%2C40730%2Cc%2Chtml/40730/20251118-160106.pdf',
  'https://www.town.miyagi-matsushima.lg.jp/index.cfm/7%2C40797%2Cc%2Chtml/40797/matsushima611_A4_compressed.pdf'
]);
const affectedCodes = new Set(['04215','04301','04321','04401','04421','04424','04445','05206','06202','06301']);

function transform(value, parentKey = '') {
  if (Array.isArray(value)) {
    const transformed = value
      .map((item) => transform(item, parentKey))
      .filter((item) => !(item && typeof item === 'object' && typeof item.url === 'string' && removals.has(item.url)));
    if (parentKey === 'additionalSources') {
      const seen = new Set();
      return transformed.filter((item) => {
        const key = item?.url || JSON.stringify(item);
        if (seen.has(key)) return false;
        seen.add(key);
        return true;
      });
    }
    return transformed;
  }
  if (value && typeof value === 'object') {
    const output = {};
    for (const [key, item] of Object.entries(value)) output[key] = transform(item, key);
    if (typeof output.url === 'string' && replacements.has(output.url)) {
      output.url = replacements.get(output.url);
      if ('checkedAt' in output) output.checkedAt = today;
    }
    return output;
  }
  if (typeof value === 'string' && replacements.has(value)) return replacements.get(value);
  return value;
}

function updateJson(file) {
  const originalText = fs.readFileSync(file, 'utf8');
  const original = JSON.parse(originalText);
  const code = String(original.code || original.municipalityCode || path.basename(file, '.json'));
  if (!affectedCodes.has(code)) return false;
  const updated = transform(original);
  if (file.includes(`${path.sep}data${path.sep}municipalities${path.sep}`)) updated.updatedAt = today;
  const nextText = `${JSON.stringify(updated, null, 2)}\n`;
  if (nextText === originalText) return false;
  fs.writeFileSync(file, nextText);
  console.log(`updated ${path.relative(projectDir, file)}`);
  return true;
}

const files = [];
for (const code of affectedCodes) {
  const pref = code.slice(0, 2);
  files.push(path.join(projectDir, 'data', 'municipalities', pref, `${code}.json`));
  files.push(path.join(projectDir, 'operations', 'tasks', `${code}.json`));
}
let changed = 0;
for (const file of files) if (fs.existsSync(file) && updateJson(file)) changed += 1;
if (changed === 0) throw new Error('No URL maintenance changes were applied.');
console.log(`changed files: ${changed}`);
