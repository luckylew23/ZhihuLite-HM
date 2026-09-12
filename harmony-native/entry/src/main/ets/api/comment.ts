/**
 * 评论 API —— 移植自上游 zhihu--/api/zhihu/comment.ts。
 * ----------------------------------------------------------------------------
 * 改动：
 *   · axios → zhihuClient.get/post/delete；POST body 为 JSON.stringify 的 raw string。
 *   · 禁止展开运算符：normalizeComment 的浅拷贝改用 Object.assign。
 *   · unknown → object（ArkTS 类型严格）；去掉接口索引签名。
 *   · 上游 axios 相对路径（baseURL=https://www.zhihu.com/api/v4）改为全 URL。
 */

import { zhihuClient, ApiResponse } from './httpClient';

const API_V4: string = 'https://www.zhihu.com/api/v4';

// ---------------------------------------------------------------------------
// 类型（对应上游 comment.ts；ZhihuVoteResponse 原自 voters.ts，本文件内重定义）
// ---------------------------------------------------------------------------

export interface ZhihuVoteResponse {
  success?: boolean;
}

export interface CommentVipIcon {
  url?: string;
  night_mode_url?: string;
}

export interface CommentVipInfo {
  is_vip: boolean;
  target_url?: string | null;
  vip_icon?: CommentVipIcon;
}

export interface CommentBadge {
  type: string;
  description: string;
}

export interface CommentBadgeV2 {
  title: string;
  merged_badges: object[] | null;
  detail_badges: object[] | null;
}

export interface CommentExposedMedal {
  medal_id: string;
  medal_name: string;
  avatar_url: string;
  description: string;
  medal_avatar_frame: string;
  can_click: boolean;
}

export interface CommentMember {
  id: string;
  url_token: string;
  name: string;
  avatar_url: string;
  avatar_url_template?: string;
  is_org?: boolean;
  type?: string;
  url?: string;
  user_type?: string;
  headline?: string;
  badge?: CommentBadge[];
  badge_v2?: CommentBadgeV2;
  exposed_medal?: CommentExposedMedal;
  gender?: number;
  is_advertiser?: boolean;
  vip_info?: CommentVipInfo;
  kvip_info?: CommentVipInfo;
  level_info?: object | null;
  is_anonymous?: boolean;
  ring_info?: object | null;
}

export interface CommentAuthor {
  role?: string;
  member: CommentMember;
}

export interface CommentTag {
  type: string;
  text: string;
  color?: string;
  night_color?: string;
  has_border?: boolean;
  border_color?: string;
  border_night_color?: string;
}

export interface CommentItem {
  id: number | string;
  type: string;
  resource_type?: string;
  member_id?: number | string;
  url?: string;
  content: string;
  score?: number;
  comment_type?: number;
  created_time: number;
  is_delete?: boolean;
  reviewing?: boolean;
  reply_comment_id?: number | string | null;
  reply_root_comment_id?: number | string | null;
  liked?: boolean;
  like_count?: number;
  disliked?: boolean;
  dislike_count?: number;
  is_author?: boolean;
  can_like?: boolean;
  can_dislike?: boolean;
  can_delete?: boolean;
  can_reply?: boolean;
  can_hot?: boolean;
  can_author_top?: boolean;
  is_author_top?: boolean;
  can_share?: boolean;
  can_unfold?: boolean;
  can_truncate?: boolean;
  can_more?: boolean;
  comment_tag?: CommentTag[];
  author_tag?: CommentTag[];
  reply_author_tag?: CommentTag[];
  content_tag?: CommentTag[];
  featured?: boolean;
  top?: boolean;
  collapsed?: boolean;
  allow_like?: boolean;
  allow_delete?: boolean;
  allow_reply?: boolean;
  allow_vote?: boolean;
  can_recommend?: boolean;
  can_collapse?: boolean;
  attached_info?: string;
  author: CommentAuthor;
  vote_count?: number;
  reply_to_author?: CommentAuthor | null;
  voting?: boolean;
  censor_status?: number;
  address_text?: string;
  child_comment_count: number;
  child_comment_next_offset?: string | number | null;
  child_comments: CommentItem[];
  relationship?: {
    voting: number;
  };
  is_visible_only_to_myself?: boolean;
  _?: object;
  level_tag?: number;
  is_gift?: boolean;
  disclaimer_info?: object | null;
}

