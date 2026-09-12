/**
 * 搜索 API —— 移植自上游 zhihu--/api/zhihu/search.ts。
 * 改动：
 *   · axios(baseURL=https://www.zhihu.com/api/v4) → zhihuClient 直连绝对 URL
 *   · URLSearchParams(浏览器) → 手工 encodeURIComponent 拼接查询串
 *   · 去掉 AbortSignal（zhihuClient 暂不支持）
 */

import { zhihuClient } from './httpClient';
import { ZhihuSearchResponse } from '../model/zhihu';

const API_V4 = 'https://www.zhihu.com/api/v4';

export interface SearchContentOptions {
  restricted_scene?: string;
  restricted_field?: string;
  restricted_value?: string;
  vertical?: 'answer' | 'article' | 'zvideo';
  sort?: 'created_time' | 'upvoted_count';
  time_interval?:
    | 'a_day'
    | 'a_week'
    | 'a_month'
    | 'three_months'
    | 'half_a_year'
    | 'a_year';
}

export interface SearchSuggestion {
  // 上游未严格约束该结构；保留宽松字段供 UI 自取
  words?: string[];
  query?: string;
  hint?: string;
}

/** 搜索建议（自动补全） */
export const getSearchSuggest = async (
  query: string,
): Promise<SearchSuggestion> => {
  const res = await zhihuClient.get<SearchSuggestion>(
    API_V4 + '/search/suggest?q=' + encodeURIComponent(query),
  );
  return res.data;
};

/**
 * 综合/分类搜索（tab：综合 general / 回答 answer / 文章 article / 视频 zvideo …）
 * 垂直、排序、时间过滤会切换 search_source=Filter。
 */
export const searchContent = async (
  query: string,
  offset: number = 0,
  limit: number = 20,
  type: string = 'general',
  options?: SearchContentOptions,
): Promise<ZhihuSearchResponse> => {
  const segs: string[] = [];
  segs.push('t=' + encodeURIComponent(type));
  segs.push('q=' + encodeURIComponent(query));
  segs.push('correction=1');
  segs.push('offset=' + encodeURIComponent(String(offset)));
  segs.push('limit=' + encodeURIComponent(String(limit)));
  segs.push('filter_fields=');
  segs.push('lc_idx=0');
  segs.push('show_all_topics=0');
  let searchSource: string = 'Normal';

  if (options?.vertical) {
    segs.push('vertical=' + encodeURIComponent(options.vertical));
    segs.push('vertical_info=0,0,0,0,0,0,0,0,0,0,0,0');
    searchSource = 'Filter';
  }
  if (options?.sort) {
    segs.push('sort=' + encodeURIComponent(options.sort));
    searchSource = 'Filter';
  }
  if (options?.time_interval) {
    segs.push('time_interval=' + encodeURIComponent(options.time_interval));
    searchSource = 'Filter';
  }
  segs.push('search_source=' + encodeURIComponent(searchSource));

  if (options?.restricted_scene) {
    segs.push('restricted_scene=' + encodeURIComponent(options.restricted_scene));
  }
  if (options?.restricted_field) {
    segs.push('restricted_field=' + encodeURIComponent(options.restricted_field));
  }
  if (options?.restricted_value) {
    segs.push('restricted_value=' + encodeURIComponent(options.restricted_value));
  }

  const res = await zhihuClient.get<ZhihuSearchResponse>(
    API_V4 + '/search_v3?' + segs.join('&'),
  );
  return res.data;
};

/** 创作者后台：查询可回答的问题 */
export const searchCreatorQuestions = async (query: string): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 + '/creators/search/query?query=' + encodeURIComponent(query),
  );
  return res.data;
};

/** 收到的回答邀请列表 */
export const getInvitedQuestions = async (
  offset: number = 0,
  limit: number = 20,
): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 +
      '/notifications/v3/timeline/entry/invite?invite_with_time_slice=1' +
      '&limit=' + String(limit) +
      '&offset=' + String(offset) +
      '&invite_domain_score_ab=1',
  );
  return res.data;
};
