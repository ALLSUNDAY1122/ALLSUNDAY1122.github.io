const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');

const WIDTH = 1024;
const HEIGHT = 1024;
const pixels = Buffer.alloc(WIDTH * HEIGHT * 3);

function setPixel(x, y, color) {
  if (x < 0 || y < 0 || x >= WIDTH || y >= HEIGHT) return;
  const offset = (y * WIDTH + x) * 3;
  pixels[offset] = color[0];
  pixels[offset + 1] = color[1];
  pixels[offset + 2] = color[2];
}

function fill(color) {
  for (let offset = 0; offset < pixels.length; offset += 3) {
    pixels[offset] = color[0];
    pixels[offset + 1] = color[1];
    pixels[offset + 2] = color[2];
  }
}

function fillCircle(cx, cy, radius, color) {
  const radiusSquared = radius * radius;
  for (let y = Math.max(0, cy - radius); y <= Math.min(HEIGHT - 1, cy + radius); y += 1) {
    const dy = y - cy;
    const span = Math.floor(Math.sqrt(radiusSquared - dy * dy));
    for (let x = Math.max(0, cx - span); x <= Math.min(WIDTH - 1, cx + span); x += 1) {
      setPixel(x, y, color);
    }
  }
}

function fillRoundedRect(left, top, right, bottom, radius, color) {
  const width = right - left;
  const height = bottom - top;
  const safeRadius = Math.min(radius, Math.floor(width / 2), Math.floor(height / 2));
  const radiusSquared = safeRadius * safeRadius;

  for (let y = top; y <= bottom; y += 1) {
    for (let x = left; x <= right; x += 1) {
      const nearestX = Math.max(left + safeRadius, Math.min(x, right - safeRadius));
      const nearestY = Math.max(top + safeRadius, Math.min(y, bottom - safeRadius));
      const dx = x - nearestX;
      const dy = y - nearestY;
      if (dx * dx + dy * dy <= radiusSquared) setPixel(x, y, color);
    }
  }
}

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let value = n;
    for (let bit = 0; bit < 8; bit += 1) {
      value = (value & 1) ? (0xedb88320 ^ (value >>> 1)) : (value >>> 1);
    }
    table[n] = value >>> 0;
  }
  return table;
})();

function crc32(buffer) {
  let crc = 0xffffffff;
  for (const byte of buffer) crc = CRC_TABLE[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function pngChunk(type, data) {
  const typeBuffer = Buffer.from(type, 'ascii');
  const payload = Buffer.concat([typeBuffer, data]);
  const chunk = Buffer.alloc(12 + data.length);
  chunk.writeUInt32BE(data.length, 0);
  typeBuffer.copy(chunk, 4);
  data.copy(chunk, 8);
  chunk.writeUInt32BE(crc32(payload), 8 + data.length);
  return chunk;
}

function encodePng() {
  const scanlines = Buffer.alloc(HEIGHT * (1 + WIDTH * 3));
  const rowBytes = WIDTH * 3;
  for (let y = 0; y < HEIGHT; y += 1) {
    const targetOffset = y * (rowBytes + 1);
    scanlines[targetOffset] = 0;
    pixels.copy(scanlines, targetOffset + 1, y * rowBytes, (y + 1) * rowBytes);
  }

  const header = Buffer.alloc(13);
  header.writeUInt32BE(WIDTH, 0);
  header.writeUInt32BE(HEIGHT, 4);
  header[8] = 8;
  header[9] = 2;
  header[10] = 0;
  header[11] = 0;
  header[12] = 0;

  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk('IHDR', header),
    pngChunk('IDAT', zlib.deflateSync(scanlines, { level: 9 })),
    pngChunk('IEND', Buffer.alloc(0)),
  ]);
}

const indigo = [74, 62, 210];
const paleIndigo = [207, 220, 255];
const white = [255, 255, 255];
const cameraPurple = [85, 72, 210];
const lensDark = [45, 38, 135];
const lensBlue = [102, 177, 255];
const lensHighlight = [220, 242, 255];
const violet = [124, 58, 237];

fill(indigo);
fillRoundedRect(205, 220, 785, 800, 94, paleIndigo);
fillRoundedRect(258, 268, 840, 840, 96, white);
fillRoundedRect(424, 312, 616, 390, 32, cameraPurple);
fillCircle(549, 523, 171, cameraPurple);
fillCircle(549, 523, 115, lensDark);
fillCircle(549, 523, 69, lensBlue);
fillCircle(549, 523, 39, lensHighlight);
fillRoundedRect(678, 356, 750, 428, 22, violet);
fillRoundedRect(368, 726, 730, 760, 17, cameraPurple);
fillRoundedRect(422, 782, 678, 812, 15, violet);

const outputPath = path.join(__dirname, '..', 'assets', 'icon.png');
fs.mkdirSync(path.dirname(outputPath), { recursive: true });
const png = encodePng();
fs.writeFileSync(outputPath, png);
console.log(`Generated opaque ${WIDTH}x${HEIGHT} app icon: ${outputPath} (${png.length} bytes)`);
