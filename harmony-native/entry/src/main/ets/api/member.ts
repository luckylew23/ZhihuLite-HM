/**
 * 用户主页 / 关系 API —— 移植自上游 zhihu--/api/zhihu/member.ts。
 * 改动：
 *   · axios(baseURL=…/api/v4) → zhihuClient 绝对 URL
 *   · 禁对象/数组展开：getRecentMemberActivities 的归一化改为逐字段显式拷贝
 *   · Partial<>/Omit<>/索引签名 → 本文件内具体可选字段
 *   · 去掉 AbortSignal；getRecentActivityTargetId 内联（上游 utils/userProfile）
 */

import { zhihuClient, ApiError } from './httpClient';
import { getZhihuAppEndpointHeaders } from './appApi';
import {
  ZhihuAuthor,
  ZhihuMemberRelation,
  ZhihuPaging,
} from '../model/zhihu';

const API_V4 = 'https://www.zhihu.com/api/v4';

export const MEMBER_INCLUDE =
  'url_token,answer_count,articles_count,question_count,pins_count,follower_count,following_count,headline,cover_url,description,voteup_count,thanked_count,favorited_count,is_following,mutual_followees_count';

export const MEMBER_ANSWERS_INCLUDE =
  'data[*].is_normal,admin_closed_comment,reward_info,is_collapsed,annotation_action,annotation_detail,collapse_reason,collapsed_by,suggest_edit,comment_count,can_comment,content,editable_content,attachment,voteup_count,reshipment_settings,comment_permission,created_time,updated_time,review_info,excerpt,paid_info,reaction_instruction,is_labeled,label_info,relationship.is_authorized,voting,is_author,is_thanked,is_nothelp,reaction,vessay_info;data[*].author.badge[?(type=best_answerer)].topics;data[*].author.kvip_info;data[*].author.vip_info;data[*].question.has_publishing_draft,relationship';

const MEMBER_FALLBACK_INCLUDE =
  'id,url_token,name,avatar_url,follower_count,following_count,headline,cover_url,description,answer_count,articles_count,question_count,pins_count,voteup_count,is_following,mutual_followees_count';

export interface ZhihuMember extends ZhihuAuthor {
  answer_count?: number;
  articles_count?: number;
  question_count?: number;
  pins_count?: number;
  follower_count?: number;
  following_count?: number;
  cover_url?: string;
  description?: string;
  voteup_count?: number;
  thanked_count?: number;
  favorited_count?: number;
  mutual_followees_count?: number;
}

export interface ZhihuMemberListItem extends ZhihuMember {
  is_followed?: boolean;
}

export interface ZhihuListResponse<T> {
  data: T[];
  paging: ZhihuPaging;
}

export interface ZhihuMemberActivitySource {
  action_text?: string;
  action_time?: number;
  action_type?: string;
}

export interface ZhihuMemberActivityContentSegment {
  type: string;
  content?: string;
  own_text?: string;
  url?: string;
  data_draft_cover?: string;
}

export interface ZhihuMemberActivityQuestionRef {
  id?: string | number;
  title?: string;
}

export interface ZhihuMemberActivityTarget {
  id?: string | number;
  type?: string;
  url?: string;
  title?: string;
  excerpt?: string;
  excerpt_title?: string;
  content?: string | ZhihuMemberActivityContentSegment[];
  image_url?: string;
  thumbnail?: string;
  voteup_count?: number;
  reaction_count?: number;
  comment_count?: number;
  favlists_count?: number;
  created?: number;
  created_time?: number;
  relationship?: { voting?: number };
  author?: ZhihuAuthor;
  question?: ZhihuMemberActivityQuestionRef;
}

export interface ZhihuMemberActivity {
  id?: string | number;
  source?: ZhihuMemberActivitySource;
  target?: ZhihuMemberActivityTarget;
  type?: string;
  url?: string;
}

export interface ZhihuRecentActivityCursor {
  offset: number;
  pageNum: number;
}

/** 设备态原始（未归一化）活动条目 */
interface RawZhihuMemberActivityTarget {
  id?: string | number;
  type?: string;
  url?: string;
  created?: number;
  created_time?: number;
  reaction_relation?: { vote?: number | string };
  relationship?: { voting?: number | string };
}

