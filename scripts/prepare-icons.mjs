#!/usr/bin/env node
/**
 * prepare-icons.mjs
 * ---------------------------------------------------------------------------
 * 准备 HarmonyOS 应用图标：
 *   - AppScope/resources/base/media/app_icon.png
 *   - entry/src/main/resources/base/media/app_icon.png
 *
 * 优先从上游 zhihu-- 工程的 assets/images 里拷贝真实图标；
 * 找不到时用纯 Node（zlib + CRC32）现场生成一张纯色 PNG 兜底，
 * 保证 hvigor 资源编译不会因为缺 $media:app_icon 而失败。
 *
 * 环境变量：ZHIHU_SRC（上游工程目录，默认 ../zhihu--）
 * ---------------------------------------------------------------------------
 */
import { existsSync, mkdirSync, copyFileSync, writeFileSync, statSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { deflateSync } from 'node:zlib';

const ROOT = resolve(dirname(new URL(import.meta.url).pathname), '..');
const SRC = resolve(process.env.ZHIHU_SRC || join(ROOT, '..', 'zhihu--'));

const TARGETS = [
  join(ROOT, 'harmony', 'AppScope', 'resources', 'base', 'media', 'app_icon.png'),
  join(ROOT, 'harmony', 'entry', 'src', 'main', 'resources', 'base', 'media', 'app_icon.png'),
];

const CANDIDATES = [
  ['assets', 'images', 'icon.png'],
  ['assets', 'images', 'adaptive-icon.png'],
  ['assets', 'images', 'android-icon-foreground.png'],
  ['assets', 'images', 'splash-logo.png'],
  ['assets', 'images', 'favicon.png'],
];

// ------------------------- PNG 生成（无第三方依赖） -------------------------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const crcBuf = Buffer.alloc(4);
  crcBuf.writeUInt32BE(crc32(Buffer.concat([typeBuf, data])), 0);
  return Buffer.concat([len, typeBuf, data, crcBuf]);
}

/** 生成一张 size×size 的圆角纯色 PNG（品牌蓝 #0084ff，中心留白色圆点） */
function makePng(size, rgb) {
  const raw = Buffer.alloc((size * 4 + 1) * size);
  const radius = Math.round(size * 0.22);
  const cx = size / 2;
  const cy = size / 2;
  const dotR = size * 0.22;

  let p = 0;
  for (let y = 0; y < size; y++) {
    raw[p++] = 0; // filter: None
    for (let x = 0; x < size; x++) {
      // 圆角裁剪
      const dx = Math.min(x, size - 1 - x);
      const dy = Math.min(y, size - 1 - y);
      let inside = true;
      if (dx < radius && dy < radius) {
        const ddx = radius - dx;
        const ddy = radius - dy;
        inside = ddx * ddx + ddy * ddy <= radius * radius;
      }
      // 中心白色圆点（占位标识）
      const ddx2 = x - cx;
      const ddy2 = y - cy;
      const isDot = ddx2 * ddx2 + ddy2 * ddy2 <= dotR * dotR;

      if (!inside) {
        raw[p++] = 0; raw[p++] = 0; raw[p++] = 0; raw[p++] = 0;
      } else if (isDot) {
        raw[p++] = 255; raw[p++] = 255; raw[p++] = 255; raw[p++] = 255;
      } else {
        raw[p++] = rgb[0]; raw[p++] = rgb[1]; raw[p++] = rgb[2]; raw[p++] = 255;
      }
    }
  }

  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0);
  ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // color type RGBA
  ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;

  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// --------------------------------- main -----------------------------------
let source = null;
for (const rel of CANDIDATES) {
  const p = join(SRC, ...rel);
  if (existsSync(p) && statSync(p).size > 0) {
    source = p;
    break;
  }
}

for (const target of TARGETS) {
  mkdirSync(dirname(target), { recursive: true });
  if (source) {
    copyFileSync(source, target);
    console.log(`   ✓ ${target.replace(ROOT + '/', '')}  ← ${source.replace(SRC + '/', '')}`);
  } else {
    writeFileSync(target, makePng(192, [0x00, 0x84, 0xff]));
    console.log(`   ✓ ${target.replace(ROOT + '/', '')}  ← 内置兜底图标（未找到 ${SRC}/assets/images/icon.png）`);
  }
}
