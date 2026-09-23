/**
 * 收藏夹 API —— 移植自上游 zhihu--/api/zhihu/collection.ts。
 * ----------------------------------------------------------------------------
 * 改动：
 *   · axios → zhihuClient.get/post/put/delete；POST/PUT body 为 JSON raw string。
 *   · useAuthStore.getState().me.url_token 不可得（HarmonyOS authStore 只暴露
 *     isLoggedIn/cookies/userName），getMyCollections 直接用上游自带的
 *     'me' 兜底（/people/me/collections）。
 *   · axios 的 params 改为手动拼 query string；POST body 为 JSON raw string。
 *   · 上游相对路径改为全 URL（baseURL=https://www.zhihu.com/api/v4）。
 */

import { zhihuClient, RequestOptions } from './httpClient';
import { getMe } from './me';
import { ZhihuPaging } from '../model/zhihu';

const API_V4: string = 'https://www.zhihu.com/api/v4';

// 当前登录用户 url_token 缓存（getMe 修复后可用；获取失败回落 'me'）
let cachedUrlToken: string = '';
let urlTokenPromise: Promise<string> | null = null;

function myUrlToken(): Promise<string> {
  if (cachedUrlToken.length > 0) {
    return Promise.resolve(cachedUrlToken);
  }
  if (!urlTokenPromise) {
    urlTokenPromise = getMe()
      .then((me) => {
        cachedUrlToken = me.url_token ?? '';
        return cachedUrlToken;
      })
      .catch(() => {
        return '';
      })
      .finally(() => {
        urlTokenPromise = null;
      });
  }
  return urlTokenPromise;
}

const COLLECTION_INCLUDE: string =
  'data[*].updated_time,answer_count,follower_count,creator,description,is_following,comment_count,created_time;data[*].creator.kvip_info;data[*].creator.vip_info';

// ---------------------------------------------------------------------------
// 类型（上游未显式定义，按响应结构补全）
// ---------------------------------------------------------------------------

export interface CollectionCreator {
  id: string;
  url_token?: string;
  name: string;
  avatar_url?: string;
  headline?: string;
  type?: string;
  user_type?: string;
  vip_info?: object;
  kvip_info?: object;
}

export interface ZhihuCollection {
  id: string | number;
  title: string;
  description?: string;
  is_public?: boolean;
  answer_count?: number;
  follower_count?: number;
  comment_count?: number;
  created_time?: number;
  updated_time?: number;
  is_following?: boolean;
  creator?: CollectionCreator;
}

export interface CollectionListResponse {
  data: ZhihuCollection[];
  paging: ZhihuPaging;
}

export interface CollectionItemsResponse {
  data: object[];
  paging: ZhihuPaging;
}

export interface CollectionStatusResponse {
  data?: object[];
  count?: number;
  collected?: boolean;
}

export interface CreateCollectionInput {
  title: string;
  description: string;
  is_public: boolean;
}

function jsonBody(body: object): RequestOptions {
  return {
    data: JSON.stringify(body),
    headers: { 'Content-Type': 'application/json' },
  };
}

// ---------------------------------------------------------------------------
// 收藏夹列表 / 详情
// ---------------------------------------------------------------------------

export const getMyCollections = async (
  limit: number = 20,
  offset: number = 0,
): Promise<CollectionListResponse> => {
  const token: string = await myUrlToken();
  // 不回落 'me'：/people/me/collections 在知乎新版 API 上会被拒（403），
  // 拿不到真实 url_token 时直接抛可读错误，避免静默失败。
  if (token.length === 0) {
    throw new Error('无法获取当前用户标识（请重新登录后再试）');
  }
  const res = await zhihuClient.get<CollectionListResponse>(
    API_V4 + '/people/' + token + '/collections?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + COLLECTION_INCLUDE,
  );
  return res.data;
};

export const getUserCollections = async (
  userId: string,
  limit: number = 20,
  offset: number = 0,
): Promise<CollectionListResponse> => {
  const res = await zhihuClient.get<CollectionListResponse>(
    API_V4 + '/people/' + userId + '/collections?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + COLLECTION_INCLUDE,
  );
  return res.data;
};

