/**
 * 浏览历史 API —— 移植自上游 zhihu--/api/zhihu/history.ts。
 * 覆盖：上报单条阅读、后台 best-effort 记录、批量删除/清空、读取历史列表。
 * 改动：
 *   · useAuthStore → 已就绪 authStore / hasAuthenticationCookie
 *   · axios 对象体 → zhihuClient raw string（JSON.stringify + application/json）
 *   · 去掉 AbortSignal
 */

import { zhihuClient } from './httpClient';
import { authStore, hasAuthenticationCookie } from '../store/authStore';

const API_V4 = 'https://www.zhihu.com/api/v4';

const JSON_HEADERS: Record<string, string> = {
  'Content-Type': 'application/json;charset=utf-8',
};

export const CONTENT_TYPES: string[] = [
  'answer',
  'question',
  'article',
  'pin',
  'zvideo',
  'video',
  'column',
  'profile',
];

export type ReadHistoryContentType =
  | 'answer'
  | 'question'
  | 'article'
  | 'pin'
  | 'zvideo'
  | 'video'
  | 'column'
  | 'profile';

export interface AddReadHistoryPayload {
  content_token: string;
  content_type: ReadHistoryContentType;
}

export interface ReadHistoryHeader {
  title: string;
}

export interface ReadHistoryContent {
  summary: string;
}

export interface ReadHistoryMatrixItem {
  data: {
    text: string;
  };
}

export interface ReadHistoryExtra {
  content_token: string;
  content_type: string;
  read_time: number;
}

export interface ReadHistoryDataItem {
  id: string;
  data: {
    header: ReadHistoryHeader;
    content: ReadHistoryContent;
    matrix: ReadHistoryMatrixItem[];
    extra: ReadHistoryExtra;
  };
}

export interface ReadHistoryPaging {
  is_end: boolean;
  is_start: boolean;
  next: string;
  previous: string;
}

export interface ReadHistoryResponse {
  paging: ReadHistoryPaging;
  data: ReadHistoryDataItem[];
}

/** 上报一条阅读记录（未登录直接忽略） */
export const addReadHistory = async (
  payload: AddReadHistoryPayload,
): Promise<object | null> => {
  if (!hasAuthenticationCookie(authStore.cookies)) {
    return null;
  }
  const res = await zhihuClient.post<object>(
    API_V4 + '/read_history/add',
    { headers: JSON_HEADERS, data: JSON.stringify(payload) },
  );
  return res.data;
};

/** Best-effort 后台记录；阅读内容本身不得因此产生未捕获 rejection。 */
export function recordReadHistory(payload: AddReadHistoryPayload): void {
  addReadHistory(payload).catch(() => {
    // 记录失败不影响阅读流程
  });
}

export interface BatchDelReadHistoryPayload {
  pairs?: AddReadHistoryPayload[];
  clear: boolean;
}

export const batchDelReadHistory = async (
  payload: BatchDelReadHistoryPayload,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/read_history/batch_del',
    { headers: JSON_HEADERS, data: JSON.stringify(payload) },
  );
  return res.data;
};

/** 浏览历史列表（登录态接口） */
export const getReadHistory = async (
  limit: number = 20,
  offset: number = 0,
): Promise<ReadHistoryResponse> => {
  const res = await zhihuClient.get<ReadHistoryResponse>(
    API_V4 + '/unify-consumption/read_history?limit=' + String(limit) +
      '&offset=' + String(offset),
  );
  return res.data;
};
