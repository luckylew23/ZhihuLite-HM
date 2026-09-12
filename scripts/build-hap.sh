#!/usr/bin/env bash
# ============================================================================
# build-hap.sh — hvigor 打包 ArkTS 壳 → 本地自签 → 产出可安装 .hap
# ============================================================================
# 用法: scripts/build-hap.sh [debug|release]
#
# 本工程是**纯 ArkTS WebView 壳**：没有 RNOH、没有 C++ 原生库，
# 所以 assembleHap 只做 ArkTS 编译 + 资源打包，秒级完成
# （对照：RNOH 方案的 har 内含 boost/folly/glog/libevent 全量源码，
#   assembleHap 会触发一次完整 CMake 原生构建，数十分钟级）。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-release}"

DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
if [ ! -d "$DEVECO_HOME" ]; then
  echo "❌ 未找到 DevEco Studio（$DEVECO_HOME）。请设置 DEVECO_HOME。" >&2
  exit 1
fi

export JAVA_HOME="${JAVA_HOME:-$DEVECO_HOME/jbr/Contents/Home}"
export PATH="$JAVA_HOME/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/node/bin:$PATH"

RAWFILE="$ROOT/harmony/entry/src/main/resources/rawfile/index.html"
if [ ! -f "$RAWFILE" ]; then
  echo "❌ 缺少 $RAWFILE —— 请先运行 scripts/build-web.sh" >&2
  exit 1
fi
echo "📄 rawfile: $RAWFILE ($(du -h "$RAWFILE" | cut -f1 | tr -d ' '))"

echo ""
echo "▶ [1/2] assembleHap (mode=$MODE) …"

# 清掉 RNOH 遗留的 ArkTS 文件。它们 import '@rnoh/react-native-openharmony'，
# 而该依赖已从 oh-package.json5 移除，留着会让 ArkTS 编译直接失败。
ETS_DIR="$ROOT/harmony/entry/src/main/ets"
for f in "$ETS_DIR/EntryAbility.ts" "$ETS_DIR/MyAbilityStage.ts" "$ETS_DIR/RNPackages.ts"; do
  [ -f "$f" ] && mv "$f" /tmp/ 2>/dev/null || true
done

# 只剩公开证书、没有私钥(p12) 的残缺签名物料会让签发失败，一并清掉重新生成。
if [ -d "$ROOT/harmony/signing" ] && [ ! -f "$ROOT/harmony/signing/oh-ca.p12" ]; then
  echo "🧹 清理残缺的签名物料（只有 .cer 没有 .p12）"
  for f in "$ROOT/harmony/signing"/*.cer "$ROOT/harmony/signing"/debug-profile.json "$ROOT/harmony/signing"/verify-*; do
    [ -f "$f" ] && mv "$f" /tmp/ 2>/dev/null || true
  done
fi

# hvigorfile.ts 的 `import { appTasks } from '@ohos/hvigor-ohos-plugin'` 走 Node CJS 解析，
# 命令行下常常解析不到 → 先软链 DevEco 自带的那份（幂等）。
bash "$ROOT/scripts/link-hvigor-plugin.sh"

cd "$ROOT/harmony"
chmod +x ./hvigorw 2>/dev/null || true
bash ./hvigorw assembleHap \
  --mode module \
  -p product=default \
  -p buildMode="$MODE" \
  --no-daemon

UNSIGNED="$ROOT/harmony/entry/build/default/outputs/default/entry-default-unsigned.hap"
if [ ! -f "$UNSIGNED" ]; then
  echo "❌ 未找到未签名包：$UNSIGNED" >&2
  exit 1
fi

echo ""
echo "▶ [2/2] 本地自签 …"
SIGNED="$ROOT/harmony/entry/build/default/outputs/default/zhihu--default-signed.hap"
bash "$ROOT/harmony/signing/sign.sh" "$UNSIGNED" "$SIGNED"

echo ""
echo "🎉 完成"
echo "   未签名：$UNSIGNED"
echo "   已签名：$SIGNED"
