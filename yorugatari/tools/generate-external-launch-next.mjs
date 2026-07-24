import fs from 'node:fs';
import path from 'node:path';

const tools = path.join(process.cwd(), 'yorugatari', 'tools');
const status = JSON.parse(fs.readFileSync(path.join(tools, 'external-launch-status.json'), 'utf8'));
const campaigns = JSON.parse(fs.readFileSync(path.join(tools, 'campaigns.json'), 'utf8'));
const kit = fs.readFileSync(path.join(tools, 'external-launch-kit.md'), 'utf8');
const output = path.join(tools, 'external-launch-next.md');

const nextStatus = status.campaigns.find((row) => row.id === status.nextCampaignId);
const campaign = campaigns.definitions.find((row) => row.id === status.nextCampaignId);
if (!nextStatus || !campaign) throw new Error(`Next campaign is not registered: ${status.nextCampaignId}`);
if (nextStatus.status !== 'ready_not_posted') throw new Error(`Next campaign is not ready_not_posted: ${status.nextCampaignId}`);

const lines = kit.split(/\r?\n/);
const codeLine = lines.findIndex((line) => line.trim() === `\`${campaign.id}\``);
if (codeLine < 0) throw new Error(`Campaign section was not found in external-launch-kit.md: ${campaign.id}`);
let sectionStart = codeLine;
while (sectionStart >= 0 && !lines[sectionStart].startsWith('## ')) sectionStart -= 1;
if (sectionStart < 0) throw new Error(`Campaign heading was not found: ${campaign.id}`);
let sectionEnd = codeLine + 1;
while (sectionEnd < lines.length && !lines[sectionEnd].startsWith('## ')) sectionEnd += 1;
const section = lines.slice(sectionStart, sectionEnd);

const copyHeading = section.findIndex((line) => /^### (投稿文|送信用文面)$/.test(line.trim()));
const urlHeading = section.findIndex((line) => line.trim() === '### 計測用URL');
if (copyHeading < 0 || urlHeading < 0 || urlHeading <= copyHeading) throw new Error(`Post copy or URL heading is missing: ${campaign.id}`);
const postCopy = section.slice(copyHeading + 1, urlHeading).join('\n').trim();
const sectionUrl = section.slice(urlHeading + 1).find((line) => /^https:\/\//.test(line.trim()))?.trim();
if (!postCopy || !sectionUrl) throw new Error(`Post copy or URL is empty: ${campaign.id}`);
if (sectionUrl !== campaign.url) throw new Error(`Campaign URL mismatch for ${campaign.id}`);

const platformValidation = {
  platform: campaign.source,
  postCharacters: Array.from(postCopy).length,
  urlCharactersUsedForEstimate: campaign.source === 'x' ? 23 : Array.from(campaign.url).length,
  estimatedTotalCharacters: null,
  maximumCharacters: campaign.source === 'x' ? 280 : null,
  valid: true
};
platformValidation.estimatedTotalCharacters = platformValidation.postCharacters + 1 + platformValidation.urlCharactersUsedForEstimate;
if (platformValidation.maximumCharacters && platformValidation.estimatedTotalCharacters > platformValidation.maximumCharacters) {
  platformValidation.valid = false;
  throw new Error(`Post exceeds ${campaign.source} length estimate: ${platformValidation.estimatedTotalCharacters}/${platformValidation.maximumCharacters}`);
}

const now = new Date();
const generatedAtJapan = new Intl.DateTimeFormat('ja-JP', {
  timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit',
  hour: '2-digit', minute: '2-digit', hour12: false
}).format(now);

const lengthLine = platformValidation.maximumCharacters
  ? `推定文字数：${platformValidation.estimatedTotalCharacters}／${platformValidation.maximumCharacters}（URLは23文字換算）  `
  : `本文文字数：${platformValidation.postCharacters}  `;
const markdown = `# 夜語り 次の外部投稿\n\n生成日時（日本時間）：${generatedAtJapan}  \n状態：未投稿  \n優先順位：${nextStatus.priority}  \n媒体：${campaign.source}  \n${lengthLine}\n\n## 投稿文\n\n${postCopy}\n\n## 追跡URL\n\n${campaign.url}\n\n## 計測コード\n\n\`${campaign.id}\`\n\n## 投稿後に記録する項目\n\n投稿を実際に完了した場合だけ、\`external-launch-status.json\` の該当行を次のように更新する。\n\n- \`status\`: \`published\`\n- \`publishedAt\`: 実際の投稿日時\n- \`postUrl\`: 公開された投稿URL\n- \`nextCampaignId\`: 次の \`ready_not_posted\` キャンペーン\n\n投稿していない段階では、これらを変更しない。\n`;

fs.writeFileSync(output, markdown, 'utf8');
console.log(`Generated ${path.relative(process.cwd(), output)} for ${campaign.id}: ${JSON.stringify(platformValidation)}`);
