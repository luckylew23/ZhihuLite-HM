/**
 * 文章 API —— 移植自上游 zhihu--/api/zhihu/article.ts。
 * 改动：
 *   · axios baseURL → zhihuClient 全 URL
 *   · JSON body → JSON.stringify(raw string)
 *   · updateArticleDraft 走 zhihuClient.patch（与上游 PATCH 一致）
 *   · Set 去重 + 展开 → 显式 Set + push 循环
 */

import { zhihuClient } from './httpClient';
import { ZhihuArticle } from '../model/zhihu';
import {
  createPublishingTraceId,
  PublishedContentResult,
  parsePublishedContentResult,
} from './publishing';

const ZHUANLAN_API_URL: string = 'https://zhuanlan.zhihu.com/api';
const API_V4: string = 'https://www.zhihu.com/api/v4';
const JSON_CONTENT_TYPE: string = 'application/json';

export interface ArticleDraft {
  id: string | number;
  title?: string;
  content?: string;
}

export interface ArticlePublishOptions {
  tableOfContentsEnabled?: boolean;
  topics?: string[];
}

interface ArticleDraftPatch {
  can_reward?: boolean;
  content?: string;
  delta_time?: number;
  table_of_contents?: boolean;
  title?: string;
  titleImage?: string;
  isTitleImageFullScreen?: boolean;
}

export const getArticle = async (
  id: string | number,
): Promise<ZhihuArticle> => {
  const res = await zhihuClient.get<ZhihuArticle>(
    API_V4 + '/articles/' + String(id) + '?include=author.is_following',
  );
  return res.data;
};

export async function createArticleDraft(title: string): Promise<ArticleDraft> {
  const payload: Record<string, ESObject> = {
    title: title,
    delta_time: 0,
    can_reward: false,
  };
  const response = await zhihuClient.post<ArticleDraft>(
    ZHUANLAN_API_URL + '/articles/drafts',
    {
      data: JSON.stringify(payload),
      headers: {
        'Content-Type': JSON_CONTENT_TYPE,
        'Origin': 'https://zhuanlan.zhihu.com',
        'Referer': 'https://zhuanlan.zhihu.com/write',
      },
    },
  );
  if (response.data.id === undefined || response.data.id === null) {
    throw new Error('知乎没有返回文章草稿 ID');
  }
  return response.data;
}

/**
 * 更新文章草稿：PATCH。
 */
export async function updateArticleDraft(
  articleId: string | number,
  patch: ArticleDraftPatch,
): Promise<void> {
  await zhihuClient.patch<object>(
    ZHUANLAN_API_URL + '/articles/' + encodeURIComponent(String(articleId)) + '/draft',
    {
      data: JSON.stringify(patch),
      headers: {
        'Content-Type': JSON_CONTENT_TYPE,
        'Origin': 'https://zhuanlan.zhihu.com',
        'Referer': 'https://zhuanlan.zhihu.com/p/' + String(articleId) + '/edit',
      },
    },
  );
}

export async function searchArticleTopics(
  articleId: string | number,
  query: string,
): Promise<object> {
  const url: string = ZHUANLAN_API_URL + '/autocomplete/topics' +
    '?token=' + encodeURIComponent(query) +
    '&max_matches=5&use_similar=0&topic_filter=1';
  const response = await zhihuClient.get<object>(url, {
    headers: {
      'Referer': 'https://zhuanlan.zhihu.com/p/' + String(articleId) + '/edit',
    },
  });
  return response.data;
}

function getFirstTopicSuggestion(response: object): object | undefined {
  if (Array.isArray(response)) {
    const arr = response as object[];
    return arr.length > 0 ? arr[0] : undefined;
  }
  if (response !== null && typeof response === 'object') {
    const record = response as Record<string, object>;
    const data = record['data'];
    if (Array.isArray(data)) {
      const arr = data as object[];
      return arr.length > 0 ? arr[0] : undefined;
    }
  }
  return undefined;
}

