#!/usr/bin/env node
/**
 * build-ohos-bundle.js —— 生成 HarmonyOS 平台的 JS bundle
 * ----------------------------------------------------------------------------
 * 用法：
 *   node scripts/build-ohos-bundle.js                 # 生产包（minify, dev=false）
 *   node scripts/build-ohos-bundle.js --dev           # 调试包（含红屏/热更新能力）
 *   node scripts/build-ohos-bundle.js --reset-cache   # 清 Metro 缓存后打包
 *
 * 产物：
 *   harmony/entry/src/main/resources/rawfile/bundle.harmony.js       ← JS bundle
 *   harmony/entry/src/main/resources/rawfile/bundle.harmony.js.map   ← sourcemap
 *   harmony/entry/src/main/resources/rawfile/assets/                 ← 图片/字体等资源
 *
 * 为什么是这个路径与文件名：
 *   RNOH 的 ResourceJSBundleProvider 默认 `path = 'bundle.harmony.js'`，
 *   通过 rawfile 资源目录加载（见 harmony/oh_modules/@rnoh/react-native-openharmony
 *   /src/main/ets/RNOH/JSBundleProvider.ts:134）。修改文件名需同步改 EntryAbility。
 */
const path = require('path');
const fs = require('fs');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const ENTRY = path.join(ROOT, 'ohos', 'index.tsx');
const RAWFILE = path.join(ROOT, 'harmony', 'entry', 'src', 'main', 'resources', 'rawfile');
const OUT = path.join(RAWFILE, 'bundle.harmony.js');

const dev = process.argv.includes('--dev');
const resetCache = process.argv.includes('--reset-cache');

if (!fs.existsSync(ENTRY)) {
  console.error('✗ 找不到入口文件: ' + ENTRY);
  process.exit(1);
}

fs.mkdirSync(RAWFILE, { recursive: true });

const metroBin = path.join(ROOT, 'node_modules', '.bin', 'metro');
if (!fs.existsSync(metroBin)) {
  console.error('✗ 找不到 Metro CLI: ' + metroBin + '  （请先 npm install）');
  process.exit(1);
}

// 注意：Metro 0.83 的 CLI 已改为 `metro build <entry>`，且移除了 --assets-dest。
// 入口为位置参数，输出用 -O/--out，平台用 -p/--platform。
const args = [
  'build', ENTRY,
  '--config', path.join(ROOT, 'metro.config.js'),
  '--platform', 'harmony',
  '--dev', dev ? 'true' : 'false',
  '--minify', dev ? 'false' : 'true',
  '--out', OUT,
  '--source-map',
  '--source-map-url', 'bundle.harmony.js.map',
];
if (resetCache) args.push('--reset-cache');

console.log('📦 构建 HarmonyOS bundle');
console.log('   入口 : ' + path.relative(ROOT, ENTRY));
console.log('   产物 : ' + path.relative(ROOT, OUT));
console.log('   模式 : ' + (dev ? 'dev' : 'release') + '\n');

const res = spawnSync(metroBin, args, {
  stdio: 'inherit',
  cwd: ROOT,
  env: { ...process.env, HMOS_BUILD: '1' },
});

if (res.status !== 0) {
  console.error('\n✗ bundle 构建失败');
  process.exit(res.status ?? 1);
}

// ---------------------------------------------------------------------------
// 资源(assets)输出
// Metro 0.83 的 `build` 命令已不再输出资源（无 --assets-dest，legacy-bundler 同样不输出）。
// 因此这里解析 bundle 里的 registerAsset 记录，把资源拷到 rawfile。
//
// 路径约定（与 RNOH 对齐）：
//   RNOH 的 RAWFILE_PREFIX = "resource://RAWFILE/assets/"（见 ImageCacheUriUtil.cpp），
//   即 asset://X → rawfile/assets/X。
//   Metro 生成的 httpServerLocation = "/assets/" + dirname(相对项目根路径)，
//   所以 destination = rawfile + httpServerLocation 正好落在 rawfile/assets/<相对路径>。
// ---------------------------------------------------------------------------
function emitAssets() {
  if (!fs.existsSync(OUT)) return { copied: 0, missing: 0 };
  const code = fs.readFileSync(OUT, 'utf8');
  const re = /registerAsset\(\{([^}]*)\}\)/g;
  let m;
  let copied = 0;
  let missing = 0;

  while ((m = re.exec(code))) {
    const body = m[1];
    const str = (key) => {
      const mm = body.match(new RegExp(key + ':\\s*"([^"]*)"'));
      return mm ? mm[1] : null;
    };
    const loc = str('httpServerLocation');
    const name = str('name');
    const type = str('type');
    if (!loc || !name || !type) continue;

    const scalesRaw = body.match(/scales:\s*\[([^\]]*)\]/);
    const scales = scalesRaw
      ? [...new Set(scalesRaw[1].split(',').map((s) => s.trim()).filter(Boolean))]
      : ['1'];

    const relDir = loc.replace(/^\/assets\//, '').replace(/^\/+/, '');
    const srcDir = path.join(ROOT, relDir);
    const dstDir = path.join(RAWFILE, loc.replace(/^\/+/, ''));

    for (const s of scales) {
      const suffix = s === '1' || s === '1e0' ? '' : '@' + s + 'x';
      const file = name + suffix + '.' + type;
      const src = path.join(srcDir, file);
      const dst = path.join(dstDir, file);
      if (fs.existsSync(src)) {
        fs.mkdirSync(path.dirname(dst), { recursive: true });
        fs.copyFileSync(src, dst);
        copied++;
      } else {
        missing++;
      }
    }
  }
  return { copied, missing };
}

const assets = emitAssets();

const size = fs.existsSync(OUT) ? (fs.statSync(OUT).size / 1024 / 1024).toFixed(2) : '?';
console.log('\n✅ bundle 生成成功：' + path.relative(ROOT, OUT) + '  (' + size + ' MB)');
console.log('   资源文件：已拷贝 ' + assets.copied + ' 个' + (assets.missing ? '，缺失 ' + assets.missing + ' 个' : ''));
console.log('   下一步：用 DevEco Studio 打开 harmony/ 工程，签名后运行到鸿蒙设备。');
