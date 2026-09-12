/**
 * Feed 解析器 —— 移植自上游 app/(tabs)/index.tsx 的
 * parseFollowingData / parseRecommendData / parseHotData。
 * 纯数据转换，ArkTS 原生 UI 直接消费。
 */

import {
  FeedItem,
  FeedAuthor,
  FeedTopic,
  FeedContentSegment,
  RawFeedItem,
  RawFeedTarget,
} from '../api/feed';
import { formatRelativeTime } from '../utils/date';

export interface HotItem {
  id: string;
  questionId: string;
  rank: number;
  title: string;
  excerpt: string;
  image: string | null;
  hotValue: string;
  answerCount: number;
  labelArea: { type: string; text?: string; normal_color?: string } | null;
}

export type FeedCardType = 'answers' | 'articles' | 'pins' | 'questions';

/**
 * 归一化回答的付费类型。
 * answer_type 大小写随接口而异（游客流小写 normal / 话题流大写 NORMAL/PAID），
 * 统一大写后比较，并与 paid_info 取或作为兜底。
 */
function normalizeAnswerType(target: RawFeedTarget): string | undefined {
  const raw = typeof target.answer_type === 'string'
    ? (target.answer_type as string).toUpperCase()
    : undefined;
  if (raw === 'PAID' || target.paid_info != null) return 'PAID';
  return raw;
}

function toFeedType(type: string | undefined): FeedCardType | null {
  if (type === 'answer') return 'answers';
  if (type === 'article') return 'articles';
  if (type === 'pin') return 'pins';
  if (type === 'question') return 'questions';
  return null;
}

function mapTopics(topics: FeedTopic[] | null | undefined): FeedTopic[] | undefined {
  if (!topics) {
    return undefined;
  }
  const out: FeedTopic[] = [];
  for (const topic of topics) {
    if (topic && topic.id !== undefined && topic.name !== undefined) {
      out.push({ id: topic.id, name: topic.name });
    }
  }
  return out.length > 0 ? out : undefined;
}

function excerptOf(target: RawFeedTarget): string {
  if (target.excerpt) {
    return target.excerpt;
  }
  if (Array.isArray(target.content)) {
    const first = (target.content as FeedContentSegment[])[0];
    return first?.content ?? '';
  }
  return (target.content as string) ?? '';
}

function imageOf(target: RawFeedTarget): string | null {
  if (target.thumbnail) {
    return target.thumbnail;
  }
  if (target.content_img && target.content_img.length > 0) {
    return target.content_img[0] ?? null;
  }
  return null;
}

const DEFAULT_AVATAR: string =
  'https://picx.zhimg.com/v2-abed1a8c04700ba7d72b45195223e0ff_l.jpg';

function toFeedAuthor(target: RawFeedTarget): FeedAuthor {
  return {
    id: target.author?.id ?? '',
    url_token: target.author?.url_token ?? '',
    name: target.author?.name ?? '匿名用户',
    avatar: target.author?.avatar_url ?? DEFAULT_AVATAR,
    headline: target.author?.headline ?? '',
  };
}

/** 关注流解析（动作 + 时间戳文案） */
export function parseFollowingData(item: RawFeedItem): FeedItem | null {
  const target = item.target;
  if (!target) {
    return null;
  }
  const appType = toFeedType(target.type);
  if (!appType) {
    return null;
  }
  const questionId: string = target.question?.id?.toString() ??
    (target.type === 'question' ? target.id?.toString() ?? '' : '');

  let actionText: string | undefined = undefined;
  if (item.action_text) {
    const time = item.updated_time
      ? '·' + formatRelativeTime(item.updated_time)
      : '';
    actionText = item.action_text + time;
  }

  return {
    id: target.id?.toString() || String(Math.random()),
    title: target.question?.title || target.title || '',
    questionId: questionId,
    actionText: actionText,
    author: toFeedAuthor(target),
    excerpt: excerptOf(target),
    content: target.content ?? '',
    image: imageOf(target),
    voteCount: target.voteup_count || target.like_count || 0,
    commentCount: target.comment_count || 0,
    favlistsCount: target.favorite_count || 0,
    voted: target.relationship?.voting || 0,
    type: appType,
    answerType: normalizeAnswerType(target),
    contentNeedTruncated: target.content_need_truncated,
    topics: mapTopics(target.topics),
    url: target.url,
  };
}

/** 推荐流解析（含本地过滤信号） */
export function parseRecommendData(item: RawFeedItem): FeedItem | null {
  const target = (item.target ?? item) as RawFeedTarget;
  const appType = toFeedType(target.type);
  if (!appType) {
    return null;
  }
  const stableId = target.id?.toString().trim();
  const questionId: string = target.question?.id?.toString() ??
    (target.type === 'question' ? target.id?.toString() ?? '' : '');

  return {
    id: stableId || String(Math.random()),
    isIdStable: Boolean(stableId),
    title: target.question?.title || target.title || '',
    questionId: questionId,
    author: toFeedAuthor(target),
    excerpt: excerptOf(target),
    content: target.content ?? '',
    image: imageOf(target),
    voteCount: target.voteup_count || target.like_count || 0,
    commentCount: target.comment_count || 0,
    favlistsCount: target.favlists_count || target.favorite_count || 0,
    voted: target.relationship?.voting || 0,
    type: appType,
    topics: mapTopics(target.topics),
    answerType: normalizeAnswerType(target),
    contentNeedTruncated: target.content_need_truncated,
    isLabeled: Boolean(target.is_labeled),
    isOrgAuthor: Boolean(target.author?.is_org),
    isAdvertiser: Boolean(target.author?.is_advertiser),
    upvotedByFollowee: (target.relationship?.upvoted_followee_ids?.length ?? 0) > 0,
    boundTopicIds: target.question?.bound_topic_ids,
    answerCount: target.type === 'question'
      ? target.answer_count
      : target.question?.answer_count,
    followerCount: target.type === 'question'
      ? target.follower_count
      : target.question?.follower_count,
    url: target.url,
  };
}

/** 热榜解析 */
export function parseHotData(item: RawFeedItem, index: number): HotItem | null {
  const target = (item.target ?? item) as RawFeedTarget;
  const questionId =
    target.link?.url?.split('/').pop() ||
    target.url?.split('/').pop() ||
    '';
  const hotValue = target.metrics_area?.text || item.detail_text || target.detail_text || '';
  const answerCount = item.feed_specific?.answer_count || target.answer_count || 0;

  let labelArea: { type: string; text?: string; normal_color?: string } | null =
    target.label_area ?? null;
  if (!labelArea) {
    if (item.card_label?.type === 'new' || item.debut) {
      labelArea = { type: 'text', text: '新', normal_color: '#ff9607' };
    } else if (item.card_label?.type === 'hot') {
      labelArea = { type: 'text', text: '热', normal_color: '#f65324' };
    }
  }

  return {
    id: item.id?.toString() || target.id?.toString() || String(Math.random()),
    questionId: questionId,
    rank: index + 1,
    title: target.title_area?.text || target.title || '无标题',
    excerpt: target.excerpt_area?.text || target.excerpt || '',
    image: target.image_area?.url || item.image_url || null,
    hotValue: hotValue,
    answerCount: answerCount,
    labelArea: labelArea,
  };
}
