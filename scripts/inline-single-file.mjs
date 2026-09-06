#!/usr/bin/env node
/**
 * inline-single-file.mjs
 * ---------------------------------------------------------------------------
 * 把 Expo Web 静态导出目录（默认 ../zhihu--/dist-web）内联成**单个** index.html，
 * 供 ArkWeb 通过 `Web({ src: $rawfile('index.html') })` 加载。
 *
 * 为什么必须单文件：
 *   $rawfile 的文档源是 `resource://rawfile/...`。该 scheme 下 **ES module**
 *   子资源（<script type="module">、<link rel="modulepreload">）会被 CORS 拒绝，
 *   分包 .js / .css / 字体 / 图片也可能因跨 scheme 取不到 → 页面白屏。
 *   因此把 JS / CSS / 字体 / 图片全部内联，并把 module 脚本降级为普通 IIFE 脚本。
 *
 * 用法：
 *   node scripts/inline-single-file.mjs [输入目录] [输出文件]
 *   环境变量 QUIET=1 关闭进度输出
 * ---------------------------------------------------------------------------
 */
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { dirname, resolve, extname, join } from 'node:path';

const QUIET = process.env.QUIET === '1';

const MIME = {
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.css': 'text/css',
  '.json': 'application/json',
  '.html': 'text/html',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.eot': 'application/vnd.ms-fontobject',
  '.mp3': 'audio/mpeg',
  '.mp4': 'video/mp4',
  '.wasm': 'application/wasm',
};

const INLINE_BINARY_LIMIT = 8 * 1024 * 1024; // 单个二进制资源内联上限

const log = [];
const warn = [];
function info(msg) {
  if (!QUIET) console.log(msg);
}

function mimeOf(file) {
  return MIME[extname(file).toLowerCase()] || 'application/octet-stream';
}

function dataUri(file) {
  const buf = readFileSync(file);
  if (buf.length > INLINE_BINARY_LIMIT) {
    warn.push(`资源过大(${buf.length}B)，跳过内联：${file}`);
    return null;
  }
  return `data:${mimeOf(file)};base64,${buf.toString('base64')}`;
}

function human(n) {
  if (n < 1024) return `${n}B`;
  if (n < 1024 * 1024) return `${(n / 1024).toFixed(1)}KB`;
  return `${(n / 1024 / 1024).toFixed(2)}MB`;
}

function isLocalUrl(u) {
  if (!u) return false;
  return !/^(https?:)?\/\//i.test(u) && !/^(data|blob|mailto|tel|javascript|about):/i.test(u) && !u.startsWith('#');
}

/** 站点绝对路径 '/a/b' 相对输入根目录解析；相对路径相对当前文件解析 */
function resolveRef(currentDir, rootDir, u) {
  const clean = u.split('?')[0].split('#')[0];
  if (clean.startsWith('/')) return resolve(rootDir, '.' + clean);
  return resolve(currentDir, clean);
}

