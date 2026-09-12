#!/usr/bin/env bash
# ============================================================================
# build-web.sh — 构建 Expo Web 产物并内联为单文件 index.html，放进 rawfile
# ============================================================================
# 流程：
#   [1/3] 在 ZHIHU_SRC（默认 ../zhihu--）里跑
#           expo export --platform web --output-dir dist-web
#   [2/3] scripts/prepare-icons.mjs 准备应用图标
#   [3/3] scripts/inline-single-file.mjs 内联成单个 index.html，写入 rawfile
#
# 环境变量：
#   ZHIHU_SRC            上游 Expo/RN 工程目录（默认 ../zhihu--）
#   NODE_BIN             node 所在目录（默认 WorkBuddy 托管 22.22.2；Metro 需 Node ≥ 20.19）
#   EXPO_EXPORT_FLAGS    透传给 expo export 的附加参数（默认空）
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

ZHIHU_SRC="${ZHIHU_SRC:-$ROOT/../zhihu--}"
ZHIHU_SRC="$(cd "$ZHIHU_SRC" && pwd)"

NODE_BIN="${NODE_BIN:-/Users/admin/.workbuddy-ai/binaries/node/versions/22.22.2/bin}"
if [ -d "$NODE_BIN" ]; then
  export PATH="$NODE_BIN:$PATH"
fi

DIST="$ZHIHU_SRC/dist-web"
RAWFILE_DIR="$ROOT/harmony/entry/src/main/resources/rawfile"
OUT="$RAWFILE_DIR/index.html"

echo "🌐 zhihu--HMOS — Web 产物构建"
echo "   上游工程 : $ZHIHU_SRC"
echo "   输出目录 : $DIST"
echo "   node     : $(node -v)"

if [ ! -x "$ZHIHU_SRC/node_modules/.bin/expo" ]; then
  echo "❌ 上游工程缺少 expo（$ZHIHU_SRC/node_modules/.bin/expo）。请先 npm install。" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# 导出期间的临时改动（脚本退出时自动还原，上游工程最终保持原样）
#
#   1) metro.config.js -> scripts/metro.web.config.js
#      web 平台下把 react-native-pager-view 解析到库自带的 index.web.js。
#      否则其 main/module 指向 native-only 实现，会 import
#      react-native/Libraries/Utilities/codegenNativeCommands，
#      Metro 直接报 "Importing native-only module ... on web" 而打包失败。
#      该覆盖仅在 platform==='web' 生效，Android/iOS 解析不变。
#
#   2) 临时移走 app/index.tsx
#      该路由只有一个 <Redirect href="/(tabs)"/>。在 ArkWeb 的 resource://
#      水合场景下这个重定向不生效，App 会停在只有导航栏标题 "index" 的空壳，
#      真机表现为「启动一片白屏，只有上方 index 一个词」。
#      移走后 '/' 直接解析到 app/(tabs)/index.tsx，首屏即真正首页。
# ---------------------------------------------------------------------------
export HMOS_ROOT="$ROOT"   # metro.web.config.js 用它定位 platform/web/shims/*
METRO_SRC="$ROOT/scripts/metro.web.config.js"
METRO_DST="$ZHIHU_SRC/metro.config.js"
METRO_BAK=""
INDEX_SRC="$ZHIHU_SRC/app/index.tsx"
INDEX_BAK="$ZHIHU_SRC/app/index.tsx.hmos-bak"

restore_all() {
  if [ -n "${METRO_BAK:-}" ] && [ -f "$METRO_BAK" ]; then
    cp "$METRO_BAK" "$METRO_DST"
    rm -f "$METRO_BAK"
  fi
  if [ -f "$INDEX_BAK" ]; then
    mv "$INDEX_BAK" "$INDEX_SRC"
  fi
  return 0
}
trap restore_all EXIT INT TERM

if [ -f "$METRO_SRC" ]; then
  METRO_BAK="$(mktemp "${TMPDIR:-/tmp}/zhihu-metro.XXXXXX")"
  cp "$METRO_DST" "$METRO_BAK"
  cp "$METRO_SRC" "$METRO_DST"
  echo "   ✓ 临时启用 Web 专用 metro 配置（导出后还原）"
fi

if [ -f "$INDEX_SRC" ]; then
  mv "$INDEX_SRC" "$INDEX_BAK"
  echo "   ✓ 临时移走 app/index.tsx（避免卡在重定向空壳，导出后还原）"
fi

run_export() {
  ( cd "$ZHIHU_SRC" && CI=1 NODE_OPTIONS=--max-old-space-size=8192 \
      ./node_modules/.bin/expo export --platform web --output-dir dist-web "$@" )
}

echo ""
echo "▶ [1/3] Expo Web 静态导出 …"
if [ -n "${EXPO_EXPORT_FLAGS:-}" ]; then
  # 显式指定了附加参数：只跑一次，失败就直接报错
  run_export $EXPO_EXPORT_FLAGS
else
  if ! run_export; then
    echo ""
    echo "⚠️  默认参数导出失败，尝试降级参数重跑："
    ok=0
    for flags in "--no-ssg" "--no-minify"; do
      echo "    → expo export --platform web --output-dir dist-web $flags"
      if run_export "$flags"; then
        echo "    ✅ 降级参数 $flags 导出成功"
        ok=1
        break
      fi
    done
    if [ "$ok" != "1" ]; then
      echo "❌ Expo Web 导出失败。请在 $ZHIHU_SRC 手动复现该错误。" >&2
      echo "   常见原因：业务代码直接使用了 expo-secure-store / expo-sqlite /" >&2
      echo "   expo-media-library 等没有 Web 实现的模块，静态渲染(SSG) 阶段就崩。" >&2
      echo "   可尝试：EXPO_EXPORT_FLAGS=--no-ssg bash scripts/build-web.sh" >&2
      exit 1
    fi
  fi
fi

echo ""
echo "▶ [2/3] 准备应用图标 …"
ZHIHU_SRC="$ZHIHU_SRC" node "$ROOT/scripts/prepare-icons.mjs"

echo ""
echo "▶ [3/3] 内联为单文件 HTML …"
mkdir -p "$RAWFILE_DIR"
node "$ROOT/scripts/inline-single-file.mjs" "$DIST" "$OUT"

echo ""
echo "🎉 完成：$OUT"
ls -lh "$OUT"
