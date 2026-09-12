/**
 * 个人中心 API —— 移植自上游 zhihu--/api/zhihu/me.ts。
 * 注意：原生 http.request 需要完整 URL，所有路径均拼 API_V4 前缀（v1.3.0 修复）。
 */

import { zhihuClient } from './httpClient';
import { ZhihuMemberRelation, ZhihuPaging } from '../model/zhihu';

const API_V4: string = 'https://www.zhihu.com/api/v4';

export interface ZhihuMeInfo {  id: string;
  url_token: string;
  name: string;
  avatar_url: string;
  avatar_url_template: string;
  is_org: boolean;
  type: string;
  url: string;
  user_type: string;
  headline: string;
  gender: number;
  is_advertiser: boolean;
  answer_count: number;
  question_count: number;
  articles_count: number;
  columns_count: number;
  zvideo_count: number;
  favorite_count: number;
  pins_count: number;
  voteup_count: number;
  thanked_count: number;
  following_question_count: number;
  /** 关注数 / 粉丝数：/me include 可能不下发，缺省由 UI 降级为 0。 */
  following_count?: number;
  followers_count?: number;
  is_bind_phone: boolean;
  is_realname: boolean;
  default_notifications_count: number;
  follow_notifications_count: number;
  vote_thank_notifications_count: number;
  messages_count: number;
  draft_count: number;
}

export const getMe = async (): Promise<ZhihuMeInfo> => {
  const include =
    'id,ad_type,email,account_status,is_bind_phone,available_message_types,' +
    'default_notifications_count,follow_notifications_count,' +
    'vote_thank_notifications_count,messages_count,is_org,avatar_url,name,' +
    'url_token,draft_count,following_question_count,is_realname,' +
    'is_force_renamed,renamed_fullname,is_destroy_waiting,' +
    'following_count,followers_count';
  const res = await zhihuClient.get<ZhihuMeInfo>(
    API_V4 + '/me?include=' + include,
  );
  return res.data;
};

export const getMyLikes = async (
  type: 'answers' | 'articles',
  limit: number,
  offset: number,
): Promise<{ data: ZhihuMemberRelation[]; paging: ZhihuPaging }> => {
  const endpoint = type === 'answers' ? 'voted_answers' : 'voted_articles';
  const include =
    'data[*].content,voteup_count,comment_count,created_time,updated_time,' +
    'excerpt,question.title,relationship.voting';
  const res = await zhihuClient.get<{
    data: ZhihuMemberRelation[];
    paging: ZhihuPaging;
  }>(
    API_V4 + '/members/me/' + endpoint + '?limit=' + String(limit) +
    '&offset=' + String(offset) + '&include=' + include,
  );
  return res.data;
};