interface RawZhihuMemberActivity {
  id?: string | number;
  source?: ZhihuMemberActivitySource;
  type?: string;
  url?: string;
  target?: RawZhihuMemberActivityTarget;
}

export interface ZhihuFollowResponse {
  follower_count?: number;
}

// ---------------------------------------------------------------------------
// 上游 utils/userProfile.getRecentActivityTargetId 的内联拷贝
// ---------------------------------------------------------------------------
/** 从完整 URL 取 pathname（等价 new URL(url).pathname，避免依赖浏览器 URL）。 */
function pathnameOf(urlText: string): string {
  let rest = urlText;
  const proto = rest.indexOf('//');
  if (proto >= 0) {
    rest = rest.substring(proto + 2);
  }
  const slash = rest.indexOf('/');
  if (slash < 0) {
    return '/';
  }
  let path = rest.substring(slash);
  const q = path.indexOf('?');
  if (q >= 0) {
    path = path.substring(0, q);
  }
  const h = path.indexOf('#');
  if (h >= 0) {
    path = path.substring(0, h);
  }
  return path;
}

function getRecentActivityTargetId(
  target: { id?: string | number; type?: string; url?: string },
): string | number | undefined {
  if (
    !target.url ||
    (target.type !== 'moments_pin' &&
      target.type !== 'pin' &&
      target.type !== 'pins')
  ) {
    return target.id;
  }
  try {
    const pathname: string = pathnameOf(target.url);
    const match = pathname.match(/^\/pins?\/([^/]+)$/);
    return match ? match[1] : target.id;
  } catch (e) {
    return target.id;
  }
}

function getErrorStatus(error: unknown): number | undefined {
  if (!error || typeof error !== 'object') {
    return undefined;
  }
  if (error instanceof ApiError) {
    return error.status;
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// 用户资料
// ---------------------------------------------------------------------------

export const getMember = async (
  id: string | number,
  include?: string,
): Promise<ZhihuMember> => {
  const res = await zhihuClient.get<ZhihuMember>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) +
      '?include=' + (include || MEMBER_INCLUDE),
  );
  return res.data;
};

export const getMemberWithFallback = async (
  id: string | number,
): Promise<ZhihuMember> => {
  try {
    return await getMember(id);
  } catch (error) {
    if (getErrorStatus(error) === 403) {
      return getMember(id, MEMBER_FALLBACK_INCLUDE);
    }
    throw error;
  }
};

/** 用户主页发布流（web v3 moments） */
export const getMemberActivities = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuListResponse<ZhihuMemberActivity>> => {
  const url =
    'https://www.zhihu.com/api/v3/moments/' + encodeURIComponent(String(id)) +
    '/activities?limit=' + String(limit) + '&offset=' + String(offset);
  const res = await zhihuClient.get<ZhihuListResponse<ZhihuMemberActivity>>(
    url,
    { headers: { 'x-api-version': '3.0.40' } },
  );
  return res.data;
};

/**
 * 「最近更新」入口：设备态 people 发布流（api.zhihu.com）。
 * 归一化 voting（字符串→数字）、pin id 从 URL 还原（超出 2^53）。
 */