export const getCollection = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.get<object>(API_V4 + '/collections/' + id);
  return res.data;
};

export const getCollectionDetail = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<CollectionItemsResponse> => {
  // 使用 /items 接口
  const res = await zhihuClient.get<CollectionItemsResponse>(
    API_V4 + '/collections/' + id + '/items?limit=' + String(limit) +
      '&offset=' + String(offset),
  );
  return res.data;
};

export const createCollection = async (
  data: CreateCollectionInput,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/collections',
    jsonBody(data as object),
  );
  return res.data;
};

export const updateCollection = async (
  id: string | number,
  data: CreateCollectionInput,
): Promise<object> => {
  const res = await zhihuClient.put<object>(
    API_V4 + '/collections/' + id,
    jsonBody(data as object),
  );
  return res.data;
};

export const deleteCollection = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.delete<object>(API_V4 + '/collections/' + id);
  return res.data;
};

// ---------------------------------------------------------------------------
// 回答收藏状态 / 添加 / 移除
// ---------------------------------------------------------------------------

/**
 * 获取回答被收藏的状态及所属收藏夹列表
 * GET /collections/contents/answer/{answer_id}
 */
export const getAnswerCollectionStatus = async (
  answerId: string | number,
  limit: number = 100,
  offset: number = 0,
): Promise<CollectionStatusResponse> => {
  const res = await zhihuClient.get<CollectionStatusResponse>(
    API_V4 + '/collections/contents/answer/' + answerId +
      '?limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

/**
 * 添加到收藏夹
 * POST /collections/{collection_id}/contents?content_id={answer_id}&content_type=answer
 */
export const addToCollection = async (
  collectionId: string | number,
  answerId: string | number,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/collections/' + collectionId + '/contents' +
      '?content_id=' + answerId + '&content_type=answer',
  );
  return res.data;
};

/**
 * 从收藏夹中删除
 * DELETE /collections/{collection_id}/contents/{answer_id}?content_type=answer
 */
export const removeFromCollection = async (
  collectionId: string | number,
  answerId: string | number,
): Promise<object> => {
  const res = await zhihuClient.delete<object>(
    API_V4 + '/collections/' + collectionId + '/contents/' + answerId +
      '?content_type=answer',
  );
  return res.data;
};

/**
 * 快速收藏到默认收藏夹
 * POST /collections/contents/answer/{answer_id}
 */
export const fastCollectAnswer = async (
  answerId: string | number,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/collections/contents/answer/' + answerId,
  );
  return res.data;
};

// ---------------------------------------------------------------------------
// 文章收藏状态 / 添加 / 移除
// ---------------------------------------------------------------------------

/**
 * 获取文章被收藏的状态及所属收藏夹列表
 * GET /collections/contents/article/{article_id}
 */
export const getArticleCollectionStatus = async (
  articleId: string | number,
  limit: number = 100,
  offset: number = 0,
): Promise<CollectionStatusResponse> => {
  const res = await zhihuClient.get<CollectionStatusResponse>(
    API_V4 + '/collections/contents/article/' + articleId +
      '?limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

/**
 * 添加文章到收藏夹
 * POST /collections/{collection_id}/contents?content_id={article_id}&content_type=article
 */
export const addArticleToCollection = async (
  collectionId: string | number,
  articleId: string | number,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/collections/' + collectionId + '/contents' +
      '?content_id=' + articleId + '&content_type=article',
  );
  return res.data;
};

/**
 * 从收藏夹中删除文章
 * DELETE /collections/{collection_id}/contents/{article_id}?content_type=article
 */
export const removeArticleFromCollection = async (
  collectionId: string | number,
  articleId: string | number,
): Promise<object> => {
  const res = await zhihuClient.delete<object>(
    API_V4 + '/collections/' + collectionId + '/contents/' + articleId +
      '?content_type=article',
  );
  return res.data;
};

/**
 * 快速收藏文章到默认收藏夹
 * POST /collections/contents/article/{article_id}
 */
export const fastCollectArticle = async (
  articleId: string | number,
): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/collections/contents/article/' + articleId,
  );
  return res.data;
};
