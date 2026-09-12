/**
 * 专栏 API —— 移植自上游 zhihu--/api/zhihu/column.ts。
 * 改动：
 *   · axios baseURL → zhihuClient 全 URL（www.zhihu.com/api/v4）
 *   · getColumnItems 返回 any[] → object[]（ArkTS 禁 any）
 *   · unfollowColumn 走 zhihuClient.delete（与上游 DELETE 一致）
 */

import { zhihuClient } from './httpClient';
import { ZhihuColumnDetail } from '../model/zhihu';

const API_V4: string = 'https://www.zhihu.com/api/v4';

export interface ZhihuColumnItemsResponse {
  paging: {
    is_end: boolean;
    next: string;
  };
  data: object[];
}

export const getColumn = async (
  id: string | number,
): Promise<ZhihuColumnDetail> => {
  const include: string = 'intro,followers,articles_count,items_count,author,is_following';
  const res = await zhihuClient.get<ZhihuColumnDetail>(
    API_V4 + '/columns/' + String(id) + '?include=' + include,
  );
  return res.data;
};

export const getColumnItems = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuColumnItemsResponse> => {
  const res = await zhihuClient.get<ZhihuColumnItemsResponse>(
    API_V4 + '/columns/' + String(id) + '/items' +
      '?limit=' + String(limit) + '&offset=' + String(offset) +
      '&ws_qiangzhisafe=0',
  );
  return res.data;
};

export const getArticleColumnCard = async (
  articleId: string | number,
): Promise<ZhihuColumnDetail> => {
  const res = await zhihuClient.get<ZhihuColumnDetail>(
    API_V4 + '/column/articles/' + String(articleId) + '/card',
  );
  return res.data;
};

export const followColumn = async (
  columnId: string | number,
): Promise<{ member_count?: number; is_following?: boolean }> => {
  const res = await zhihuClient.post<{ member_count?: number; is_following?: boolean }>(
    API_V4 + '/columns/' + String(columnId) + '/followers',
    { data: '' },
  );
  return res.data;
};

/** 取消关注专栏：DELETE。 */
export const unfollowColumn = async (
  columnId: string | number,
): Promise<{ member_count?: number; is_following?: boolean }> => {
  const res = await zhihuClient.delete<{ member_count?: number; is_following?: boolean }>(
    API_V4 + '/columns/' + String(columnId) + '/followers',
  );
  return res.data;
};