/** 把 CSS 里的 url() 全部换成 data URI */
function inlineCssUrls(css, cssDir, rootDir) {
  return css.replace(/url\(\s*(['"]?)([^)'"]+?)\1\s*\)/gi, (m, _q, u) => {
    if (!isLocalUrl(u)) return m;
    const p = resolveRef(cssDir, rootDir, u);
    if (!existsSync(p) || !statSync(p).isFile()) {
      warn.push(`CSS 引用的资源不存在：${u}`);
      return m;
    }
    const d = dataUri(p);
    return d ? `url("${d}")` : m;
  });
}

/** 去掉 type="module" / nomodule / crossorigin（内联脚本不需要，module 还会触发 CORS） */
function cleanScriptAttrs(attrs) {
  return attrs
    .replace(/\s*type\s*=\s*["']module["']/gi, '')
    .replace(/\s*nomodule\b/gi, '')
    .replace(/\s*crossorigin(\s*=\s*["'][^"']*["'])?/gi, '')
    .replace(/\s*async\b/gi, '')
    .replace(/\s*defer\b/gi, '');
}

const HEAD_SHIM = `<script>
/* ---- HMOS ArkWeb shim（由 scripts/inline-single-file.mjs 注入）---- */
(function () {
  'use strict';
  window.__HMOS__ = true;

  // $rawfile('index.html') 会让文档 URL 变成 resource://rawfile/index.html，
  // 首屏 pathname 带 /index.html —— expo-router 会把它当成未知路由而白屏。
  // 在业务脚本执行之前把 URL 规范化回 '/'.
  try {
    if (window.history && window.history.replaceState &&
        /\\/index\\.html$/i.test(window.location.pathname)) {
      window.history.replaceState(window.history.state || null, '', '/');
    }
  } catch (e) {
    try { console.warn('[hmos-shim] replaceState failed', e); } catch (_) {}
  }

  // 屏上错误面板：WebView 里看不到 devtools，未捕获错误直接糊在页面上，便于定位白屏
  function showError(title, detail) {
    try {
      var box = document.getElementById('__hmos_error__');
      if (!box) {
        box = document.createElement('pre');
        box.id = '__hmos_error__';
        box.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:2147483647;' +
          'max-height:45%;overflow:auto;margin:0;padding:10px;white-space:pre-wrap;' +
          'word-break:break-all;background:#330000;color:#ff9c9c;font:12px/1.5 monospace;';
        (document.body || document.documentElement).appendChild(box);
      }
      box.textContent += '\\n\\n### ' + title + '\\n' + detail;
    } catch (_) {}
  }
  window.__hmosShowError = showError;
  window.addEventListener('error', function (ev) {
    showError('window.error', (ev && ev.message ? ev.message : '') +
      (ev && ev.filename ? '\\n  at ' + ev.filename + ':' + ev.lineno + ':' + ev.colno : ''));
  });
  window.addEventListener('unhandledrejection', function (ev) {
    showError('unhandledrejection', String(ev && ev.reason ? (ev.reason.stack || ev.reason) : ev));
  });
})();
</script>`;

function processHtml(htmlPath, rootDir) {
  const dir = dirname(htmlPath);
  let html = readFileSync(htmlPath, 'utf8');
  const originalSize = Buffer.byteLength(html);

  // ---------- 1) <link> ----------
  html = html.replace(/<link\b[^>]*>/gi, (tag) => {
    const rel = (tag.match(/rel\s*=\s*["']([^"']+)["']/i) || [])[1] || '';
    const href = (tag.match(/href\s*=\s*["']([^"']+)["']/i) || [])[1];

    if (/stylesheet/i.test(rel)) {
      if (!href || !isLocalUrl(href)) return '';
      const p = resolveRef(dir, rootDir, href);
      if (!existsSync(p)) { warn.push(`缺少 CSS：${href}`); return ''; }
      const css = inlineCssUrls(readFileSync(p, 'utf8'), dirname(p), rootDir);
      log.push(`CSS  ${href}  (${human(Buffer.byteLength(css))})`);
      return `<style>${css}</style>`;
    }

    if (/icon|apple-touch-icon|mask-icon/i.test(rel)) {
      if (!href || !isLocalUrl(href)) return '';
      const p = resolveRef(dir, rootDir, href);
      if (!existsSync(p)) return '';
      const d = dataUri(p);
      return d ? `<link rel="icon" href="${d}">` : '';
    }

    // preload / modulepreload / prefetch / manifest：单文件模式下无意义，且
    // modulepreload 会触发 CORS 失败，必须移除。
    if (/preload|prefetch|manifest|dns-prefetch|preconnect/i.test(rel)) return '';

    return tag;
  });

  // ---------- 2) <script> ----------
  html = html.replace(/<script\b([^>]*)>([\s\S]*?)<\/script>/gi, (_m, attrs, body) => {
    const src = (attrs.match(/src\s*=\s*["']([^"']+)["']/i) || [])[1];
    if (!src) {
      return `<script${cleanScriptAttrs(attrs)}>${body}</script>`;
    }
    if (!isLocalUrl(src)) return `<script${cleanScriptAttrs(attrs.replace(/\s*src\s*=\s*["'][^"']*["']/i, ''))} src="${src}"></script>`;
    const p = resolveRef(dir, rootDir, src);
    if (!existsSync(p)) { warn.push(`缺少 JS：${src}`); return ''; }
    const js = readFileSync(p, 'utf8');
    log.push(`JS   ${src}  (${human(Buffer.byteLength(js))})`);
    return `<script${cleanScriptAttrs(attrs.replace(/\s*src\s*=\s*["'][^"']*["']/i, ''))}>\n${js}\n</script>`;
  });

  // ---------- 3) <img> / <source> / <video poster> / <audio> ----------
  html = html.replace(/<(img|source|video|audio)\b([^>]*)>/gi, (_m, tagName, attrs) => {
    const attrName = tagName === 'video' ? 'poster' : 'src';
    const re = new RegExp(`${attrName}\\s*=\\s*["']([^"']+)["']`, 'i');
    const m = attrs.match(re);
    if (!m || !isLocalUrl(m[1])) return `<${tagName}${attrs}>`;
    const p = resolveRef(dir, rootDir, m[1]);
    if (!existsSync(p)) return `<${tagName}${attrs}>`;
    const d = dataUri(p);
    if (!d) return `<${tagName}${attrs}>`;
    return `<${tagName}${attrs.replace(re, `${attrName}="${d}"`)}>`;
  });

  // ---------- 4) 注入 head shim ----------
  if (/<head\b[^>]*>/i.test(html)) {
    html = html.replace(/<head\b[^>]*>/i, (m) => `${m}\n${HEAD_SHIM}`);
  } else if (/<html\b[^>]*>/i.test(html)) {
    html = html.replace(/<html\b[^>]*>/i, (m) => `${m}\n<head>\n${HEAD_SHIM}\n</head>`);
  } else {
    html = `${HEAD_SHIM}\n${html}`;
  }

  return { html, originalSize };
}

/** 自检：不允许残留任何本地子资源引用 / module 脚本 */
function selfCheck(html) {
  const problems = [];

  const localRefs = [];
  const refRe = /(?:src|href)\s*=\s*["']([^"']+)["']/gi;
  let m;
  while ((m = refRe.exec(html)) !== null) {
    if (isLocalUrl(m[1])) localRefs.push(m[1]);
  }
  if (localRefs.length) {
    problems.push(`仍存在 ${localRefs.length} 处本地子资源引用，前 10 个：\n    ` +
      [...new Set(localRefs)].slice(0, 10).join('\n    '));
  }

  const openScripts = (html.match(/<script\b/gi) || []).length;
  const closeScripts = (html.match(/<\/script>/gi) || []).length;
  if (openScripts !== closeScripts) {
    problems.push(
      `script 标签不配平：开标签 ${openScripts} 个 / 闭标签 ${closeScripts} 个。` +
      `若内联的 JS 字符串里含有 "</script>" 字面量会提前截断，需先做 <\\/script 转义`);
  }

  if (/type\s*=\s*["']module["']/i.test(html)) {
    problems.push('仍存在 type="module" 脚本（resource:// 下会被 CORS 拒绝）');
  }
  if (/rel\s*=\s*["']modulepreload["']/i.test(html)) {
    problems.push('仍存在 <link rel="modulepreload">');
  }

  return problems;
}

function main() {
  const inputDir = resolve(process.argv[2] || '../zhihu--/dist-web');
  const outputFile = resolve(process.argv[3] || 'harmony/entry/src/main/resources/rawfile/index.html');

  const htmlPath = join(inputDir, 'index.html');
  if (!existsSync(htmlPath)) {
    console.error(`❌ 找不到 ${htmlPath}\n   请先运行 expo export --platform web`);
    process.exit(1);
  }

  info(`📥 输入目录：${inputDir}`);
  const { html, originalSize } = processHtml(htmlPath, inputDir);

  log.sort();
  log.forEach((l) => info(`   ✓ ${l}`));

  const outSize = Buffer.byteLength(html);
  info(`\n📦 内联完成：${human(originalSize)} → ${human(outSize)}`);

  const problems = selfCheck(html);
  if (problems.length) {
    console.error('\n❌ 自检未通过：');
    problems.forEach((p) => console.error(`   - ${p}`));
    console.error('\n   这些残留会导致 ArkWeb 白屏，请修复后再打包。');
    process.exit(2);
  }
  info('✅ 自检通过：零本地子资源引用、零 type="module"');

  if (warn.length) {
    console.warn('\n⚠️  警告：');
    [...new Set(warn)].slice(0, 20).forEach((w) => console.warn(`   - ${w}`));
  }

  writeFileSync(outputFile, html, 'utf8');
  info(`\n💾 已写入：${outputFile} (${human(outSize)})`);
}

main();
