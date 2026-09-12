/**
 * 回答 API —— 移植自上游 zhihu--/api/zhihu/answer.ts。
 * 改动：
 *   · axios(baseURL=https://www.zhihu.com/api/v4) → zhihuClient（全 URL）
 *   · POST/DELETE JSON body → JSON.stringify(raw string) + Content-Type
 *   · voteAnswer 表单体 encodeURIComponent 拼 raw string
 *   · 上游 publishing → 本目录 ./publishing
 *   · 对象展开 → 显式构造；.map/.flatMap → 显式循环
 *   · 注：deleteAnswer/unreactAnswerSegment 走 zhihuClient.delete（与上游 DELETE 一致）。
 */

import { zhihuClient } from './httpClient';
import {
  ZhihuAuthor,
  ZhihuPaging,
  ZhihuQuestion,
  ZhihuSegmentInfo,
} from '../model/zhihu';
import {
  createPublishingTraceId,
  getPublishingTextLength,
  PublishedContentResult,
  parsePublishedContentResult,
} from './publishing';

const API_V4: string = 'https://www.zhihu.com/api/v4';
const JSON_CONTENT_TYPE: string = 'application/json';
const FORM_CONTENT_TYPE: string = 'application/x-www-form-urlencoded;charset=UTF-8';

export interface AnswerQuestion extends ZhihuQuestion {
  relationship?: ZhihuQuestion['relationship'] | null;
}

export interface AnswerReactionRelation {
  vote?: 'UP' | 'DOWN' | 'NEUTRAL';
  faved?: boolean;
  liked?: boolean;
}

export interface AnswerDetail {
  id: string | number;
  type?: 'answer';
  answer_type?: string;
  question?: AnswerQuestion;
  author: ZhihuAuthor;
  content: string;
  editable_content?: string;
  excerpt: string;
  created_time: number;
  created_time_name?: string;
  updated_time?: number;
  voteup_count: number;
  comment_count: number;
  favlists_count?: number;
  thanks_count?: number;
  visited_count?: number;
  reaction?: {
    relation?: AnswerReactionRelation;
  };
  relationship?: {
    upvoted_followees?: ZhihuAuthor[];
    is_author?: boolean;
    is_favorited?: boolean;
    is_thanked?: boolean;
    voting?: number;
  };
  segment_infos?: ZhihuSegmentInfo[];
  can_comment?: {
    status: boolean;
    reason: string;
  };
  allow_segment_interaction?: number;
  content_need_truncated?: boolean;
  extras?: string;
  force_login_when_click_read_more?: boolean;
  is_collapsed?: boolean;
  is_copyable?: boolean;
  is_jump_native?: boolean;
  url?: string;
  thumbnail?: string;
  content_img?: string[];
  biz_ext?: object;
  ip_info?: string;
  paid_info?: object;
  link_card_info?: Record<string, string>;
}

export interface QuestionAnswersResponse {
  data: AnswerDetail[];
  paging?: ZhihuPaging;
  read_count?: number;
}

export interface AnswerPublishOptions {
  answerId?: string | number;
  deltaTime?: number;
  tableOfContentsEnabled?: boolean;
}

export interface AnswerDraftSettings {
  can_reward: boolean;
  commercial_report_info: {
    is_report: boolean;
  };
  comment_permission: string;
  disclaimer_status: string;
  disclaimer_type: string;
  is_copyable: boolean;
  reshipment_settings: string;
  table_of_contents: {
    enabled: boolean;
  };
  table_of_contents_enabled: boolean;
  thank_inviter: string;
  thank_inviter_status: string;
}

/** Response returned by `POST /questions/{id}/draft`. */
export interface AnswerDraft {
  answer_type: string;
  attachment: Record<string, object> | null;
  content: string;
  created_time: number;
  draft_type: string;
  editable_content: string;
  excerpt: string;
  settings: AnswerDraftSettings;
  title: {
    enabled: boolean;
  };
  type: 'draft';
  updated_time: number;
  url: string;
}

interface AnswerDraftRequestSettings {
  can_reward: boolean;
  commercial_report_info: {
    is_report: boolean;
  };
  comment_permission: 'all';
  disclaimer_status: 'close';
  disclaimer_type: 'none';
  reshipment_settings: 'allowed';
  table_of_contents_enabled: boolean;
  tagline: string;
  thank_inviter: string;
  thank_inviter_status: 'close';
}

interface AnswerDraftRequest {
  content: string;
  delta_time: number;
  draft_type: 'normal';
  settings: AnswerDraftRequestSettings;
}

