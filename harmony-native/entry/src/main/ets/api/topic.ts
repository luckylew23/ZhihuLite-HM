/**
 * 话题 API —— 移植自上游 zhihu--/api/zhihu/topic.ts。
 * 覆盖：话题详情、话题下 hot/精华/未回答 feed、关注/取关话题、父/子话题、优秀回答者。
 * 改动：axios(baseURL=…/api/v4) → zhihuClient 绝对 URL；去掉 AbortSignal。
 */

import { zhihuClient } from './httpClient';

const API_V4 = 'https://www.zhihu.com/api/v4';

export const TOPIC_INCLUDE =
  'introduction,questions_count,best_answers_count,followers_count,is_following,header_card';

export interface ZhihuTopicFeedResponse {
  data: object[];
  paging: {
    is_end: boolean;
    is_start?: boolean;
    next: string;
    previous?: string;
  };
}

export const getTopic = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) +
      '?include=' + TOPIC_INCLUDE,
  );
  return res.data;
};

/**
 * 话题下 feed。
 * @param type 'hot'=最热 | 'top-answers'=精华 | 'unanswered'=未回答，其余原样透传
 */
export const getTopicFeed = async (
  id: string | number,
  type: string = 'hot',
  offset: number = 0,
): Promise<ZhihuTopicFeedResponse> => {
  const typeMapping: Record<string, string> = {
    hot: 'hot',
    'top-answers': 'essence',
    unanswered: 'top_question',
  };
  const feedType: string = typeMapping[type] !== undefined ? typeMapping[type] : type;
  const include =
    'data[*].target.content,voteup_count,comment_count,author.name,author.avatar_url,author.headline,author.is_following,relationship.voting,relationship.is_author,created_time,segment_infos';
  const res = await zhihuClient.get<ZhihuTopicFeedResponse>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) +
      '/feeds/' + feedType +
      '?include=' + include + '&limit=20&offset=' + String(offset),
  );
  return res.data;
};

export const followTopic = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) + '/followers',
  );
  return res.data;
};

export const unfollowTopic = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.delete<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) + '/followers',
  );
  return res.data;
};

export const getTopicParents = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) + '/parent',
  );
  return res.data;
};

export const getTopicChildren = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) + '/children',
  );
  return res.data;
};

export const getBestAnswerers = async (
  id: string | number,
  limit: number = 3,
): Promise<object> => {
  const res = await zhihuClient.get<object>(
    API_V4 + '/topics/' + encodeURIComponent(String(id)) +
      '/best_answerers?limit=' + String(limit),
  );
  return res.data;
};
