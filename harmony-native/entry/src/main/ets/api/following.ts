/**
 * 「我关注的」列表 API —— 移植自上游 zhihu--/api/zhihu/following.ts。
 * 覆盖：关注的专栏 / 话题 / 问题 / 收藏夹。
 * 改动：
 *   · axios(baseURL=…/api/v4) → zhihuClient 绝对 URL
 *   · axios params → 手工拼接查询串
 *   · 上游本地 ZhihuTopic 与 model/zhihu.ts 的轻量 ZhihuTopic 重名，
 *     这里更名为 ZhihuFollowingTopic 避免歧义。
 */

import { zhihuClient } from './httpClient';
import { ZhihuAuthor, ZhihuPaging } from '../model/zhihu';

const API_V4 = 'https://www.zhihu.com/api/v4';

export interface ZhihuFollowingColumnItem {
  id: string;
  title: string;
  intro: string;
  excerpt: string;
  image_url: string;
  url: string;
  type: 'column';
  column_type: string;
  updated: number;
  voteup_count: number;
  followers: number;
  articles_count: number;
  items_count: number;
  purchase_count: number;
  accept_submission: boolean;
  comment_permission: string;
  author: ZhihuAuthor;
}

export interface ZhihuFollowingColumnsResponse {
  paging: ZhihuPaging;
  data: ZhihuFollowingColumnItem[];
}

/** 上游 following.ts 内的富话题类型（model/zhihu.ts 的 ZhihuTopic 为轻量版） */
export interface ZhihuFollowingTopic {
  id: string;
  type: 'topic';
  url: string;
  name: string;
  avatar_url: string;
  meta_avatar_url: string;
  excerpt: string;
  introduction: string;
  category: string;
  is_black: boolean;
  is_vote: boolean;
  is_following: boolean;
  is_super_topic_vote: boolean;
  followers_count: number;
  questions_count: number;
  discuss_count: number;
  total_pv: number;
}

export interface ZhihuFollowingTopicContributionItem {
  topic: ZhihuFollowingTopic;
  contributions_count: number;
}

export interface ZhihuFollowingTopicsContributionsResponse {
  paging: ZhihuPaging;
  data: ZhihuFollowingTopicContributionItem[];
}

export interface ZhihuFollowingQuestionItem {
  id: string | number;
  type: 'question';
  title: string;
  url: string;
  created: number;
  updated_time: number;
  answer_count: number;
  follower_count: number;
  question_type: string;
  author: ZhihuAuthor;
}

export interface ZhihuFollowingQuestionsResponse {
  paging: ZhihuPaging;
  data: ZhihuFollowingQuestionItem[];
}

export interface ZhihuFollowingFavlistCreator {
  id: string;
  name: string;
  avatar_url: string;
  headline?: string;
  url_token: string;
}

export interface ZhihuFollowingFavlistItem {
  id: number;
  title: string;
  description: string;
  url: string;
  answer_count: number;
  follower_count: number;
  comment_count: number;
  updated_time: number;
  created_time: number;
  is_following: boolean;
  is_public: boolean;
  type: 'collection';
  creator: ZhihuFollowingFavlistCreator;
}

export interface ZhihuFollowingFavlistsResponse {
  paging: ZhihuPaging;
  data: ZhihuFollowingFavlistItem[];
}

/** GET /members/{id}/following-columns —— 关注的专栏 */
export const getMemberFollowingColumns = async (
  memberId: string | number,
  offset: number = 0,
  limit: number = 20,
): Promise<ZhihuFollowingColumnsResponse> => {
  const include =
    'data[*].intro,followers,articles_count,voteup_count,items_count';
  const res = await zhihuClient.get<ZhihuFollowingColumnsResponse>(
    API_V4 + '/members/' + encodeURIComponent(String(memberId)) +
      '/following-columns?include=' + include +
      '&offset=' + String(offset) + '&limit=' + String(limit),
  );
  return res.data;
};

/** GET api/v5.1/topics/{id}/following_topics_contributions —— 关注的话题 */
export const getMemberFollowingTopics = async (
  memberId: string | number,
  offset: number = 0,
  limit: number = 20,
): Promise<ZhihuFollowingTopicsContributionsResponse> => {
  const include = 'data[*].topic.introduction';
  const res = await zhihuClient.get<ZhihuFollowingTopicsContributionsResponse>(
    'https://www.zhihu.com/api/v5.1/topics/' +
      encodeURIComponent(String(memberId)) +
      '/following_topics_contributions?include=' + include +
      '&offset=' + String(offset) + '&limit=' + String(limit),
  );
  return res.data;
};

/** GET /members/{id}/following-questions —— 关注的问题 */
export const getMemberFollowingQuestions = async (
  memberId: string | number,
  offset: number = 0,
  limit: number = 20,
): Promise<ZhihuFollowingQuestionsResponse> => {
  const include = 'data[*].created,answer_count,follower_count,author';
  const res = await zhihuClient.get<ZhihuFollowingQuestionsResponse>(
    API_V4 + '/members/' + encodeURIComponent(String(memberId)) +
      '/following-questions?include=' + include +
      '&offset=' + String(offset) + '&limit=' + String(limit),
  );
  return res.data;
};

/** GET /members/{id}/following-favlists —— 关注的收藏夹 */
export const getMemberFollowingFavlists = async (
  memberId: string | number,
  offset: number = 0,
  limit: number = 20,
): Promise<ZhihuFollowingFavlistsResponse> => {
  const include =
    'data[*].updated_time,answer_count,follower_count,creator,description,is_following,comment_count,created_time';
  const res = await zhihuClient.get<ZhihuFollowingFavlistsResponse>(
    API_V4 + '/members/' + encodeURIComponent(String(memberId)) +
      '/following-favlists?include=' + include +
      '&offset=' + String(offset) + '&limit=' + String(limit),
  );
  return res.data;
};
