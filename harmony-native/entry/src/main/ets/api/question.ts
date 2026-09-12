/**
 * 问题 API —— 移植自上游 zhihu--/api/zhihu/question.ts。
 * 改动：
 *   · axios baseURL → zhihuClient 全 URL；登录态走 www.zhihu.com/api/v4，
 *     游客态走设备端点 api.zhihu.com（合并 getZhihuAppEndpointHeaders）
 *   · useAuthStore → ../store/authStore（authStore.cookies）
 *   · appApi 未导出 question 相关 builder，本文件内用 @kit.ArkTS URL 自建
 *   · new URL → url.URL
 */

import { url } from '@kit.ArkTS';

const URL_CTOR = url.URL;

import { zhihuClient } from './httpClient';
import { authStore, hasAuthenticationCookie } from '../store/authStore';
import { getZhihuAppEndpointHeaders } from './appApi';
import { ZhihuPaging, ZhihuQuestion } from '../model/zhihu';
import {
  AnswerDetail,
  AnswerQuestion,
  QuestionAnswersResponse,
} from './answer';
import {
  normalizeZhihuAppQuestionFeeds,
  NormalizedQuestionFeedsResult,
  ZhihuAppQuestionFeedsResponse,
} from './questionFeed';
import {
  createPublishingTraceId,
  PublishedContentResult,
  parsePublishedContentResult,
} from './publishing';

const API_V4: string = 'https://www.zhihu.com/api/v4';
const APP_BASE: string = 'https://api.zhihu.com';
const JSON_CONTENT_TYPE: string = 'application/json';

const APP_QUESTION_INCLUDE: string = 'read_count,query_info,voteup_count,voting,can_vote';
const APP_QUESTION_FEEDS_INCLUDE: string =
  'big_card_summary,media_detail,reaction_instruction,is_author,is_thanked,voting,is_favorited,label_info,content_text_length,reactions';

export type ZhihuQuestionBrief = AnswerQuestion;
export type ZhihuAnswer = AnswerDetail;
export type ZhihuAnswersPaging = ZhihuPaging;
export type ZhihuAnswersResponse = QuestionAnswersResponse;

export interface ZhihuQuestionDetail extends ZhihuQuestion {
  detail?: string;
  excerpt?: string;
  answer_count?: number;
  comment_count?: number;
  follower_count?: number;
  visit_count?: number;
  link_card_info?: Record<string, string>;
}

export interface ZhihuAppRelatedObject {
  id?: string | number;
  type?: string;
  target?: Record<string, object>;
}

export interface ZhihuAppRelatedObjectsResponse {
  data: ZhihuAppRelatedObject[];
  paging?: ZhihuPaging;
}

export const QUESTION_INCLUDE: string =
  'detail,excerpt,answer_count,comment_count,follower_count,visit_count,topics,relationship.is_following,relationship.is_author,relationship.is_anonymous,relationship.voting,relationship.is_thanked,relationship.is_nothelp,relationship.my_answer';

// ---------------- 设备态（api.zhihu.com）URL builder ----------------

function buildZhihuAppQuestionUrl(
  questionId: string | number,
  include: string,
): string {
  const parsed = new URL_CTOR(
    '/questions/' + encodeURIComponent(String(questionId)),
    APP_BASE,
  );
  parsed.searchParams.set('include', include);
  return parsed.toString();
}

function buildZhihuAppQuestionFeedsUrl(
  questionId: string | number,
  order: string,
  limit: number,
  offset: number,
): string {
  const parsed = new URL_CTOR(
    '/questions/' + encodeURIComponent(String(questionId)) + '/feeds',
    APP_BASE,
  );
  parsed.searchParams.set('include', APP_QUESTION_FEEDS_INCLUDE);
  parsed.searchParams.set('order', order);
  parsed.searchParams.set('show_detail', '1');
  parsed.searchParams.set('limit', String(limit));
  parsed.searchParams.set('offset', String(offset));
  return parsed.toString();
}

