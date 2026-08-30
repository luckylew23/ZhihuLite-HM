#!/usr/bin/env bash
# ============================================================================
# build-ohos.sh — 构建 HarmonyOS NEXT (.hap)
# ============================================================================
# 关键修正（2026-08-28）：
#   不要手动 `react-native bundle`！RNOH 的 hvigor 插件（appTasks）会在
#   `assembleHap` 时**自动调用 Metro** 完成 JS 打包，并使用 RNOH 专用的
#   Metro 序列化器（处理 .rnoh / TurboModule 等）。手动 bundle 会用错序列化器
#   且文件名不对（应为 index.harmony.bundle），反而破坏产物。
#
#   打包入口 / 输出目录由 harmony/build-profile.json5 的
#   app.buildOption.rnoh { entryRoot:"./ohos", entryFileName:"index",
#   assetDest:".../rawfile", jsBundleFile:".../index.harmony.bundle" } 决定。
#
# 前置（本机需具备，脚本已尽量自动定位 DevEco 工具链）：
#   - DevEco Studio（提供 hvigor / ohpm / node / JDK）
#   - 已执行过依赖安装：ohpm install（harmony/）+ npm install（基于 package.ohos.json）
#   - signingConfigs：本地调试可在 DevEco 里「自动签名」，或用已有 p12/cer/p7b 物料
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# —— 自动定位 DevEco 工具链（hvigor / ohpm / node / JDK）——
DEVECO_HOME="${DEVECO_HOME:-/Applications/DevEco-Studio.app/Contents}"
if [ ! -d "$DEVECO_HOME" ]; then
  echo "❌ 未找到 DevEco Studio（期望 $DEVECO_HOME）。请设置 DEVECO_HOME 环境变量。" >&2
  exit 1
fi

export JAVA_HOME="${JAVA_HOME:-$DEVECO_HOME/jbr/Contents/Home}"
export PATH="$JAVA_HOME/bin:$DEVECO_HOME/tools/hvigor/bin:$DEVECO_HOME/tools/ohpm/bin:$DEVECO_HOME/tools/node/bin:$PATH"

# HMOS_BUILD=1 让业务代码的 expo-* import 走 platform/ohos/shims/* 别名层
# （RNOH 的 Metro 打包也会读取此环境变量以启用别名）。
export HMOS_BUILD=1

echo "🔧 DevEco 工具链："
echo "   hvigor : $(hvigorw -v 2>/dev/null || echo '?')"
echo "   ohpm   : $(ohpm -v 2>/dev/null || echo '?')"
echo "   java   : $($JAVA_HOME/bin/java -version 2>&1 | head -1)"

echo "🏗️  构建 HAP（RNOH hvigor 插件将自动打包 JS + 编译 ArkTS + 签名）..."
cd harmony
./hvigorw assembleHap --mode module -p product=default

echo "🎉 完成。HAP 位于："
echo "   harmony/entry/build/default/outputs/default/*.hap"
echo "   复制到设备/模拟器后用 DevEco 或 hdc install 安装。"