export interface CommentStatus {
  type?: number;
  text?: string;
  induce_text?: string;
  can_comment?: boolean;
  can_reply?: boolean;
  toast?: string;
}

export interface CommentAtmosphereVotingDetail {
  emoji_level: string;
  title: string;
  normal_icon: string;
  selected_icon: string;
}

export interface CommentAtmosphereVotingConfig {
  daily_frequency: number;
  frequency_interval: number;
  min_num_of_root_comment: number;
  location: number;
  title: string;
  detail: CommentAtmosphereVotingDetail[];
}

export interface CommentCounts {
  total_counts: number;
  collapsed_counts: number;
  reviewing_counts: number;
  segment_comment_counts: number;
}

export interface CommentPermission {
  permission: string;
  text: string;
  checked: boolean;
  disable: boolean;
  disable_alert: string;
  icon: string;
}

export interface CommentEditStatus {
  can_reply: boolean;
  toast: string;
}

export interface CommentSorter {
  type: string;
  text: string;
}

export interface CommentPaging {
  is_end: boolean;
  is_start: boolean;
  next: string;
  previous: string;
  totals: number;
}

export interface ZhihuCommentResponse {
  ad_plugin_infos?: object[];
  atmosphere_voting_config?: CommentAtmosphereVotingConfig;
  featured_counts?: number;
  common_counts?: number;
  collapsed_counts?: number;
  reviewing_counts?: number;
  counts?: CommentCounts;
  comment_status?: CommentStatus;
  current_permission?: CommentPermission;
  edit_status?: CommentEditStatus;
  header?: object[];
  is_content_author?: boolean;
  is_content_rewardable?: boolean;
  paging: CommentPaging;
  data: CommentItem[];
  sorter?: CommentSorter[];
}

export interface DeleteCommentResponse {
  success: boolean;
}

export type CommentResourceType = 'answers' | 'questions' | 'articles' | 'pins';

export interface CreateCommentResponse {
  id?: string | number;
  type?: string;
  content?: string;
  reply_comment_id?: string | number | null;
  reply_root_comment_id?: string | number | null;
}

export interface CreateCommentPayload {
  content: string;
  type: string;
  reply_comment_id?: string | number;
}

function jsonPost<T>(url: string, body: object): Promise<T> {
  return zhihuClient
    .post<T>(url, {
      data: JSON.stringify(body),
      headers: { 'Content-Type': 'application/json' },
    })
    .then((res: ApiResponse<T>) => res.data);
}

// ---------------------------------------------------------------------------
// 评论读取
// ---------------------------------------------------------------------------

export const getComment = async (id: string | number): Promise<CommentItem> => {
  const res = await zhihuClient.get<CommentItem>(API_V4 + '/comments/' + id);
  return normalizeComment(res.data as object);
};

export const getAnswerComments = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuCommentResponse> => {
  const include =
    'data[*].author,content,child_comment_count,child_comments,vote_count,created_time';
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/answers/' + id + '/root_comments?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + include,
  );
  if (res.data.data) {
    res.data.data = normalizeList(res.data.data);
  }
  return res.data;
};

export const createAnswerComment = async (
  id: string | number,
  content: string,
): Promise<CreateCommentResponse> => {
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/answers/' + id + '/comments',
    { content: content, type: 'comment' },
  );
};

export const getChildComments = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuCommentResponse> => {
  const include =
    'data[*].author,vote_count,content,created_time,reply_to_author';
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comments/' + id + '/child_comments?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + include,
  );
  if (res.data.data) {
    res.data.data = normalizeList(res.data.data);
  }
  return res.data;
};

