/**
 * 消息通知 API —— 移植自上游 zhihu--/api/zhihu/notification.ts。
 * ----------------------------------------------------------------------------
 * 改动：
 *   · axios → zhihuClient；POST body 为 JSON raw string（'{}'）。
 *   · 去掉 ApiRequestOptions.signal（v1.0 无 AbortSignal）。
 *   · 上游返回 any → object。
 */

import { zhihuClient } from './httpClient';

const RECENT_URL: string =
  'https://www.zhihu.com/api/v4/notifications/v2/recent';
const READALL_URL: string =
  'https://www.zhihu.com/api/v4/notifications/v2/timeline/actions/readall';

/**
 * 通知列表。
 * @param nextUrl 翻页时直接传 paging.next；为空则走入口 URL
 * @param entryName all / votes / comments / follows / communications 等
 */
export const getNotifications = async (
  nextUrl?: string,
  entryName: string = 'all',
): Promise<object> => {
  const url =
    nextUrl !== undefined && nextUrl.length > 0
      ? nextUrl
      : RECENT_URL + '?limit=10&entry_name=' + encodeURIComponent(entryName);
  const res = await zhihuClient.get<object>(url);
  return res.data;
};

/** 一键全部已读 */
export const markAllNotificationsRead = async (): Promise<object> => {
  const res = await zhihuClient.post<object>(READALL_URL, {
    data: '{}',
    headers: { 'Content-Type': 'application/json' },
  });
  return res.data;
};
