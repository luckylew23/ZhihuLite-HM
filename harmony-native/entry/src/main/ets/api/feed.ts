/**
 * Feed API —— 移植自上游 zhihu--/api/zhihu/feed.ts。
 * 改动：
 *   · ReactNode → string（UI 层职责下沉到原生渲染）
 *   · unknown[] → object[]（ArkTS）
 *   · useAuthStore/useSettingsStore → 本文件内轻量设置常量（v1.0）
 *   · new URL → @kit.ArkTS URL
 */

import { url } from '@kit.ArkTS';

const URL_CTOR = url.URL;
import { zhihuClient, ApiResponse } from './httpClient';
import { settingsStore } from '../store/settingsStore';
import {
  buildZhihuAppMomentsUrl,
  buildZhihuAppRecommendUrl,
  getZhihuAppEndpointHeaders,
} from './appApi';

// —— v1.0 轻量设置（对应上游 useSettingsStore 默认值）——
export interface FeedSettings {
  recommendRequestIncludeDesktop: boolean;
  recommendRequestIncludeAdInterval: boolean;
  recommendRequestAdInterval: number;
}

export const DEFAULT_FEED_SETTINGS: FeedSettings = {
  recommendRequestIncludeDesktop: true,
  recommendRequestIncludeAdInterval: true,
  recommendRequestAdInterval: -10,
};

/**
 * 当前生效的推荐流请求开关 —— 从 settingsStore 读持久化值（默认与上游一致：
 * desktop=true、ad_interval 开）。feed.ts 只读取，不改变函数签名。
 */
export function currentFeedSettings(): FeedSettings {
  return {
    recommendRequestIncludeDesktop: settingsStore.isSendDesktop(),
    recommendRequestIncludeAdInterval: settingsStore.isSendAdInterval(),
    recommendRequestAdInterval: DEFAULT_FEED_SETTINGS.recommendRequestAdInterval,
  };
}

/**
 * 本地后处理·去重：开启时丢弃已记录过的 item，并把本次新出现的 id 记入 store。
 * 就地改写 response.data（ZhihuFeedResponse.data 即 RawFeedItem[]），返回是否发生去重。
 */
function applyLocalDedup(response: ZhihuFeedResponse): boolean {
  if (!settingsStore.isDedupEnabled() || !response || !response.data) {
    return false;
  }
  const raw: RawFeedItem[] = response.data;
  const kept: RawFeedItem[] = [];
  const newIds: string[] = [];
  for (const item of raw) {
    const idStr = feedItemId(item);
    if (idStr.length > 0 && settingsStore.isFeedIdSeen(idStr)) {
      continue; // 丢弃重复
    }
    kept.push(item);
    if (idStr.length > 0) {
      newIds.push(idStr);
    }
  }
  if (newIds.length > 0) {
    settingsStore.markFeedIdsSeen(newIds);
  }
  response.data = kept;
  return kept.length !== raw.length;
}

/** 从 feed item 取稳定去重键（id > card_id > target.id）。 */
function feedItemId(item: RawFeedItem): string {
  if (item.id !== undefined && item.id !== null) {
    return String(item.id);
  }
  if (item.card_id !== undefined && item.card_id !== null && item.card_id.length > 0) {
    return item.card_id;
  }
  const target = item.target;
  if (target && target.id !== undefined && target.id !== null) {
    return String(target.id);
  }
  return '';
}

// ---------------------------------------------------------------------------
// 原始响应类型（JSON 结构，缺失字段为 undefined）
// ---------------------------------------------------------------------------

export interface FeedTopic {
  id: string;
  name: string;
}

export interface FeedAuthor {
  id: string;
  url_token?: string;
  name: string;
  avatar: string;
  headline?: string;
}

export interface RawFeedAuthor {
  id?: string;
  name?: string;
  avatar_url?: string;
  headline?: string;
  url?: string;
  url_token?: string;
  type?: string;
  user_type?: string;
  gender?: number;
  is_advertiser?: boolean;
  is_org?: boolean;
  is_followed?: boolean;
  is_following?: boolean;
}

export interface RawFeedQuestion {
  id?: string | number;
  title?: string;
  url?: string;
  type?: string;
  answer_count?: number;
  comment_count?: number;
  follower_count?: number;
  detail?: string;
  excerpt?: string;
  bound_topic_ids?: number[];
  relationship?: {
    is_author?: boolean;
  };
  is_following?: boolean;
  author?: RawFeedAuthor;
}

