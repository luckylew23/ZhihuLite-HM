#!/usr/bin/env bash
# ============================================================================
# setup-remotes.sh — 配置你的 fork（origin）+ 原作者仓库（upstream，只读）
# ============================================================================
# 用法：
#   ./scripts/setup-remotes.sh <你的 fork 地址> [原作者仓库地址]
#
# 示例：
#   ./scripts/setup-remotes.sh git@github.com:yourname/zhihu--.git
#
# 执行后：
#   - origin    = 你的 fork（转换工作推送到这里）
#   - upstream  = 原作者 luckylew23/zhihu--（已禁止推送，避免影响原作者）
# ============================================================================
set -euo pipefail

FORK_URL="${1:?请提供你的 fork 地址，例如 git@github.com:yourname/zhihu--.git}"
UPSTREAM_URL="${2:-https://github.com/luckylew23/zhihu--.git}"

git remote remove origin 2>/dev/null || true
git remote add origin "$FORK_URL"
git remote add upstream "$UPSTREAM_URL" 2>/dev/null || git remote set-url upstream "$UPSTREAM_URL"

# 关键：上游仓库只读，任何推送都被拒绝，确保不影响原作者
git remote set-url --push upstream "no-push-upstream"

git fetch upstream
git fetch origin 2>/dev/null || true

echo "✅ 远程仓库已配置："
git remote -v
echo ""
echo "➡️  转换工作在 hmos 分支进行；需要同步上游时执行： ./scripts/sync-upstream.sh"