const ANSWER_PUBLISH_INCLUDE: string =
  'is_contain_ai_content,is_visible,paid_info,paid_info_content,has_column,admin_closed_comment,reward_info,annotation_action,annotation_detail,collapse_reason,is_normal,is_sticky,collapsed_by,suggest_edit,comment_count,thanks_count,favlists_count,can_comment,content,editable_content,voteup_count,reshipment_settings,comment_permission,created_time,updated_time,review_info,relevant_info,question,excerpt,attachment,content_source,is_labeled,endorsements,reaction_instruction,reaction,ip_info,relationship.is_authorized,voting,is_thanked,is_author,is_nothelp,is_favorited;author.vip_info,kvip_info,badge[*].topics;settings.table_of_content.enabled';

const DEFAULT_ANSWER_INCLUDE: string =
  'content,editable_content,paid_info,can_comment,excerpt,thanks_count,voteup_count,comment_count,visited_count,reaction,ip_info,question.topics,author.is_following,reaction.relation.voting,segment_infos,favlists_count';

export const getAnswer = async (
  id: string | number,
  include?: string,
): Promise<AnswerDetail> => {
  const res = await zhihuClient.get<AnswerDetail>(
    API_V4 + '/answers/' + String(id) + '?include=' + (include ?? DEFAULT_ANSWER_INCLUDE),
  );
  return res.data;
};

/**
 * 赞同/反对/取消赞同。
 * type: 'up'=赞同, 'down'=反对, 'neutral'=取消赞同。
 * 表单体为 form-urlencoded：type=up。
 */
export const voteAnswer = async (
  id: string | number,
  type: 'up' | 'neutral' | 'down',
): Promise<object> => {
  const body: string = 'type=' + encodeURIComponent(type);
  const res = await zhihuClient.post<object>(
    API_V4 + '/answers/' + String(id) + '/voters',
    {
      data: body,
      headers: { 'Content-Type': FORM_CONTENT_TYPE },
    },
  );
  return res.data;
};

export async function saveAnswerDraft(
  questionId: string | number,
  html: string,
  options: AnswerPublishOptions,
): Promise<AnswerDraft> {
  const tableOfContentsEnabled: boolean = options.tableOfContentsEnabled ?? false;
  const payload: AnswerDraftRequest = {
    content: html,
    draft_type: 'normal',
    delta_time: options.deltaTime ?? 0,
    settings: {
      reshipment_settings: 'allowed',
      comment_permission: 'all',
      can_reward: false,
      tagline: '',
      disclaimer_status: 'close',
      disclaimer_type: 'none',
      commercial_report_info: { is_report: false },
      table_of_contents_enabled: tableOfContentsEnabled,
      thank_inviter_status: 'close',
      thank_inviter: '',
    },
  };
  const referer: string = options.answerId !== undefined
    ? 'https://www.zhihu.com/question/' + String(questionId) + '/answer/' + String(options.answerId)
    : 'https://www.zhihu.com/question/' + String(questionId) + '/answer';
  const response = await zhihuClient.post<AnswerDraft>(
    API_V4 + '/questions/' + encodeURIComponent(String(questionId)) + '/draft',
    {
      data: JSON.stringify(payload),
      headers: {
        'Content-Type': JSON_CONTENT_TYPE,
        'Origin': 'https://www.zhihu.com',
        'Referer': referer,
      },
    },
  );
  return response.data;
}

export async function publishAnswer(
  questionId: string | number,
  html: string,
  options: AnswerPublishOptions,
): Promise<PublishedContentResult> {
  const tableOfContentsEnabled: boolean = options.tableOfContentsEnabled ?? false;
  const isPublished: boolean = options.answerId !== undefined;
  const questionIdString: string = String(questionId);
  const businessParams: string = JSON.stringify({
    is_paid_column: false,
    reward_setting: { can_reward: false, tagline: '' },
    disclaimer_status: 'close',
    disclaimer_type: 'none',
    commercial_report_info: { is_report: false },
    commercial_zhitask_bind_info: null,
    is_report: false,
    push_activity: true,
    table_of_contents_enabled: tableOfContentsEnabled,
    thank_inviter_status: 'close',
    thank_inviter: '',
  });

  const data: Record<string, object> = {
    publish: { traceId: createPublishingTraceId() },
    hybridInfo: {},
    extra_info: {
      question_id: questionIdString,
      publisher: 'pc',
      include: ANSWER_PUBLISH_INCLUDE,
      pc_business_params: businessParams,
    },
    hybrid: {
      html: html,
      textLength: getPublishingTextLength(html),
    },
    reprint: {},
    commentsPermission: {},
    appreciate: { can_reward: false, tagline: '' },
    publishSwitch: { draft_type: 'normal' },
    creationStatement: {
      disclaimer_status: 'close',
      disclaimer_type: 'none',
    },
    commercialReportInfo: { isReport: 0 },
    toFollower: {},
    contentsTables: {
      table_of_contents_enabled: tableOfContentsEnabled,
    },
    thanksInvitation: { thank_inviter_status: 'close', thank_inviter: '' },
  };
  if (isPublished) {
    data['draft'] = {
      contentId: String(options.answerId),
      isPublished: true,
      disabled: 1,
    };
  } else {
    data['draft'] = { isPublished: false, disabled: 1 };
  }
  const payload: Record<string, ESObject> = {
    action: 'answer',
    data: data,
  };
  const res = await zhihuClient.post<object>(
    API_V4 + '/content/publish',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return parsePublishedContentResult(res.data);
}

export const createAnswer = async (
  questionId: string | number,
  html: string,
  options: AnswerPublishOptions,
): Promise<PublishedContentResult> => {
  await saveAnswerDraft(questionId, html, options);
  return publishAnswer(questionId, html, options);
};

export const updateAnswer = async (
  questionId: string | number,
  answerId: string | number,
  html: string,
  options: AnswerPublishOptions,
): Promise<PublishedContentResult> =>
  createAnswer(questionId, html, {
    answerId: answerId,
    deltaTime: options.deltaTime,
    tableOfContentsEnabled: options.tableOfContentsEnabled,
  });

/**
 * 删除回答：DELETE /answers/:id。
 */
export const deleteAnswer = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.delete<object>(
    API_V4 + '/answers/' + String(id),
  );
  return res.data;
};

