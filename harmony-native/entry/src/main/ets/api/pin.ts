/**
 * 想法（图文 pin）API —— 移植自上游 zhihu--/api/zhihu/pin.ts。
 * 改动：
 *   · axios baseURL → zhihuClient 全 URL（/pins/{id} → www.zhihu.com/api/v4）
 *   · JSON body → JSON.stringify(raw string)
 *   · 上游 image.ts 的 UploadedImage 未移植，本文件内定义等价 PinUploadedImage
 *   · 上游 publishing → ./publishing
 *   · 对象展开（draft 合并）→ 显式逐字段
 */

import { zhihuClient } from './httpClient';
import { ZhihuAuthor, ZhihuTopic } from '../model/zhihu';
import {
  createPublishingTraceId,
  getPublishingTextLength,
  PublishedContentResult,
  parsePublishedContentResult,
} from './publishing';

const API_V4: string = 'https://www.zhihu.com/api/v4';
const JSON_CONTENT_TYPE: string = 'application/json';

interface PinDraftResponse {
  data?: {
    content_id?: string | number;
  };
}

export interface PinMediaImage {
  height: number;
  originalUrl: string;
  url: string;
  watermark: string;
  watermarkUrl: string;
  width: number;
}

/** 等价上游 image.ts 的 UploadedImage（image.ts 未移植，本地定义最小子集）。 */
export interface PinUploadedImage {
  height: number;
  width: number;
  src: string;
  originalSrc?: string;
  watermark?: string;
  watermarkSrc?: string;
}

export interface PinPublishOptions {
  images?: PinUploadedImage[];
  pinId?: string | number;
  title?: string;
}

/** 想法详情（getPin）。 */
export interface ZhihuPinDetail {
  id: string | number;
  type?: string;
  content?: string;
  content_html?: string;
  excerpt?: string;
  created?: number;
  like_count?: number;
  comment_count?: number;
  author?: ZhihuAuthor;
  topics?: ZhihuTopic[];
  relationship?: {
    voting?: number;
  };
}

const PIN_INCLUDE: string =
  'author,author.is_following,content,content_html,created,like_count,comment_count,relationship.voting,topics';

export const getPin = async (id: string | number): Promise<ZhihuPinDetail> => {
  const res = await zhihuClient.get<ZhihuPinDetail>(
    API_V4 + '/pins/' + String(id) + '?include=' + PIN_INCLUDE,
  );
  return res.data;
};

export const votePinPoll = async (
  pollId: string | number,
  optionIds: Array<string | number>,
): Promise<object> => {
  const options: string[] = [];
  for (const oid of optionIds) {
    options.push(String(oid));
  }
  const payload: Record<string, ESObject> = { options: options };
  const res = await zhihuClient.post<object>(
    API_V4 + '/polls/' + String(pollId),
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return res.data;
};

function toPinMediaImage(image: PinUploadedImage): PinMediaImage {
  return {
    height: image.height,
    width: image.width,
    url: image.src,
    originalUrl: image.originalSrc ?? image.src,
    watermark: image.watermark ?? 'watermark',
    watermarkUrl: image.watermarkSrc ?? image.src,
  };
}

function createPinContentData(
  html: string,
  traceId: string,
  options: PinPublishOptions,
): Record<string, object> {
  const medias: object[] = [];
  const images = options.images ?? [];
  for (const image of images) {
    medias.push({ image: toPinMediaImage(image) });
  }
  return {
    publish: { traceId: traceId },
    commentsPermission: { comment_permission: 'all' },
    extra_info: { view_permission: 'all', publisher: 'pc' },
    title: { title: options.title?.trim() ?? '' },
    hybrid: {
      html: html,
      textLength: getPublishingTextLength(html),
    },
    media: { medias: medias },
  };
}

async function createPinDraft(
  html: string,
  traceId: string,
  options: PinPublishOptions,
): Promise<string> {
  const contentData = createPinContentData(html, traceId, options);
  const data: Record<string, object> = {
    draft: { disabled: 1 },
  };
  const keys = Object.keys(contentData);
  for (const k of keys) {
    data[k] = contentData[k];
  }
  const payload: Record<string, ESObject> = {
    action: 'pin',
    data: data,
  };
  const response = await zhihuClient.post<PinDraftResponse>(
    'https://api.zhihu.com/content/drafts',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  const draftId = response.data.data?.content_id;
  if (draftId === undefined || draftId === null || draftId === '') {
    throw new Error('知乎没有返回想法草稿 ID');
  }
  return String(draftId);
}

/**
 * Publish a new pin, or update an existing pin when `pinId` is provided.
 * Unlike articles and answers, pin images must live in `data.media.medias`.
 */
export const createPin = async (
  html: string,
  options: PinPublishOptions,
): Promise<PublishedContentResult> => {
  const traceId = createPublishingTraceId();
  const isPublished: boolean = options.pinId !== undefined;
  const draftId: string = isPublished
    ? String(options.pinId)
    : await createPinDraft(html, traceId, options);

  const contentData = createPinContentData(html, traceId, options);
  const data: Record<string, object> = {
    draft: { disabled: 1, id: draftId, isPublished: isPublished },
  };
  const keys = Object.keys(contentData);
  for (const k of keys) {
    data[k] = contentData[k];
  }
  const payload: Record<string, ESObject> = {
    action: 'pin',
    data: data,
  };
  const response = await zhihuClient.post<object>(
    API_V4 + '/content/publish',
    { data: JSON.stringify(payload), headers: { 'Content-Type': JSON_CONTENT_TYPE } },
  );
  return parsePublishedContentResult(response.data);
};

export const updatePin = async (
  pinId: string | number,
  html: string,
  options: PinPublishOptions,
): Promise<PublishedContentResult> =>
  createPin(html, {
    images: options.images,
    title: options.title,
    pinId: pinId,
  });
