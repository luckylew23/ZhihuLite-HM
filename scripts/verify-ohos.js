#!/usr/bin/env node
/**
 * verify-ohos.js —— HMOS 转换层的回归自检脚本
 * ----------------------------------------------------------------------------
 * 用法： node scripts/verify-ohos.js
 *
 * 做三件事（全部只读，不改动任何文件）：
 *   A. 垫片 API 契约审计：每个垫片的导出 是否覆盖 源码里实际调用的 API
 *   B. Metro 别名层校验：别名目标文件是否存在、平台模块是否都被覆盖、'@/' 前缀能否解析
 *   C. 关键垫片行为测试：crypto(MD5/SHA-256 对照 Node crypto) 与 CookieManager(复刻登录合并流程)
 *
 * C 部分需要把 TS 垫片编译到临时目录后执行，依赖项目的 typescript（devDependency）。
 */
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const SHIM_DIR = path.join(ROOT, 'platform/ohos/shims');

let pass = 0, fail = 0;
const assert = (label, cond, extra) => {
  if (cond) pass++;
  else { fail++; console.log('  ✗ ' + label + (extra ? '  -> ' + extra : '')); }
};

// 与 metro.config.js 保持一致的别名表
const ALIASES = {
  'expo-secure-store': 'expoSecureStore.ts',
  'expo-crypto': 'expoCrypto.ts',
  'expo-clipboard': 'expoClipboard.ts',
  'expo-file-system': 'expoFileSystem.ts',
  'expo-file-system/legacy': 'expoFileSystemLegacy.ts',
  'expo-linking': 'expoLinking.ts',
  'expo-web-browser': 'expoWebBrowser.ts',
  'expo-sharing': 'expoSharing.ts',
  'expo-intent-launcher': 'expoIntentLauncher.ts',
  'expo-haptics': 'expoHaptics.ts',
  'expo-blur': 'expoBlur.tsx',
  'expo-linear-gradient': 'expoLinearGradient.tsx',
  'expo-status-bar': 'expoStatusBar.tsx',
  'expo-screen-orientation': 'expoScreenOrientation.ts',
  'expo-splash-screen': 'expoSplashScreen.ts',
  'expo-constants': 'expoConstants.ts',
  'expo-sqlite': 'expoSqlite.ts',
  'expo-media-library': 'expoMediaLibrary.ts',
  '@react-native-cookies/cookies': 'reactNativeCookies.ts',
  'react-native-root-siblings': 'reactNativeRootSiblings.tsx',
  'expo-router': 'expoRouter.tsx',
  'expo-router/html': 'expoRouterHtml.tsx',
  'expo-router/entry': 'expoRouterEntry.tsx',
};

const SRC_DIRS = ['app', 'components', 'store', 'api', 'utils', 'constants', 'hooks', 'storage'];

function collectSources() {
  const files = [];
  const walk = (dir) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) walk(p);
      else if (/\.(ts|tsx)$/.test(e.name)) files.push(p);
    }
  };
  for (const d of SRC_DIRS) {
    const abs = path.join(ROOT, d);
    if (fs.existsSync(abs)) walk(abs);
  }
  return files;
}

function shimExports(file) {
  const src = fs.readFileSync(file, 'utf8');
  const names = new Set();
  let m;
  const re = /export\s+(?:async\s+)?(?:function|const|let|var|class|enum|interface|type)\s+([A-Za-z0-9_$]+)/g;
  while ((m = re.exec(src))) names.add(m[1]);
  if (/export\s+default/.test(src)) names.add('default');
  const hasStar = /export\s+\*/.test(src);
  const re2 = /export\s*\{([^}]+)\}/g;
  while ((m = re2.exec(src))) {
    m[1].split(',').forEach((s) => {
      const n = s.trim().split(/\s+as\s+/).pop().trim();
      if (n) names.add(n);
    });
  }
  return { names, hasStar };
}

// ---------------- A. 垫片 API 契约审计 ----------------
function auditShims(sources) {
  console.log('A. 垫片 API 契约审计');
  const usage = {};
  for (const k of Object.keys(ALIASES)) usage[k] = new Set();

  for (const file of sources) {
    const src = fs.readFileSync(file, 'utf8');
    for (const mod of Object.keys(ALIASES)) {
      const esc = mod.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      const reNamed = new RegExp("import\\s*\\{([^}]+)\\}\\s*from\\s*['\"]" + esc + "['\"]", 'g');
      let mn;
      while ((mn = reNamed.exec(src))) {
        mn[1].split(',').forEach((s) => {
          const n = s.trim().split(/\s+as\s+/)[0].trim().replace(/^type\s+/, '');
          if (n) usage[mod].add(n);
        });
      }
      const re = new RegExp(
        "import\\s+(?:\\*\\s+as\\s+([A-Za-z0-9_$]+)|([A-Za-z0-9_$]+)\\s*(?:,|from)\\s*(?:\\{[^}]*\\}\\s*)?)?from\\s*['\"]" + esc + "['\"]", 'g');
      let m, ns = null;
      while ((m = re.exec(src))) { ns = m[1] || m[2] || null; }
      if (ns) {
        const reUse = new RegExp('\\b' + ns + '\\.([A-Za-z0-9_$]+)', 'g');
        let mu;
        while ((mu = reUse.exec(src))) usage[mod].add(mu[1]);
        usage[mod].add('default');
      }
    }
  }

  for (const mod of Object.keys(ALIASES)) {
    const file = path.join(SHIM_DIR, ALIASES[mod]);
    assert(mod + ' 垫片文件存在', fs.existsSync(file));
    if (!fs.existsSync(file)) continue;
    const { names, hasStar } = shimExports(file);
    const missing = [...usage[mod]].filter(
      (u) => !names.has(u) && !hasStar && !names.has('default'));
    assert(mod + ' API 完整', missing.length === 0, missing.join(', '));
  }
}

