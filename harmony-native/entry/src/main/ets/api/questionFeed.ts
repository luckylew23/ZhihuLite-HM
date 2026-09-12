/**
 * 问题下回答流（设备态 /questions/{id}/feeds）类型与归一化
 * —— 移植自上游 zhihu--/api/zhihu/questionFeed.ts。
 * 改动：
 *   · flatMap → 显式 push 循环
 *   · { ...target } 对象展开 → 显式逐字段构造
 *   · replaceAll → replace(/.../g)
 *   · Omit<Partial<AnswerDetail>, 'reaction'> → 显式接口（ArkTS 友好）
 * 本文件无网络请求；URL 构造在 question.ts 内。
 */

import { ZhihuPaging } from '../model/zhihu';
import {
  AnswerDetail,
  AnswerReactionRelation,
} from './answer';

/** The card envelope returned by `/questions/{id}/feeds`. */
export interface ZhihuAppQuestionFeedCard {
  type?: string;
  target_type?: string;
  target?: ZhihuAppQuestionFeedAnswer;
  cursor?: string;
  position?: number;
  skip_count?: boolean | number;
  is_jump_native?: boolean;
}

export interface ZhihuAppReaction {
  relation?: AnswerReactionRelation;
  statistics?: {
    down_vote_count?: number;
    favorites?: number;
    like_count?: number;
  };
}

export interface ZhihuAppReactionValue {
  count?: number;
  reacted?: boolean;
  reaction_type?: string;
  options?: Record<string, { count?: number }>;
}

export interface ZhihuAppMediaDetail {
  pdf_parsed_txt?: string;
  user_upload_parsed_content?: string;
}

export interface ZhihuAppRelevantInfo {
  is_relevant?: boolean;
  relevant_text?: string;
  relevant_type?: string;
}

export interface ZhihuAppThumbnailInfo {
  count?: number;
  thumbnails?: object[];
  type?: string;
}

/**
 * The App endpoint returns answer cards. `content` is present for some
 * answers, while `big_card_summary` is the only readable body for others.
 */
export interface ZhihuAppQuestionFeedAnswer {
  id: string | number;
  author?: AnswerDetail['author'];
  type?: 'answer';
  answer_type?: string;
  question?: AnswerDetail['question'];
  content?: string;
  editable_content?: string;
  excerpt?: string;
  created_time?: number;
  created_time_name?: string;
  updated_time?: number;
  voteup_count?: number;
  comment_count?: number;
  favlists_count?: number;
  thanks_count?: number;
  visited_count?: number;
  reaction?: ZhihuAppReaction;
  relationship?: AnswerDetail['relationship'];
  segment_infos?: AnswerDetail['segment_infos'];
  can_comment?: AnswerDetail['can_comment'];
  content_need_truncated?: boolean;
  ip_info?: string;
  url?: string;
  thumbnail?: string;
  content_img?: string[];
  admin_closed_comment?: boolean;
  annotation_action?: object;
  attached_info?: string;
  big_card_summary?: string;
  business_type?: string;
  content_id?: string | number;
  content_mark?: Record<string, object>;
  content_text_length?: number;
  decorative_labels?: object[];
  exposed_medal?: object;
  has_publishing_draft?: boolean;
  is_mine?: boolean;
  is_navigator?: boolean;
  is_normal?: boolean;
  is_sticky?: boolean;
  is_visible?: boolean;
  matrix_tips?: string;
  media_detail?: ZhihuAppMediaDetail;
  navigator_vote?: boolean;
  reaction_instruction?: Record<string, object>;
  reactions?: Record<string, ZhihuAppReactionValue>;
  relevant_info?: ZhihuAppRelevantInfo;
  sticky_info?: string;
  thumbnail_info?: ZhihuAppThumbnailInfo;
  visible_only_to_author?: boolean;
  vote_next_step?: string;
}

export interface ZhihuAppQuestionFeedsPaging extends ZhihuPaging {
  page?: number;
  need_force_login?: boolean;
}

export interface ZhihuAppQuestionFeedsResponse {
  data: ZhihuAppQuestionFeedCard[];
  paging?: ZhihuAppQuestionFeedsPaging;
  read_count?: number;
}

export interface NormalizedQuestionFeedsResult {
  data: AnswerDetail[];
  paging?: ZhihuAppQuestionFeedsPaging;
  read_count?: number;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function summaryToHtml(summary: string): string {
  return '<p>' + escapeHtml(summary).replace(/\n/g, '<br />') + '</p>';
}

function getVoteCount(target: ZhihuAppQuestionFeedAnswer): number {
  if (target.voteup_count !== undefined) {
    return target.voteup_count;
  }
  const upCount = target.reactions?.['VOTE']?.options?.['UP']?.count;
  return upCount ?? 0;
}

/** Convert App question cards into the answer list shape used by the UI. */
export function normalizeZhihuAppQuestionFeeds(
  response: ZhihuAppQuestionFeedsResponse,
): NormalizedQuestionFeedsResult {
  const out: AnswerDetail[] = [];
  const cards = response.data || [];
  for (const card of cards) {
    if (card.target_type !== undefined && card.target_type !== 'answer') {
      continue;
    }
    const target = card.target;
    if (!target || !target.author) {
      continue;
    }

    const summary: string = target.big_card_summary?.trim() ?? '';
    const excerpt: string = target.excerpt?.trim() ?? summary;
    const hasStringContent: boolean =
      typeof target.content === 'string' && (target.content as string).trim().length > 0;
    const content: string = hasStringContent
      ? (target.content as string)
      : summaryToHtml(summary || excerpt);

    const answer: AnswerDetail = {
      id: target.id,
      type: 'answer',
      author: target.author,
      content: content,
      excerpt: excerpt,
      created_time: target.created_time ?? 0,
      updated_time: target.updated_time,
      voteup_count: getVoteCount(target),
      comment_count: target.comment_count ?? 0,
      favlists_count: target.favlists_count ?? 0,
      question: target.question,
      answer_type: target.answer_type,
      editable_content: target.editable_content,
      thanks_count: target.thanks_count,
      visited_count: target.visited_count,
      reaction: target.reaction,
      relationship: target.relationship,
      segment_infos: target.segment_infos,
      can_comment: target.can_comment,
      ip_info: target.ip_info,
      url: target.url,
      thumbnail: target.thumbnail,
      content_img: target.content_img,
      // A summary is intentionally not treated as reusable full answer HTML.
      content_need_truncated: hasStringContent
        ? target.content_need_truncated
        : true,
    };
    out.push(answer);
  }

  return { data: out, paging: response.paging, read_count: response.read_count };
}
