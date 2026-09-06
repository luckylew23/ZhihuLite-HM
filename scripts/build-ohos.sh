#!/usr/bin/env bash
# ============================================================================
# build-ohos.sh — 一键产出 zhihu--HMOS 的可安装 .hap
# ============================================================================
# 用法: scripts/build-ohos.sh [debug|release]
#
# 路线（与 Tydora-HMOS 一致，已验证）：
#   Expo Web 静态导出 → 内联为单文件 index.html → rawfile
#   → ArkTS ArkWeb 壳加载 → assembleHap（秒级）→ 本地自签
#
# 不做 React Native 原生移植（RNOH）。原因：
#   RNOH 的 har 内含 boost / folly / glog / libevent / fast_float 全量 C++ 源码，
#   且 libs/ 为空（没有预编译 .so），assembleHap 会触发一次完整 CMake 原生构建
#   （数十分钟级），且 JS RN 0.83.2 与原生 RNOH 0.84.3 版本错配。
#   zhihu-- 本身已带 react-native-web + expo web 支持，走 Web 壳是性价比最高的路径。
#
# 子脚本：
#   scripts/build-web.sh —— Expo Web 导出 + 单文件内联 + 图标准备
#   scripts/build-hap.sh —— hvigor assembleHap + 本地自签
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-release}"
SKIP_WEB="${SKIP_WEB:-0}"

echo "🚀 zhihu--HMOS 构建 (mode=$MODE)"

if [ "$SKIP_WEB" != "1" ]; then
  bash "$ROOT/scripts/build-web.sh"
else
  echo "⏭  SKIP_WEB=1，跳过 Web 构建，复用现有 rawfile"
fi

echo ""
bash "$ROOT/scripts/build-hap.sh" "$MODE"