export interface FeedContentSegment {
  type: string;
  content?: string;
  own_text?: string;
  fold_type?: string;
  text_link_type?: string;
  title?: string;
  url?: string;
  duration?: number;
  height?: number;
  width?: number;
  thumbnail?: string;
  video_id?: string;
  status?: string;
}

export interface RawFeedTarget {
  id?: string | number;
  type?: string;
  author?: RawFeedAuthor;
  created?: number;
  created_time?: number;
  updated?: number;
  updated_time?: number;
  title?: string;
  excerpt_new?: string;
  excerpt?: string;
  content?: string | FeedContentSegment[];
  preview_type?: string;
  preview_text?: string;
  thumbnail?: string;
  content_img?: string[];
  children?: Array<Record<string, unknown>>;
  image_url?: string;
  linkbox?: {
    url?: string;
    category?: string;
    pic?: string;
    title?: string;
  };
  url?: string;
  voteup_count?: number;
  thanks_count?: number;
  like_count?: number;
  comment_count?: number;
  favlists_count?: number;
  favorite_count?: number;
  is_deleted?: boolean;
  is_top?: boolean;
  questions?: RawFeedQuestion[] | null;
  reaction_count?: number;
  relationship?: {
    voting?: number;
    is_thanked?: boolean;
    is_nothelp?: boolean;
    upvoted_followee_ids?: string[] | null;
  };
  topics?: FeedTopic[] | null;
  voting?: number;
  question?: RawFeedQuestion;
  detail_text?: string;
  answer_type?: string;
  paid_info?: {
    type?: string;
    content?: string;
    has_purchased?: boolean;
  };
  content_need_truncated?: boolean;
  is_labeled?: boolean;
  answer_count?: number;
  follower_count?: number;
  title_area?: {
    text: string;
  };
  excerpt_area?: {
    text: string;
  };
  image_area?: {
    url: string;
  };
  metrics_area?: {
    text: string;
    font_color?: string;
    background?: string;
    weight?: string;
  };
  label_area?: {
    type: string;
    trend?: number;
    text?: string;
    night_color?: string;
    normal_color?: string;
  };
  link?: {
    url: string;
  };
}

export interface RawFeedItem {
  id?: string | number;
  type?: string;
  offset?: number;
  created_time?: number;
  updated_time?: number;
  brief?: string;
  verb?: string;
  action_text_tpl?: string;
  action_text?: string;
  show_actor_time?: boolean;
  target?: RawFeedTarget;
  actors?: RawFeedAuthor[];
  count?: number;
  attached_info?: string;
  image_url?: string;
  detail_text?: string;
  debut?: boolean;
  card_id?: string;
  card_label?: {
    type: string;
    icon: string;
    night_icon: string;
  };
  feed_specific?: {
    answer_count: number;
  };
}

export interface ZhihuFeedResponse {
  data: RawFeedItem[];
  fresh_test?: string;
  has_new?: boolean;
  paging: {
    is_end: boolean;
    is_start?: boolean;
    next: string;
    previous?: string;
  };
}

// ---------------------------------------------------------------------------
// 展示模型（对应上游 FeedItem，去掉 ReactNode）
// ---------------------------------------------------------------------------

export interface FeedItem {
  id: string;
  isIdStable?: boolean;
  type: string;
  title: string;
  excerpt: string;
  content?: string | FeedContentSegment[];
  actionText?: string;
  author: FeedAuthor;
  image: string | null;
  voteCount: number;
  commentCount: number;
  favlistsCount?: number;
  voted: number;
  questionId?: string;
  topics?: FeedTopic[];
  answerType?: string;
  contentNeedTruncated?: boolean;
  isLabeled?: boolean;
  isOrgAuthor?: boolean;
  isAdvertiser?: boolean;
  upvotedByFollowee?: boolean;
  boundTopicIds?: number[];
  answerCount?: number;
  followerCount?: number;
  url?: string;
}

export const FEED_URLS = {
  following: 'https://www.zhihu.com/api/v3/moments?limit=10',
  recommend: 'https://www.zhihu.com/api/v3/feed/topstory/recommend?limit=10',
  local: 'zhihu://local-feed',
  hot: 'https://www.zhihu.com/api/v3/feed/topstory/hot-lists/total?limit=50',
  daily: 'https://daily.zhihu.com/api/4/news/latest',
};

