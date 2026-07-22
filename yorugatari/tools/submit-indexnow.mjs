import fs from 'node:fs';
import path from 'node:path';

const repoRoot = process.cwd();
const sitemapPath = path.join(repoRoot, 'yorugatari', 'sitemap.xml');
const reportPath = path.join(repoRoot, 'yorugatari-indexnow-report.json');
const host = 'allsunday1122.github.io';
const key = '173baadd8bd18212cc1286c5ae612fce';
const keyLocation = `https://${host}/${key}.txt`;
const endpoint = 'https://api.indexnow.org/indexnow';

function extractUrls() {
  const xml = fs.readFileSync(sitemapPath, 'utf8');
  const urls = Array.from(xml.matchAll(/<loc>([^<]+)<\/loc>/g), (match) => match[1]);
  if (urls.length !== 106) throw new Error(`Expected 106 sitemap URLs, found ${urls.length}`);
  for (const url of urls) {
    const parsed = new URL(url);
    if (parsed.hostname !== host) throw new Error(`URL does not belong to ${host}: ${url}`);
  }
  return urls;
}

async function waitForKey() {
  let detail = null;
  for (let attempt = 1; attempt <= 24; attempt += 1) {
    try {
      const response = await fetch(`${keyLocation}?indexnow=${Date.now()}-${attempt}`, {
        headers: { 'cache-control': 'no-cache', 'user-agent': 'Yorugatari-IndexNow/1.0' }
      });
      const text = (await response.text()).trim();
      detail = { attempt, status: response.status, matches: text === key };
      if (response.status === 200 && text === key) return detail;
    } catch (error) {
      detail = { attempt, error: error.message };
    }
    await new Promise((resolve) => setTimeout(resolve, 10000));
  }
  throw new Error(`Published IndexNow key was not verified: ${JSON.stringify(detail)}`);
}

async function submit(urlList) {
  let last = null;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: {
          'content-type': 'application/json; charset=utf-8',
          'user-agent': 'Yorugatari-IndexNow/1.0'
        },
        body: JSON.stringify({ host, key, keyLocation, urlList })
      });
      const body = await response.text();
      last = { attempt, status: response.status, body: body.slice(0, 500) };
      if (response.status === 200 || response.status === 202) return last;
      if (response.status !== 429 && response.status < 500) break;
    } catch (error) {
      last = { attempt, error: error.message };
    }
    if (attempt < 3) await new Promise((resolve) => setTimeout(resolve, 15000));
  }
  throw new Error(`IndexNow submission failed: ${JSON.stringify(last)}`);
}

const urls = extractUrls();
let report;
try {
  const keyCheck = await waitForKey();
  const submission = await submit(urls);
  report = {
    submittedAt: new Date().toISOString(),
    success: true,
    endpoint,
    host,
    keyLocation,
    urlCount: urls.length,
    keyCheck,
    submission
  };
} catch (error) {
  report = {
    submittedAt: new Date().toISOString(),
    success: false,
    endpoint,
    host,
    keyLocation,
    urlCount: urls.length,
    error: error.message
  };
}

fs.writeFileSync(reportPath, `${JSON.stringify(report, null, 2)}\n`);
console.log(`YORUGATARI_INDEXNOW_REPORT=${JSON.stringify(report)}`);
if (!report.success) process.exit(1);
