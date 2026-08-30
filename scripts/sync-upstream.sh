#!/usr/bin/env bash
# ============================================================================
# sync-upstream.sh — 将上游更新合入当前分支（默认 rebase，保持线性历史）
# ============================================================================
# 设计目标：
#   - 把 luckylew23/zhihu-- (upstream/main) 的最新提交合入当前分支
#   - 通过 rebase 让转换分支始终基于最新上游，减少与上游的长期分叉
#   - 冲突面被刻意控制在以下受控文件（见 OHOS_MIGRATION.md）：
#       package.json / app.json / metro.config.js / babel.config.js
#     业务代码 app/ components/ store/ api/ utils/ 因走 Metro 别名抽象层，
#     基本无需改动，rebase 时极少冲突。
#
# 用法：
#   ./scripts/sync-upstream.sh            # rebase upstream/main 到当前分支
#   ./scripts/sync-upstream.sh --merge   # 改用 merge（保留合并提交）
# ============================================================================
set -euo pipefail

MODE="rebase"
if [ "${1:-}" = "--merge" ]; then MODE="merge"; fi

UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"
CURRENT="$(git rev-parse --abbrev-ref HEAD)"

echo "🔄 同步上游 $UPSTREAM_REMOTE/$UPSTREAM_BRANCH -> 当前分支: $CURRENT"
git fetch "$UPSTREAM_REMOTE"

# 有未提交改动先暂存
STASHED=0
if ! git diff --quiet || ! git diff --cached --quiet || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "📦 暂存本地未提交改动..."
  git stash push -u -m "sync-upstream auto-stash $(date +%s)"
  STASHED=1
fi

if [ "$MODE" = "rebase" ]; then
  if git rebase "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"; then
    echo "✅ rebase 完成"
  else
    echo "⚠️  rebase 冲突，请手动解决后执行: git rebase --continue"
    [ "$STASHED" -eq 1 ] && echo "（stash 仍保留，解决后可 git stash pop 恢复本地改动）"
    exit 1
  fi
else
  git merge "$UPSTREAM_REMOTE/$UPSTREAM_BRANCH" --no-edit
fi

if [ "$STASHED" -eq 1 ]; then
  echo "📥 恢复本地未提交改动..."
  git stash pop || echo "⚠️  stash pop 失败，请手动处理"
fi

echo "🎉 同步完成。推送到你的 fork: git push -u origin $CURRENT"
echo "   若已推送过且使用 rebase:   git push --force-with-lease origin $CURRENT"