export const getRecentMemberActivities = async (
  memberId: string | number,
  cursor: ZhihuRecentActivityCursor,
): Promise<ZhihuListResponse<ZhihuMemberActivity>> => {
  const url =
    'https://api.zhihu.com/moments/recent/people/' +
    encodeURIComponent(String(memberId)) +
    '?action=down&offset=' + String(cursor.offset) +
    '&page_num=' + String(cursor.pageNum);

  const headers: Record<string, string> = getZhihuAppEndpointHeaders(url);
  headers['x-api-version'] = '3.0.93';
  headers['x-page-id'] = '10103';

  const rawRes = await zhihuClient.get<ZhihuListResponse<RawZhihuMemberActivity>>(
    url,
    { headers: headers },
  );

  const normalized: ZhihuMemberActivity[] = [];
  const rawData: RawZhihuMemberActivity[] = rawRes.data.data;
  for (const activity of rawData) {
    const rawTarget = activity.target;
    if (!rawTarget) {
      normalized.push({
        id: activity.id,
        source: activity.source,
        type: activity.type,
        url: activity.url,
      });
      continue;
    }

    const votingRaw = rawTarget.relationship
      ? rawTarget.relationship.voting
      : (rawTarget.reaction_relation ? rawTarget.reaction_relation.vote : undefined);
    let normalizedVoting: number | undefined;
    if (votingRaw !== undefined) {
      const n = Number(votingRaw);
      normalizedVoting = Number.isFinite(n) ? n : undefined;
    }

    const target: ZhihuMemberActivityTarget = {
      id: getRecentActivityTargetId(rawTarget),
      type: rawTarget.type === 'moments_pin' ? 'pin' : rawTarget.type,
      url: rawTarget.url,
      created:
        rawTarget.created !== undefined
          ? rawTarget.created
          : (rawTarget.created_time !== undefined
            ? rawTarget.created_time
            : (activity.source ? activity.source.action_time : undefined)),
    };
    if (normalizedVoting !== undefined) {
      target.relationship = { voting: normalizedVoting };
    }

    normalized.push({
      id: activity.id,
      source: activity.source,
      type: activity.type,
      url: activity.url,
      target: target,
    });
  }

  const result: ZhihuListResponse<ZhihuMemberActivity> = {
    data: normalized,
    paging: rawRes.data.paging,
  };
  return result;
};

// ---------------------------------------------------------------------------
// 用户内容列表（回答/文章/提问/想法）
// ---------------------------------------------------------------------------

export interface MemberRelationsParams {
  limit?: number;
  offset?: number;
  include?: string;
  sort_by?: string;
  ws_qiangzhisafe?: number;
}

export const getMemberRelations = async (
  id: string | number,
  type: 'answers' | 'questions' | 'articles' | 'pins',
  params: MemberRelationsParams,
): Promise<ZhihuListResponse<ZhihuMemberRelation>> => {
  const segs: string[] = [];
  if (params.limit !== undefined) {
    segs.push('limit=' + String(params.limit));
  }
  if (params.offset !== undefined) {
    segs.push('offset=' + String(params.offset));
  }
  if (params.include !== undefined) {
    segs.push('include=' + params.include);
  }
  if (params.sort_by !== undefined) {
    segs.push('sort_by=' + encodeURIComponent(params.sort_by));
  }
  if (params.ws_qiangzhisafe !== undefined) {
    segs.push('ws_qiangzhisafe=' + String(params.ws_qiangzhisafe));
  }
  const query: string = segs.length > 0 ? '?' + segs.join('&') : '';
  const res = await zhihuClient.get<ZhihuListResponse<ZhihuMemberRelation>>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) + '/' + type + query,
  );
  return res.data;
};

// ---------------------------------------------------------------------------
// 关注 / 粉丝
// ---------------------------------------------------------------------------

export const followMember = async (
  id: string | number,
): Promise<ZhihuFollowResponse> => {
  const res = await zhihuClient.post<ZhihuFollowResponse>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) + '/followers',
  );
  return res.data;
};

export const unfollowMember = async (
  id: string | number,
): Promise<ZhihuFollowResponse> => {
  const res = await zhihuClient.delete<ZhihuFollowResponse>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) + '/followers',
  );
  return res.data;
};

const FOLLOWER_INCLUDE =
  'data[*].answer_count,articles_count,gender,follower_count,is_followed,is_following,badge[?(type=best_answerer)].topics';

export const getMemberFollowers = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuListResponse<ZhihuMemberListItem>> => {
  const res = await zhihuClient.get<ZhihuListResponse<ZhihuMemberListItem>>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) +
      '/followers?include=' + FOLLOWER_INCLUDE +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

export const getMemberFollowing = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuListResponse<ZhihuMemberListItem>> => {
  const res = await zhihuClient.get<ZhihuListResponse<ZhihuMemberListItem>>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) +
      '/followees?include=' + FOLLOWER_INCLUDE +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

export const getMemberMutual = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuListResponse<ZhihuMemberListItem>> => {
  const res = await zhihuClient.get<ZhihuListResponse<ZhihuMemberListItem>>(
    API_V4 + '/members/' + encodeURIComponent(String(id)) +
      '/relations/mutuals?include=' + FOLLOWER_INCLUDE +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};
