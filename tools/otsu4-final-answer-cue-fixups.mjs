import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(here, '..');
const bankPath = path.join(repo, 'kikenbutsu-otsu4-sprint', 'questions.generated.json');
const bank = JSON.parse(fs.readFileSync(bankPath, 'utf8'));
const byID = new Map(bank.questions.map(q => [q.id, q]));

const reviewed = {
  P001: [
    '外部点火源を用いず加熱したとき、自ら燃焼を始める最低温度',
    '液体内部から気泡が連続して発生し、沸騰を始める温度',
    '液面上の可燃性蒸気濃度が燃焼上限に達する温度',
    '液体の蒸気圧が標準大気圧の半分に達する温度'
  ],
  P002: [
    '点火源を近づけたとき、蒸気が瞬間的に燃え始める最低温度',
    '液体の蒸気圧が外圧と等しくなり、沸騰を始める温度',
    '可燃性蒸気の濃度が燃焼下限に達する最低濃度そのもの',
    '液体を加熱したとき、蒸発速度が最大になる最低温度'
  ],
  P023: [
    '比熱が小さい物質ほど、同じ質量・温度上昇に多くの熱が必要',
    '比熱が大きい物質ほど、同じ熱量で生じる温度上昇が大きい',
    '比熱が同じなら、質量に関係なく同じ熱量で同じ温度上昇となる',
    '比熱は物質の温度変化には関係せず、蒸発時の潜熱だけを表す'
  ]
};

for (const [id, wrongs] of Object.entries(reviewed)) {
  const q = byID.get(id);
  if (!q) throw new Error(`${id}: missing`);
  const correct = q.choices[q.answer];
  const pool = [correct, ...wrongs];
  if (new Set(pool).size !== 5) throw new Error(`${id}: duplicate reviewed choices`);
  const shift = Number(id.slice(1)) % 5;
  q.choices = pool.slice(shift).concat(pool.slice(0, shift));
  q.answer = q.choices.indexOf(correct);
}

fs.writeFileSync(bankPath, JSON.stringify(bank, null, 2) + '\n');
console.log(JSON.stringify({ ok: true, fixed: Object.keys(reviewed) }, null, 2));
