#!/usr/bin/env bash
# ============================================================================
# link-hvigor-plugin.sh — 把 DevEco 自带的 @ohos/hvigor* 软链进 harmony/node_modules
# ============================================================================
# hvigorfile.ts 里 `import { appTasks } from '@ohos/hvigor-ohos-plugin'` 走的是
# **Node CommonJS 解析**（hvigor 的 require-hook 只注册 .ts / .mjs，且不看 oh_modules）。
# 命令行直接跑 hvigorw 时经常解析不到，于是把 DevEco 自带的那份软链到项目
# node_modules 下即可。该目录已被 .gitignore 忽略。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"

if [ ! -d "$DEVECO_HOME" ]; then
  echo "❌ 未找到 DevEco Studio（$DEVECO_HOME）。" >&2
  exit 1
fi

DEST="$ROOT/harmony/node_modules/@ohos"
mkdir -p "$DEST"

link_one() {
  local name="$1"
  if [ -e "$DEST/$name" ]; then
    echo "   ✓ @ohos/$name 已存在 → $(readlink "$DEST/$name" 2>/dev/null || echo '（实体目录）')"
    return 0
  fi
  for cand in \
    "$DEVECO_HOME/tools/hvigor/node_modules/@ohos/$name" \
    "$DEVECO_HOME/tools/hvigor/$name" \
    "$DEVECO_HOME/tools/ohpm/node_modules/@ohos/$name"
  do
    if [ -d "$cand" ]; then
      ln -s "$cand" "$DEST/$name"
      echo "   ✓ 已软链 @ohos/$name → $cand"
      return 0
    fi
  done
  echo "   ⚠️  未找到 @ohos/$name（hvigor 可能仍能自行解析，继续）"
  return 0
}

echo "🔗 准备 hvigor 插件软链 …"
link_one hvigor
link_one hvigor-ohos-plugin
