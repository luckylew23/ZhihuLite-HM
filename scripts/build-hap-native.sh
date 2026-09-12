#!/usr/bin/env bash
# ============================================================================
# build-hap-native.sh — 构建并自签 harmony-native（方案 B 原生应用）
# 用法: ./scripts/build-hap-native.sh [debug|release]
# 产物: harmony-native/entry/build/default/outputs/default/zhihu--hmos-native-*.hap
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NATIVE="$ROOT/harmony-native"
MODE="${1:-release}"

DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
if [ ! -d "$DEVECO_HOME" ]; then
  echo "❌ 未找到 DevEco Studio（$DEVECO_HOME）。" >&2
  exit 1
fi

export JAVA_HOME="$DEVECO_HOME/jbr/Contents/Home"
export PATH="$JAVA_HOME/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/node/bin:$PATH"

# hvigor 插件软链（首次或缺失时）
if [ ! -e "$NATIVE/node_modules/@ohos/hvigor" ]; then
  mkdir -p "$NATIVE/node_modules/@ohos"
  for name in hvigor hvigor-ohos-plugin; do
    for cand in \
      "$DEVECO_HOME/tools/hvigor/node_modules/@ohos/$name" \
      "$DEVECO_HOME/tools/hvigor/$name" \
      "$DEVECO_HOME/tools/ohpm/node_modules/@ohos/$name"
    do
      if [ -d "$cand" ]; then
        ln -s "$cand" "$NATIVE/node_modules/@ohos/$name"
        break
      fi
    done
  done
fi

echo "🔨 assembleHap ($MODE) …"
cd "$NATIVE"
bash ./hvigorw assembleHap --mode module -p product=default -p buildMode="$MODE" --no-daemon

echo "✍️  自签 …"
bash signing/sign.sh

echo "✅ 产物: $NATIVE/entry/build/default/outputs/default/ZhihuLite-HM-signed.hap"