// ---------------- B. Metro 别名层校验 ----------------
function auditMetro(sources) {
  console.log('B. Metro 别名层校验');
  process.env.HMOS_BUILD = '1';
  const config = require(path.join(ROOT, 'metro.config.js'));
  const ohosDeps = require(path.join(ROOT, 'package.ohos.json')).dependencies || {};

  const ctx = { resolveRequest: (_c, name) => ({ resolvedTo: name }) };
  const resolve = (m) => config.resolver.resolveRequest(ctx, m, 'harmony').resolvedTo;

  for (const [mod, shimFile] of Object.entries(ALIASES)) {
    const target = resolve(mod);
    assert(mod + ' 已映射', target !== mod);
    assert(mod + ' 目标存在', fs.existsSync(target), target.replace(ROOT, '<root>'));
  }

  const atTarget = resolve('@/store/useAuthStore');
  assert("'@/*' 前缀解析", atTarget === path.join(ROOT, 'store/useAuthStore'), atTarget);

  // 源码里出现的所有平台模块都必须被覆盖（垫片 或 已声明的 npm 包）
  const mods = new Set();
  for (const file of sources) {
    const src = fs.readFileSync(file, 'utf8');
    const re = /from\s+['"]([^'"]+)['"]/g;
    let m;
    while ((m = re.exec(src))) {
      const n = m[1];
      if (/^(expo|@expo\/|@react-native|react-native$)/.test(n)) mods.add(n);
    }
  }
  for (const n of mods) {
    if (n === 'react-native') continue; // 标准包，RNOH 在原生层接管
    const mapped = resolve(n) !== n;
    const pkg = n.startsWith('@') ? n.split('/').slice(0, 2).join('/') : n.split('/')[0];
    assert(n + ' 已覆盖(垫片或 npm 包)', mapped || !!ohosDeps[pkg]);
  }
  delete process.env.HMOS_BUILD;
}

// ---------------- C. 关键垫片行为测试 ----------------
function testShimBehaviour() {
  console.log('C. 关键垫片行为测试');
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zhihu-ohos-'));
  const tsc = path.join(ROOT, 'node_modules/typescript/bin/tsc');
  const files = [
    path.join(SHIM_DIR, 'cryptoImpl.ts'),
    path.join(SHIM_DIR, 'expoCrypto.ts'),
    path.join(SHIM_DIR, '_kv.ts'),
    path.join(SHIM_DIR, 'reactNativeCookies.ts'),
  ];
  try {
    execFileSync(process.execPath, [tsc, ...files, '--outDir', tmp,
      '--module', 'commonjs', '--target', 'es2017', '--esModuleInterop', '--skipLibCheck'],
      { cwd: ROOT, stdio: 'pipe' });
  } catch (e) {
    console.log('  ✗ 编译垫片失败:\n' + e.stdout);
    fail++;
    return;
  }

  // C1. crypto：对照 Node 原生 crypto
  const nodeCrypto = require('crypto');
  const { digest } = require(path.join(tmp, 'cryptoImpl.js'));
  const cases = ['', 'a', 'abc', '知乎--', 'x-zse-96|101_3_3.0', 'a'.repeat(55), 'a'.repeat(56),
    'a'.repeat(63), 'a'.repeat(64), 'a'.repeat(65), 'a'.repeat(119), 'a'.repeat(120), 'a'.repeat(1000)];
  for (const algo of ['MD5', 'SHA-256']) {
    const ref = (s) => nodeCrypto.createHash(algo === 'MD5' ? 'md5' : 'sha256').update(s, 'utf8').digest('hex');
    for (const c of cases) {
      assert(algo + ' 一致 (' + (c.length > 12 ? c.length + ' chars' : JSON.stringify(c)) + ')',
        (() => { try { return digest(algo, c) === ref(c); } catch { return false; } })());
    }
  }

  // C2. CookieManager：复刻 app/login/index.tsx 的合并流程
  const CookieManager = require(path.join(tmp, 'reactNativeCookies.js')).default;
  return (async () => {
    await CookieManager.clearAll(true);
    await CookieManager.set('https://www.zhihu.com', { name: 'z_c0', value: 'ZCO', domain: '.zhihu.com', path: '/' }, true);
    await CookieManager.set('https://www.zhihu.com', { name: 'd_c0', value: 'DCO', domain: '.zhihu.com', path: '/' }, true);

    const cookies = await CookieManager.get('https://www.zhihu.com', true);
    const merged = {};
    '_xsrf=XSRF; _zap=ZAP'.split(';').forEach((p) => {
      const [n, ...v] = p.trim().split('=');
      if (n) merged[n] = v.join('=');
    });
    Object.values(cookies).forEach((c) => { merged[c.name] = c.value; });

    assert('登录判定 z_c0 可检出', merged.z_c0 === 'ZCO', JSON.stringify(merged));
    assert('签名依赖 d_c0 可检出', merged.d_c0 === 'DCO');
    assert('未污染出 name/domain 伪键', !('name' in merged) && !('domain' in merged));
  })();
}

// ---------------- main ----------------
(async () => {
  const sources = collectSources();
  console.log('扫描源码文件: ' + sources.length + ' 个\n');
  auditShims(sources);
  auditMetro(sources);
  await testShimBehaviour();
  console.log('\n' + '='.repeat(60));
  console.log(fail === 0
    ? '✅ 全部通过：' + pass + ' 项检查'
    : '❌ ' + fail + ' 项失败 / 共 ' + (pass + fail) + ' 项');
  console.log('='.repeat(60));
  process.exit(fail ? 1 : 0);
})();