export const getCommentReplies = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuCommentResponse> => {
  const include =
    'data[*].author,content,vote_count,created_time,reply_to_comment';
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comments/' + id + '/replies?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + include,
  );
  if (res.data.data) {
    res.data.data = normalizeList(res.data.data);
  }
  return res.data;
};

export const createCommentReply = async (
  id: string | number,
  content: string,
  extra?: Record<string, object>,
): Promise<CreateCommentResponse> => {
  const payload: Record<string, ESObject> = { content: content, type: 'comment' };
  if (extra !== undefined) {
    const keys = Object.keys(extra);
    for (const k of keys) {
      payload[k] = extra[k];
    }
  }
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/comments/' + id + '/replies',
    payload,
  );
};

export const voteComment = async (
  id: string | number,
  type: string,
): Promise<ZhihuVoteResponse> => {
  const endpoint =
    '/comments/' + encodeURIComponent(String(id)) + '/like';
  if (type === 'up') {
    const res = await zhihuClient.post<ZhihuVoteResponse>(API_V4 + endpoint);
    return res.data;
  }
  const res = await zhihuClient.delete<ZhihuVoteResponse>(API_V4 + endpoint);
  return res.data;
};

export const getQuestionComments = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuCommentResponse> => {
  const include =
    'data[*].author,content,child_comment_count,child_comments,vote_count,created_time';
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/questions/' + id + '/root_comments?limit=' + String(limit) +
      '&offset=' + String(offset) + '&include=' + include,
  );
  if (res.data.data) {
    res.data.data = normalizeList(res.data.data);
  }
  return res.data;
};

export const createQuestionComment = async (
  id: string | number,
  content: string,
): Promise<CreateCommentResponse> => {
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/questions/' + id + '/comments',
    { content: content, type: 'comment' },
  );
};

// ---------------------------------------------------------------------------
// Comment V5
// ---------------------------------------------------------------------------

export const createCommentV5 = async (
  resourceType: CommentResourceType,
  resourceId: string | number,
  content: string,
  replyToCommentId?: string | number,
): Promise<CreateCommentResponse> => {
  const payload: CreateCommentPayload = {
    content: content,
    type: 'comment',
  };
  if (replyToCommentId !== undefined) {
    payload.reply_comment_id = replyToCommentId;
  }
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/comment_v5/' + resourceType + '/' +
      encodeURIComponent(String(resourceId)) + '/comment',
    payload as object,
  );
};

export const getAnswerCommentsV5 = async (
  id: string | number,
  limit: number = 20,
  offset: string | number = '',
  orderBy: string = 'score',
): Promise<ZhihuCommentResponse> => {
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comment_v5/answers/' + id + '/root_comment?order_by=' + orderBy +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  const list = res.data.data === undefined ? [] : res.data.data;
  res.data.data = normalizeList(list);
  return res.data;
};

export const getQuestionCommentsV5 = async (
  id: string | number,
  limit: number = 20,
  offset: string | number = '',
  orderBy: string = 'score',
): Promise<ZhihuCommentResponse> => {
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comment_v5/questions/' + id + '/root_comment?order_by=' + orderBy +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  const list = res.data.data === undefined ? [] : res.data.data;
  res.data.data = normalizeList(list);
  return res.data;
};

export const getArticleCommentsV5 = async (
  id: string | number,
  limit: number = 20,
  offset: string | number = '',
  orderBy: string = 'score',
): Promise<ZhihuCommentResponse> => {
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comment_v5/articles/' + id + '/root_comment?order_by=' + orderBy +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  const list = res.data.data === undefined ? [] : res.data.data;
  res.data.data = normalizeList(list);
  return res.data;
};

export const getPinCommentsV5 = async (
  id: string | number,
  limit: number = 20,
  offset: string | number = '',
  orderBy: string = 'score',
): Promise<ZhihuCommentResponse> => {
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comment_v5/pins/' + id + '/root_comment?order_by=' + orderBy +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  const list = res.data.data === undefined ? [] : res.data.data;
  res.data.data = normalizeList(list);
  return res.data;
};