export async function addArticleTopic(
  articleId: string | number,
  topic: object,
): Promise<void> {
  await zhihuClient.post<object>(
    ZHUANLAN_API_URL + '/articles/' + encodeURIComponent(String(articleId)) + '/topics',
    {
      data: JSON.stringify(topic),
      headers: {
        'Content-Type': JSON_CONTENT_TYPE,
        'Origin': 'https://zhuanlan.zhihu.com',
        'Referer': 'https://zhuanlan.zhihu.com/p/' + String(articleId) + '/edit',
      },
    },
  );
}

export async function publishArticleDraft(
  articleId: string | number,
  options: ArticlePublishOptions,
  isPublished: boolean,
): Promise<PublishedContentResult> {
  const tableOfContentsEnabled: boolean = options.tableOfContentsEnabled ?? false;
  const traceId: string = createPublishingTraceId();
  const businessParams: string = JSON.stringify({
    column: null,
    commentPermission: 'anyone',
    disclaimer_type: 'none',
    disclaimer_status: 'close',
    table_of_contents_enabled: tableOfContentsEnabled,
    commercial_report_info: { commercial_types: [] },
    commercial_zhitask_bind_info: null,
    canReward: false,
  });
  const data: Record<string, object> = {
    publish: { traceId: traceId },
    extra_info: {
      publisher: 'pc',
      pc_business_params: businessParams,
    },
    draft: { id: String(articleId), isPublished: isPublished, disabled: 1 },
    commentsPermission: { comment_permission: 'anyone' },
    creationStatement: {
      disclaimer_type: 'none',
      disclaimer_status: 'close',
    },
    contentsTables: {
      table_of_contents_enabled: tableOfContentsEnabled,
    },
    commercialReportInfo: { isReport: 0 },
    appreciate: { can_reward: false, tagline: '' },
    hybridInfo: {},
  };
  const payload: Record<string, ESObject> = {
    action: 'article',
    data: data,
  };
  const res = await zhihuClient.post<object>(
    API_V4 + '/content/publish',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return parsePublishedContentResult(res.data);
}

/** 去重 topic 名（替代 [...new Set(options.topics ?? [])]）。 */
function dedupeTopicNames(topics: string[] | undefined): string[] {
  const seen: Set<string> = new Set<string>();
  const out: string[] = [];
  if (topics === undefined) {
    return out;
  }
  for (const name of topics) {
    if (!seen.has(name)) {
      seen.add(name);
      out.push(name);
    }
  }
  return out;
}

export const createArticle = async (
  title: string,
  html: string,
  options: ArticlePublishOptions,
): Promise<PublishedContentResult> => {
  const draft = await createArticleDraft(title);
  await updateArticleDraft(draft.id, {
    title: title,
    content: html,
    table_of_contents: options.tableOfContentsEnabled ?? false,
    delta_time: 0,
    can_reward: false,
  });

  const topicNames: string[] = dedupeTopicNames(options.topics);
  for (const topicName of topicNames) {
    const response = await searchArticleTopics(draft.id, topicName);
    const topic = getFirstTopicSuggestion(response);
    if (topic === undefined) {
      throw new Error('没有找到话题“' + topicName + '”');
    }
    await addArticleTopic(draft.id, topic);
  }

  return publishArticleDraft(draft.id, options, false);
};

export const updateArticle = async (
  articleId: string | number,
  title: string,
  html: string,
  options: ArticlePublishOptions,
): Promise<PublishedContentResult> => {
  await updateArticleDraft(articleId, {
    title: title,
    content: html,
    table_of_contents: options.tableOfContentsEnabled ?? false,
    delta_time: 0,
    can_reward: false,
  });

  const topicNames: string[] = dedupeTopicNames(options.topics);
  for (const topicName of topicNames) {
    const response = await searchArticleTopics(articleId, topicName);
    const topic = getFirstTopicSuggestion(response);
    if (topic === undefined) {
      throw new Error('没有找到话题“' + topicName + '”');
    }
    await addArticleTopic(articleId, topic);
  }

  return publishArticleDraft(articleId, options, true);
};
