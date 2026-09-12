/**
 * 用户动态流 API —— 移植自上游 zhihu--/api/zhihu/moments.ts。
 * 改动：
 *   · axios baseURL → zhihuClient 全 URL；设备态 api.zhihu.com 端点合并
 *     getZhihuAppEndpointHeaders
 *   · appApi 未导出 buildZhihuAppMomentOriginUrl，本文件内用 @kit.ArkTS URL 自建
 *   · new URL → url.URL
 */

import { url } from '@kit.ArkTS';

const URL_CTOR = url.URL;

import { zhihuClient } from './httpClient';
import {
  getZhihuAppEndpointHeaders,
  ZHIHU_APP_API_BASE_URL,
} from './appApi';
import { ZhihuPaging } from '../model/zhihu';
import { RawFeedItem } from './feed';

// ==========================================
// 1. 类型定义
// ==========================================

export interface ZhihuActor {
  id: string;
  url_token: string;
  name: string;
  avatar_url: string;
}

export interface RecentMomentItem {
  /** Some response variants expose the read token as the feed entry id. */
  id?: string;
  /** Opaque token used by the recent-person read endpoint. */
  brief?: string;
  actor: ZhihuActor;
  unread_count: number;
}

export interface RecentMomentsResponse {
  data: RecentMomentItem[];
  paging: ZhihuPaging;
}

export interface MomentOriginResponse {
  data: RawFeedItem[];
  paging?: ZhihuPaging;
}

// ==========================================
// 2. URL builder
// ==========================================

function buildMomentOriginUrl(momentId: string, limit: number): string {
  const parsed = new URL_CTOR(
    '/moments/' + encodeURIComponent(momentId) + '/origin',
    ZHIHU_APP_API_BASE_URL,
  );
  parsed.searchParams.set('limit', String(limit));
  return parsed.toString();
}

// ==========================================
// 3. 请求函数
// ==========================================

/**
 * 获取最近有更新的关注用户列表及未读数量
 *
 * @returns 包含有新动态的用户列表和分页信息的 Promise
 */
export const fetchRecentMoments = async (): Promise<RecentMomentsResponse> => {
  const requestUrl: string =
    'https://api.zhihu.com/moments/recent?type=raw';
  const response = await zhihuClient.get<RecentMomentsResponse>(requestUrl, {
    headers: getZhihuAppEndpointHeaders(requestUrl),
  });
  return response.data;
};

export interface MarkRecentMomentsReadResponse {
  success: boolean;
}

/** Mark one recent-person entry as read using its opaque response token. */
export const markRecentMomentsRead = async (
  readToken: string,
): Promise<MarkRecentMomentsReadResponse> => {
  const requestUrl: string =
    'https://api.zhihu.com/moments/recent/read?brief=' +
    encodeURIComponent(readToken);
  const response = await zhihuClient.post<MarkRecentMomentsReadResponse>(
    requestUrl,
    {
      data: '',
      headers: {
        'x-api-version': '3.0.93',
        'x-page-id': '10103',
      },
    },
  );
  return response.data;
};

/** Resolve the original items grouped by an App moments card. */
export const fetchMomentOrigin = async (
  momentId: string,
  limit: number = 20,
): Promise<MomentOriginResponse> => {
  const requestUrl = buildMomentOriginUrl(momentId, limit);
  const response = await zhihuClient.get<MomentOriginResponse>(requestUrl, {
    headers: getZhihuAppEndpointHeaders(requestUrl),
  });
  return response.data;
};