export const createPinComment = async (
  id: string | number,
  content: string,
): Promise<CreateCommentResponse> => {
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/pins/' + id + '/comments',
    { content: content, type: 'comment' },
  );
};

export const createArticleComment = async (
  id: string | number,
  content: string,
): Promise<CreateCommentResponse> => {
  return jsonPost<CreateCommentResponse>(
    API_V4 + '/articles/' + id + '/comments',
    { content: content, type: 'comment' },
  );
};

export const getChildCommentsV5 = async (
  id: string | number,
  limit: number = 20,
  offset: string | number = '',
): Promise<ZhihuCommentResponse> => {
  const res = await zhihuClient.get<ZhihuCommentResponse>(
    API_V4 + '/comment_v5/comment/' + id + '/child_comment?order_by=ts' +
      '&limit=' + String(limit) + '&offset=' + String(offset),
  );
  const list = res.data.data === undefined ? [] : res.data.data;
  res.data.data = normalizeList(list);
  return res.data;
};

export const deleteComment = async (
  id: string | number,
): Promise<DeleteCommentResponse> => {
  const res = await zhihuClient.delete<DeleteCommentResponse>(
    API_V4 + '/comment_v5/comment/' + encodeURIComponent(String(id)),
  );
  return res.data;
};

// ---------------------------------------------------------------------------
// 评论数据规整（兼容 v4 / v5；禁止展开运算符，浅拷贝用 Object.assign）
// ---------------------------------------------------------------------------

function normalizeList(list: CommentItem[]): CommentItem[] {
  const out: CommentItem[] = [];
  for (const item of list) {
    out.push(normalizeComment(item as object));
  }
  return out;
}

function normalizeAuthor(value: object | undefined): CommentAuthor | undefined {
  if (value === undefined || value === null || typeof value !== 'object') {
    return undefined;
  }
  const rec = value as Record<string, object>;
  if (rec['member'] !== undefined && rec['member'] !== null) {
    const author: CommentAuthor = { member: rec['member'] as CommentMember };
    if (typeof rec['role'] === 'string') {
      author.role = rec['role'] as string;
    }
    return author;
  }
  return { member: value as CommentMember };
}

const normalizeComment = (raw: object): CommentItem => {
  const record = raw as Record<string, object>;
  const out: Record<string, object> = {};
  Object.assign(out, record);

  // 1. 作者结构（V5 把 author 扁平化了）
  const author = normalizeAuthor(out['author'] as object | undefined);
  if (author !== undefined) {
    out['author'] = author as object;
  }

  // 2. 回复对象的作者结构
  if (out['reply_to_author'] !== undefined && out['reply_to_author'] !== null) {
    const ra = normalizeAuthor(out['reply_to_author'] as object | undefined);
    out['reply_to_author'] = (ra === undefined ? null : ra) as object;
  }

  // 3. 点赞数（V5 是 like_count）
  if (out['vote_count'] === undefined && typeof out['like_count'] === 'number') {
    out['vote_count'] = out['like_count'];
  }

  // 4. 点赞状态（V5 是 liked）
  if (out['relationship'] === undefined && typeof out['liked'] === 'boolean') {
    out['relationship'] = {
      voting: (out['liked'] as boolean) ? 1 : 0,
    } as object;
  }

  // 5. 递归处理子评论
  const childRaw = out['child_comments'];
  if (Array.isArray(childRaw)) {
    const arr: object[] = [];
    for (const c of childRaw as object[]) {
      arr.push(normalizeComment(c));
    }
    out['child_comments'] = arr as object;
  }

  // 6. IP 属地（V5 在 comment_tag 里）
  const addr = out['address_text'];
  if ((addr === undefined || String(addr) === '') && Array.isArray(out['comment_tag'])) {
    const tags = out['comment_tag'] as object[];
    for (const t of tags) {
      const tagRec = t as Record<string, object>;
      if (String(tagRec['type']) === 'ip_info' && typeof tagRec['text'] === 'string') {
        out['address_text'] = tagRec['text'];
        break;
      }
    }
  }

  return out as unknown as CommentItem;
};
