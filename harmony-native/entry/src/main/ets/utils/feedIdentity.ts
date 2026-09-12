/**
 * Feed 内容身份 —— 移植自上游 zhihu--/utils/feedIdentity.ts。
 * 供本地去重/曝光记录使用（v1.0 预留）。
 */

const FEED_CONTENT_TYPE_ALIASES: Record<string, string> = {
  answer: 'answer',
  answers: 'answer',
  article: 'article',
  articles: 'article',
  pin: 'pin',
  pins: 'pin',
  question: 'question',
  questions: 'question',
};

export interface FeedIdentitySource {
  id?: string | number | null;
  isIdStable?: boolean;
  type?: string | null;
}

export interface FeedContentIdentity {
  contentType: string;
  contentId: string;
}

export function getFeedContentIdentity(
  item: FeedIdentitySource,
): FeedContentIdentity | null {
  if (item.isIdStable === false) return null;
  const contentId = item.id?.toString().trim();
  const contentType = item.type
    ? FEED_CONTENT_TYPE_ALIASES[item.type]
    : undefined;
  if (!contentId || !contentType) return null;
  return { contentType, contentId };
}

export function toFeedContentKey(identity: FeedContentIdentity): string {
  return `${identity.contentType.trim()}:${identity.contentId.trim()}`;
}

export function getFeedContentKey(item: FeedIdentitySource): string | null {
  const identity = getFeedContentIdentity(item);
  return identity ? toFeedContentKey(identity) : null;
}

export function getInMemoryFeedKey(item: FeedIdentitySource): string | null {
  const contentKey = getFeedContentKey(item);
  if (contentKey) return contentKey;

  const id = item.id?.toString().trim();
  return id ? `unknown:${id}` : null;
}
