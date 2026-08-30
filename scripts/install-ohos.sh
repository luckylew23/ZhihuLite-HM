#!/usr/bin/env bash
# ============================================================================
# install-ohos.sh — 安装 HarmonyOS (HMOS) 构建所需的全部依赖
# ============================================================================
# 前置条件（本机需自行准备，脚本不负责安装）：
#   - Node.js 18+（与 Expo/RN 同版本要求）
#   - DevEco Studio + HarmonyOS SDK (API 12 / OHOS 5.0+)
#   - JDK 17（OHOS 构建要求）
#   - ohpm（DevEco 自带，确保 `ohpm -v` 可用）
#
# 设计原则：app/ components/ store/ api/ utils/ 等【完全不改动】。
#   - JS 依赖：临时用 package.ohos.json 覆盖 package.json 安装，装完即恢复，
#     因此 node_modules 被替换为 OHOS 专用集合，但源清单零改动。
#   - 原生依赖：harmony/ 工程通过 ohpm 拉取 @rnoh/react-native-openharmony 等。
# ============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "📦 安装 OHOS JS 依赖（基于 package.ohos.json）..."
if [ ! -f package.ohos.json ]; then
  echo "❌ 缺少 package.ohos.json" >&2
  exit 1
fi

# 备份真正的 package.json（上游清单），用 OHOS 清单临时顶替，安装后恢复。
cp package.json package.json.ohos.bak
cp package.ohos.json package.json

cleanup() {
  mv package.json.ohos.bak package.json
  echo "♻️  已恢复 package.json（上游清单未被改动）"
}
trap cleanup EXIT

npm install --no-save || {
  echo "⚠️  npm install 部分失败，继续尝试 harmony 原生依赖安装..."
}

echo "📦 安装 harmony/ 原生工程依赖（ohpm）..."
if command -v ohpm >/dev/null 2>&1; then
  (cd harmony && ohpm install)
else
  echo "⚠️  未检测到 ohpm，请打开 DevEco Studio 在 harmony/ 工程中执行 Sync 安装依赖。"
fi

echo "✅ 依赖安装完成。下一步：./scripts/build-ohos.sh"
