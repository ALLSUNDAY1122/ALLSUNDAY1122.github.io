import fs from 'node:fs';
import path from 'node:path';

const STORIES_DIR = path.resolve(process.cwd(), 'yorugatari', 'stories');
const ATTRIBUTE_PATTERN = /\b(class|id|href|src|rel|name|property|content|type|data-slug|aria-label|aria-hidden|aria-live|aria-busy|aria-expanded|tabindex)=([^\s"'<>`]+)/gi;

function quoteLegacyAttributes(html) {
  return html.replace(/<[^>]+>/g, (tag) => tag.replace(
    ATTRIBUTE_PATTERN,
    (full, name, value) => `${name}="${value}"`
  ));
}

const files = fs.readdirSync(STORIES_DIR)
  .filter((filename) => filename.endsWith('.html'))
  .sort();

if (files.length !== 100) {
  throw new Error(`Expected 100 story pages, found ${files.length}`);
}

let changed = 0;
for (const filename of files) {
  const filePath = path.join(STORIES_DIR, filename);
  const original = fs.readFileSync(filePath, 'utf8');
  const normalized = quoteLegacyAttributes(original);
  if (normalized !== original) {
    fs.writeFileSync(filePath, normalized, 'utf8');
    changed += 1;
  }
}

console.log(`Quoted legacy unquoted attributes in ${changed} of ${files.length} story pages.`);
