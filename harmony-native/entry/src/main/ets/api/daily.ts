/**
 * 日报 API —— 移植自上游 zhihu--/api/zhihu/daily.ts。
 * ----------------------------------------------------------------------------
 * 注意：日报是独立服务（daily.zhihu.com），不走主站签名通道（x-zse-96），
 * 使用专用 UA（ZhihuDaily/2.9.0）+ Referer，不携带主站 Cookie。
 * 原生 @ohos.net.http 直连（无 CORS 约束）。
 */

import { http } from '@kit.NetworkKit';

const DAILY_BASE: string = 'https://daily.zhihu.com';
const DAILY_UA: string = 'ZhihuDaily/2.9.0 (Android; 10; Scale/2.0)';

export interface DailyStory {
  id: number;
  title: string;
  hint: string;
  images?: string[];
  image?: string;
  type?: number;
  url?: string;
}

export interface DailyListResponse {
  date: string; // 'YYYYMMDD'
  stories: DailyStory[];
  top_stories?: DailyStory[];
}

export interface DailyDetailResponse {
  id: number;
  date: string;
  title: string;
  image?: string;
  images?: string[];
  hint?: string;
  /** 文章正文 HTML */
  body: string;
  share_url?: string;
}

class DailyClient {
  async get(path: string): Promise<string> {
    const req = http.createHttp();
    try {
      const resp = await req.request(DAILY_BASE + path, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': DAILY_UA,
          'Referer': DAILY_BASE + '/',
          'Accept': 'application/json, text/plain, */*',
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 25000,
        usingCache: false,
      });
      if (typeof resp.result !== 'string' || resp.result.length === 0) {
        throw new Error('日报响应为空');
      }
      return resp.result;
    } finally {
      try {
        req.destroy();
      } catch (e) {
        // ignore
      }
    }
  }
}

const dailyClient = new DailyClient();

function parse<T>(text: string): T {
  return JSON.parse(text) as T;
}

/** 最新一期日报 */
export const getDailyLatest = async (): Promise<DailyListResponse> => {
  const text = await dailyClient.get('/api/4/news/latest');
  return parse<DailyListResponse>(text);
};

/** 指定日期之前的一期日报（date 为 YYYYMMDD） */
export const getDailyBefore = async (date: string): Promise<DailyListResponse> => {
  const text = await dailyClient.get('/api/4/news/before/' + date);
  return parse<DailyListResponse>(text);
};

/** 日报文章详情（body 为 HTML） */
export const getDailyDetail = async (id: string | number): Promise<DailyDetailResponse> => {
  const text = await dailyClient.get('/api/4/news/' + String(id));
  return parse<DailyDetailResponse>(text);
};

/**
 * 将日报 HTML 正文转为可读纯文本（分段保留）。
 * 上游 zhihu-- 用富文本渲染，HarmonyOS 端暂以纯文本降级展示（见交付说明）。
 */
export function htmlToPlainText(html: string): string {
  if (!html) {
    return '';
  }
  let text: string = html;
  // 换行标签 → \n
  text = text.replace(/<(br|p|div|h1|h2|h3|li|blockquote)[^>]*>/gi, '\n');
  // 图片标签 → [图片] 占位（正文内图片保留提示）
  text = text.replace(/<img[^>]*>/gi, ' [图片] ');
  // 其余标签剔除
  text = text.replace(/<[^>]+>/g, '');
  // HTML 实体解码（常用集合）
  text = text.replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/g, "'")
    .replace(/&hellip;/gi, '…')
    .replace(/&mdash;/gi, '—')
    .replace(/&ldquo;/gi, '“')
    .replace(/&rdquo;/gi, '”')
    .replace(/&middot;/gi, '·');
  // 压缩多余空行
  text = text.replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
  return text;
}

/** 日报日期 'YYYYMMDD' → 'M月D日' */
export function formatDailyDate(dateStr: string): string {
  if (!dateStr || dateStr.length < 8) {
    return dateStr;
  }
  const month: number = Number(dateStr.substring(4, 6));
  const day: number = Number(dateStr.substring(6, 8));
  return String(month) + '月' + String(day) + '日';
}