const RECOMMEND_FEED_PATH = '/api/v3/feed/topstory/recommend';

/**
 * 给推荐流翻页 URL 补可选查询参数（含 paging.next 返回的 URL）。
 */
export function buildRecommendRequestUrl(
  url: string,
  options: FeedSettings,
): string {
  if (!url.includes(RECOMMEND_FEED_PATH)) {
    return url;
  }
  try {
    const parsedUrl = new URL_CTOR(url);
    if (options.recommendRequestIncludeDesktop) {
      parsedUrl.searchParams.set('desktop', 'true');
    } else {
      parsedUrl.searchParams.delete('desktop');
    }
    if (options.recommendRequestIncludeAdInterval) {
      parsedUrl.searchParams.set('ad_interval', String(options.recommendRequestAdInterval));
    } else {
      parsedUrl.searchParams.delete('ad_interval');
    }
    return parsedUrl.toString();
  } catch (e) {
    return url;
  }
}

/**
 * 拉取 Feed（未登录走客户端匿名态接口，失败回退 Web 游客 feed）。
 * @param url 入口 URL（支持 FEED_URLS.* 与翻页 URL）
 * @param cookies 当前 cookie（为空视为游客态）
 */
export async function getFeed(
  url: string,
  cookies: string,
): Promise<ZhihuFeedResponse> {
  let finalUrl = url;
  const isRefreshRequest = url.includes('action=up') || url.includes('t=');
  let appRecommendFallbackEligible = false;

  if (!cookies && finalUrl.includes('/api/v3/feed/topstory/recommend')) {
    appRecommendFallbackEligible = true;
    finalUrl = buildZhihuAppRecommendUrl({
      action: isRefreshRequest ? 'up' : 'down',
      refresh_scene: isRefreshRequest ? 1 : 0,
      is_feed_first_request: isRefreshRequest ? 0 : 1,
    });
  } else if (!cookies && finalUrl.includes('/api/v3/moments')) {
    finalUrl = buildZhihuAppMomentsUrl('timeline', {
      action: isRefreshRequest ? 'up' : 'down',
    });
  }

  if (url === 'zhihu://local-feed') {
    try {
      const sectionsRes = await zhihuClient.get<{
        data?: Array<{ section_id?: string; section_name?: string }>;
      }>('https://api.zhihu.com/feed-root/sections/query/v2');
      const sections = sectionsRes.data?.data || [];
      let localSection: { section_id?: string; section_name?: string } | null = null;
      for (const section of sections) {
        if (section.section_name?.includes('同城') || section.section_id) {
          localSection = section;
          break;
        }
      }
      if (localSection?.section_id) {
        finalUrl = 'https://api.zhihu.com/feed-root/section/' +
          localSection.section_id + '?channelStyle=0';
      } else {
        throw new Error('未找到同城版块');
      }
    } catch (error) {
      finalUrl = FEED_URLS.recommend;
    }
  } else if (url.startsWith('zhihu://local-feed/')) {
    finalUrl = url.replace(
      'zhihu://local-feed/',
      'https://api.zhihu.com/feed-root/section/',
    );
  }

  if (cookies) {
    finalUrl = buildRecommendRequestUrl(finalUrl, currentFeedSettings());
  }

  let res: ApiResponse<ZhihuFeedResponse>;
  try {
    res = await zhihuClient.get<ZhihuFeedResponse>(finalUrl, {
      headers: getZhihuAppEndpointHeaders(finalUrl),
    });
  } catch (error) {
    if (!appRecommendFallbackEligible) {
      throw error;
    }
    // 设备端点缺凭证时的兼容回退：Web 游客 feed
    let fallbackUrl =
      'https://www.zhihu.com/api/v3/explore/guest/feeds?limit=15&ws_qiangzhisafe=0';
    if (isRefreshRequest) {
      fallbackUrl += '&t=' + String(Date.now());
    }
    res = await zhihuClient.get<ZhihuFeedResponse>(fallbackUrl);
  }

  if (url.startsWith('zhihu://local-feed')) {
    const next = res.data?.paging?.next;
    if (next) {
      res.data.paging.next = next.replace(
        'https://api.zhihu.com/feed-root/section/',
        'zhihu://local-feed/',
      );
    }
  }

  // 本地后处理·去重（开启时在客户端过滤重复卡片）
  applyLocalDedup(res.data);

  return res.data;
}