export const reactAnswerSegment = async (
  answerId: string | number,
  segId: string,
  content: string,
  paragraphId: string,
  startOffset: number,
  endOffset: number,
): Promise<object> => {
  const payload: Record<string, ESObject> = {
    seg_id: segId,
    content: content,
    position: {
      start: { paragraph_id: paragraphId, offset: startOffset },
      end: { paragraph_id: paragraphId, offset: endOffset },
    },
  };
  const res = await zhihuClient.post<object>(
    API_V4 + '/reaction/answers/' + String(answerId) + '/segment_reaction',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return res.data;
};

export const createSegmentReaction = async (
  answerId: string | number,
  content: string,
  startParagraphId: string,
  startOffset: number,
  endParagraphId: string,
  endOffset: number,
): Promise<object> => {
  const payload: Record<string, ESObject> = {
    content: content,
    position: {
      start: { paragraph_id: startParagraphId, offset: startOffset },
      end: { paragraph_id: endParagraphId, offset: endOffset },
    },
  };
  const res = await zhihuClient.post<object>(
    API_V4 + '/reaction/answers/' + String(answerId) + '/segment_reaction',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return res.data;
};

/**
 * 取消段落反应：DELETE，body 为 form：seg_ids=...。
 */
export const unreactAnswerSegment = async (
  answerId: string | number,
  segId: string,
): Promise<object> => {
  const body: string = 'seg_ids=' + encodeURIComponent(segId);
  const res = await zhihuClient.delete<object>(
    API_V4 + '/reaction/answers/' + String(answerId) + '/segment_reaction',
    {
      data: body,
      headers: { 'Content-Type': FORM_CONTENT_TYPE },
    },
  );
  return res.data;
};

// ---------------- 段落评论 ----------------

interface SegmentCommentAuthor {
  member?: SegmentCommentAuthor;
}

interface SegmentComment {
  author?: SegmentCommentAuthor;
  relationship?: { voting: number };
  liked?: boolean;
  vote_count?: number;
  like_count?: number;
}

interface SegmentCommentsResponse {
  data?: SegmentComment[];
}

export const getSegmentComments = async (
  answerId: string | number,
  segmentId: string,
  limit: number = 20,
  offset: string = '',
): Promise<SegmentCommentsResponse> => {
  const res = await zhihuClient.get<SegmentCommentsResponse>(
    API_V4 + '/comment_v5/answers/' + String(answerId) +
      '/segment/root_comment?segment_id=' + encodeURIComponent(segmentId) +
      '&order_by=score&limit=' + String(limit) +
      '&offset=' + encodeURIComponent(offset),
  );
  // 基础标准化（V5 扁平化了作者结构）。原地修正，不使用展开运算符。
  const list = res.data.data;
  if (list) {
    for (let i = 0; i < list.length; i++) {
      const comment = list[i];
      if (comment.author && !comment.author.member) {
        const flatAuthor = comment.author;
        const nested: SegmentCommentAuthor = { member: flatAuthor };
        comment.author = nested;
      }
      if (!comment.relationship && comment.liked !== undefined) {
        comment.relationship = { voting: comment.liked ? 1 : 0 };
      }
      if (comment.vote_count === undefined && comment.like_count !== undefined) {
        comment.vote_count = comment.like_count;
      }
    }
  }
  return res.data;
};
