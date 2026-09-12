/**
 * Zhihu App API 路由 —— 移植自上游 zhihu--/api/zhihu/appApi.ts。
 * 改动：new URL → @kit.ArkTS 的 URL；对象展开 → 显式合并（ArkTS 禁展开）。
 */

import { url } from '@kit.ArkTS';

const URL_CTOR = url.URL;

export const ZHIHU_APP_API_BASE_URL = 'https://api.zhihu.com';

export type ZhihuAppFeedAction = 'up' | 'down';
export type ZhihuAppMomentsFeedType = 'timeline' | 'recommend';

export interface ZhihuAppRecommendParams {
  action?: ZhihuAppFeedAction;
  ad_interval?: number;
  after_id?: number;
  end_offset?: number;
  page_number?: number;
  session_token?: string;
  start_type?: string;
  refresh_scene?: number;
  device?: string;
  short_container_setting_value?: number;
  include_guide_relation?: boolean;
  is_feed_first_request?: number;
}

export interface ZhihuAppMomentsParams {
  action?: ZhihuAppFeedAction;
  ad_index?: number;
  ad_slot_position?: number;
  feed_type?: ZhihuAppMomentsFeedType;
  moment_start_offset?: number;
  offset?: number;
  page_num?: number;
  session_id?: string;
}

type QueryValue = string | number | boolean | object;

function buildApiUrl(path: string, params: Record<string, QueryValue>): string {
  const parsed = new URL_CTOR(path, ZHIHU_APP_API_BASE_URL);
  const names = Object.keys(params);
  for (const name of names) {
    const value = params[name];
    if (value === undefined) {
      continue;
    }
    if (typeof value === 'object') {
      parsed.searchParams.set(name, JSON.stringify(value));
    } else {
      parsed.searchParams.set(name, String(value));
    }
  }
  return parsed.toString();
}

export function buildZhihuAppRecommendUrl(
  params: ZhihuAppRecommendParams,
): string {
  const merged: Record<string, QueryValue> = {
    action: params.action ?? 'down',
    ad_interval: params.ad_interval ?? -10,
    after_id: params.after_id ?? 0,
    end_offset: params.end_offset ?? 0,
    page_number: params.page_number ?? 1,
    start_type: params.start_type ?? 'cold',
    refresh_scene: params.refresh_scene ?? 0,
    device: params.device ?? 'pad',
    short_container_setting_value: params.short_container_setting_value ?? 0,
    include_guide_relation: params.include_guide_relation ?? false,
    is_feed_first_request: params.is_feed_first_request ?? 1,
  };
  if (params.session_token !== undefined) {
    merged['session_token'] = params.session_token;
  }
  return buildApiUrl('/topstory/recommend', merged);
}

export function buildZhihuAppMomentsUrl(
  feedType: ZhihuAppMomentsFeedType,
  params: ZhihuAppMomentsParams,
): string {
  const merged: Record<string, QueryValue> = {
    action: params.action ?? 'down',
    ad_index: params.ad_index ?? 7,
    ad_slot_position: params.ad_slot_position ?? 7,
    feed_type: feedType,
    moment_start_offset: params.moment_start_offset ?? 0,
    offset: params.offset ?? 0,
    page_num: params.page_num ?? 1,
    session_id: params.session_id ?? '',
  };
  return buildApiUrl('/moments_v3', merged);
}

/**
 * 只有稳定的端点元数据被复制；易变追踪、凭证与设备指纹头必须来自运行时。
 */
export function getZhihuAppEndpointHeaders(
  url: string,
): Record<string, string> {
  let pathname: string;
  try {
    pathname = new URL_CTOR(url, ZHIHU_APP_API_BASE_URL).pathname;
  } catch (e) {
    return {};
  }

  if (pathname === '/topstory/recommend') {
    return {
      'x-api-version': '3.1.8',
      'x-page-id': '44',
      'x-close-recommend': '0',
      'x-feed-prefetch': '0',
    };
  }
  if (pathname === '/moments_v3') {
    return {
      'x-api-version': '3.0.93',
      'x-page-id': '43',
      'x-moments-ab-param': 'follow_tab=1',
    };
  }
  if (/^\/questions\/[^/]+\/feeds$/.test(pathname)) {
    return { 'x-api-version': '3.0.89', 'x-page-id': '172' };
  }
  if (
    /^\/questions\/[^/]+(?:\/related-objects)?$/.test(pathname) ||
    /^\/moments\/[^/]+\/origin$/.test(pathname)
  ) {
    return { 'x-api-version': '3.0.93', 'x-page-id': '172' };
  }
  return {};
}
