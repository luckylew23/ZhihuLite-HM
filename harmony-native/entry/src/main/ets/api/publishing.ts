/**
 * 发布辅助函数 —— 移植自上游 zhihu--/api/zhihu/publishing.ts。
 * ----------------------------------------------------------------------------
 * 本文件在原工程里只提供发布相关的纯函数（traceId、正文字数、发布结果解析），
 * 并不直接发请求（真正的提问/回答/文章/想法 POST 在其它模块）。这里照原样移植。
 * 改动：
 *   · expo-crypto randomUUID → 本地 RFC4122 v4 风格 uuid（Math.random）。
 *   · 模板字面量类型 `${...},${...}` → string。
 *   · unknown → object；去掉索引签名；catch 显式绑定。
 */

export interface PublishedContentResult {
  id?: string;
  publish?: object;
}

function asRecord(value: object | null | undefined): Record<string, object> | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (Array.isArray(value)) {
    return null;
  }
  return value as Record<string, object>;
}

function randomUuidHex(nibbles: number): string {
  const hex = '0123456789abcdef';
  let out = '';
  for (let i = 0; i < nibbles; i++) {
    const r = Math.floor(Math.random() * 16);
    if (i === 12) {
      out += '4'; // version 4
    } else if (i === 16) {
      out += hex[(r & 0x3) | 0x8]; // variant
    } else {
      out += hex[r];
    }
  }
  return out;
}

/** 生成与上游 `Date.now(),<uuid>` 同形的发布链路 traceId */
export function createPublishingTraceId(): string {
  const uuid =
    randomUuidHex(8) + '-' + randomUuidHex(4) + '-' + randomUuidHex(4) +
    '-' + randomUuidHex(4) + '-' + randomUuidHex(12);
  return String(Date.now()) + ',' + uuid;
}

/** Match the browser editor's text length without counting HTML markup. */
export function getPublishingTextLength(html: string): number {
  return html
    .replace(/<[^>]*>/g, '')
    .replace(/&(?:#\d+|#x[\da-f]+|[a-z][\da-z]+);/gi, 'x').length;
}

/** Zhihu wraps publish results in a JSON string inside `data.result`. */
export function parsePublishedContentResult(
  response: object | null | undefined,
): PublishedContentResult {
  const envelope = asRecord(response);
  if (envelope === null) {
    throw new Error('知乎返回了无效的发布结果');
  }

  const data = asRecord(envelope['data']);
  const rawResult = data === null ? undefined : data['result'];
  let result: object | string | undefined = rawResult;
  if (typeof rawResult === 'string') {
    try {
      result = JSON.parse(rawResult as string) as object;
    } catch (e) {
      throw new Error('知乎返回了无法解析的发布结果');
    }
  }

  const parsedResult = asRecord(result as object | undefined);
  if (parsedResult !== null) {
    return parsedResult as PublishedContentResult;
  }

  const error = asRecord(envelope['error']);
  let errorMessage = '';
  if (error !== null && typeof error['message'] === 'string') {
    errorMessage = error['message'] as string;
  }
  if (errorMessage.length > 0) {
    throw new Error(errorMessage);
  }

  const envelopeMsg = envelope['message'];
  const message = typeof envelopeMsg === 'string' ? (envelopeMsg as string) : '';
  if (message.length > 0 && message.toLowerCase() !== 'success') {
    throw new Error(message);
  }
  return envelope as PublishedContentResult;
}
