/**
 * 点赞/投票状态归一化 —— 问题、回答、文章、想法、评论共用。
 *
 * 知乎不同端点返回的 relationship.voting 形态不统一：
 *   · 数字 1 / 0 / -1
 *   · 字符串 "up" / "down" / "neutral"（部分 feed / v5 端点）
 *   · 布尔 true（旧 comment 端点把 voting 当 liked 用）
 *   · 字段缺失 / null
 * 直接 `voted === 1` 判断会把字符串/布尔误判成"未点赞"，
 * 而各页面各自 `?? 0` 又会在列表复用时残留状态。
 * 上游 zhihu-- 有 votePayload.ts 做同样的事，这里做轻量等价实现。
 */

/** 任意形态的投票值 → -1(反对) / 0(未投) / 1(赞同)。 */
export function normalizeVoting(value: unknown): number {
  if (typeof value === 'number') {
    if (value === 1) return 1;
    if (value === -1) return -1;
    return 0;
  }
  if (typeof value === 'boolean') {
    return value ? 1 : 0;
  }
  if (typeof value === 'string') {
    const s = value.trim().toUpperCase();
    if (s === 'UP' || s === 'LIKE' || s === '1') return 1;
    if (s === 'DOWN' || s === '-1') return -1;
    return 0;
  }
  return 0;
}

/** 是否已赞同（点赞）。 */
export function isUpvoted(value: unknown): boolean {
  return normalizeVoting(value) === 1;
}

/** 是否已反对。 */
export function isDownvoted(value: unknown): boolean {
  return normalizeVoting(value) === -1;
}

/**
 * 评论点赞态：优先 relationship.voting，回退到 V5 的 liked / is_liked 布尔字段。
 * normalizeComment 已把 liked 写进 relationship，但缓存/旧数据可能没有 relationship。
 */
export function isCommentLiked(item: {
  relationship?: { voting: number | string | boolean };
  liked?: boolean;
  is_liked?: boolean;
  voting?: boolean | number;
}): boolean {
  const rel = item.relationship;
  if (rel !== undefined && rel !== null) {
    return isUpvoted(rel.voting);
  }
  if (typeof item.liked === 'boolean') return item.liked;
  if (typeof item.is_liked === 'boolean') return item.is_liked;
  if (typeof item.voting === 'boolean') return item.voting;
  return false;
}

/**
 * 回答/文章点赞态读取：优先 relationship.voting（可能为数字/字符串），
 * 兜底 reaction.relation.vote（'UP'/'DOWN'/'NEUTRAL'，部分端点只返回这个）。
 */
export function contentVotingOf(item: {
  relationship?: { voting?: number | string | boolean | null };
  reaction?: { relation?: { vote?: string | null } };
}): number {
  const rel = item.relationship?.voting;
  if (rel !== undefined && rel !== null) {
    return normalizeVoting(rel);
  }
  const vote = item.reaction?.relation?.vote;
  if (typeof vote === 'string' && vote.length > 0) {
    return normalizeVoting(vote);
  }
  return 0;
}