function buildZhihuAppRelatedObjectsUrl(
  questionId: string | number,
  isSearch: boolean,
): string {
  const parsed = new URL_CTOR(
    '/questions/' + encodeURIComponent(String(questionId)) + '/related-objects',
    APP_BASE,
  );
  parsed.searchParams.set('is_search', isSearch ? '1' : '0');
  return parsed.toString();
}

// ---------------- 接口 ----------------

export const getQuestion = async (
  id: string | number,
  include?: string,
): Promise<ZhihuQuestionDetail> => {
  if (hasAuthenticationCookie(authStore.cookies)) {
    const res = await zhihuClient.get<ZhihuQuestionDetail>(
      API_V4 + '/questions/' + String(id) + '?include=' + (include ?? QUESTION_INCLUDE),
    );
    return res.data;
  }

  const requestUrl = buildZhihuAppQuestionUrl(id, include ?? QUESTION_INCLUDE);
  const res = await zhihuClient.get<ZhihuQuestionDetail>(requestUrl, {
    headers: getZhihuAppEndpointHeaders(requestUrl),
  });
  return res.data;
};

function parseOffsetFromUrl(urlText: string): number {
  try {
    const parsed = new URL_CTOR(urlText, APP_BASE);
    const raw = parsed.searchParams.get('offset');
    return raw !== null ? Number(raw) : 0;
  } catch (e) {
    return 0;
  }
}

export const getQuestionAnswers = async (
  id: string | number,
  pageParam: number | string,
  sortBy: 'default' | 'created',
  include: string,
): Promise<QuestionAnswersResponse> => {
  const isAuthenticated: boolean = hasAuthenticationCookie(authStore.cookies);
  const offset: number =
    typeof pageParam === 'number' ? pageParam : parseOffsetFromUrl(pageParam);

  if (isAuthenticated) {
    const res = await zhihuClient.get<QuestionAnswersResponse>(
      API_V4 + '/questions/' + String(id) + '/answers' +
        '?include=' + include + '&limit=20&offset=' + String(offset) +
        '&sort_by=' + sortBy,
    );
    return res.data;
  }

  const requestUrl: string =
    typeof pageParam === 'string'
      ? pageParam
      : buildZhihuAppQuestionFeedsUrl(
          id,
          sortBy === 'created' ? 'updated' : 'default',
          10,
          offset,
        );
  const res = await zhihuClient.get<ZhihuAppQuestionFeedsResponse>(requestUrl, {
    headers: getZhihuAppEndpointHeaders(requestUrl),
  });
  const normalized: NormalizedQuestionFeedsResult = normalizeZhihuAppQuestionFeeds(res.data);
  return {
    data: normalized.data,
    paging: normalized.paging,
    read_count: normalized.read_count,
  };
};

export const getRelatedQuestionObjects = async (
  id: string | number,
  isSearch: boolean,
): Promise<ZhihuAppRelatedObjectsResponse> => {
  const requestUrl = buildZhihuAppRelatedObjectsUrl(id, isSearch);
  const res = await zhihuClient.get<ZhihuAppRelatedObjectsResponse>(requestUrl, {
    headers: getZhihuAppEndpointHeaders(requestUrl),
  });
  return res.data;
};

export const followQuestion = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.post<object>(
    API_V4 + '/questions/' + String(id) + '/followers',
    { data: '' },
  );
  return res.data;
};

/** 取消关注问题：DELETE。 */
export const unfollowQuestion = async (id: string | number): Promise<object> => {
  const res = await zhihuClient.delete<object>(
    API_V4 + '/questions/' + String(id) + '/followers',
  );
  return res.data;
};

export const createQuestion = async (
  title: string,
  html: string,
): Promise<PublishedContentResult> => {
  const payload: Record<string, ESObject> = {
    action: 'question',
    data: {
      publish: { traceId: createPublishingTraceId() },
      draft: { isPublished: false, disabled: 1 },
      question: {
        title: title,
        detail: html,
        topics: [],
        is_anonymous: false,
      },
    },
  };
  const res = await zhihuClient.post<object>(
    API_V4 + '/content/publish',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return parsePublishedContentResult(res.data);
};
