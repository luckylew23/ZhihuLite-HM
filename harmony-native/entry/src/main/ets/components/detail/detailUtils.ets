/**
 * components/detail/detailUtils —— 详情族页面共享的纯函数工具。
 *  - stripHtml：富文本降级为纯文本（剥标签 + 解码实体），不引入 WebView。
 *  - extractImageUrls：从 HTML 正文里抽 <img src>（想法图文用）。
 *  - formatCount：点赞/评论数缩写。
 *  - guardLogin：写操作前的登录守卫，未登录则 toast 并跳登录页。
 * 注意：本文件只放纯函数，不放 @Component。
 */

import { router, promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { authStore } from '../../store/authStore';
const DOMAIN: number = 0x0001;
const TAG: string = 'ZhihuLite';

/** 富文本 → 纯文本。块级标签先转成换行，再剥标签、解码实体。 */
export function stripHtml(html: string): string {
  if (html === null || html === undefined) {
    return '';
  }
  if (typeof html !== 'string') {
    return '';
  }
  let text: string = html;
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<\/(p|div|section|article|h[1-6]|li|ul|ol|blockquote|figure)>/gi, '\n');
  text = text.replace(/<li[^>]*>/gi, '\n· ');
  text = text.replace(/<[^>]+>/g, '');
  text = text.replace(/&nbsp;/g, ' ');
  text = text.replace(/&amp;/g, '&');
  text = text.replace(/&lt;/g, '<');
  text = text.replace(/&gt;/g, '>');
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#34;/gi, '"');
  text = text.replace(/&#39;/g, '\'');
  text = text.replace(/&#x27;/g, '\'');
  text = text.replace(/&hellip;/g, '…');
  text = text.replace(/\u00a0/g, ' ');
  text = text.replace(/[ \t]+\n/g, '\n');
  text = text.replace(/\n{3,}/g, '\n\n');
  // 日报/文章末尾链接残留过滤：windows.daily=true 参数、无链接的"查看知乎讨论"纯文本
  text = text.replace(/https?:\/\/\S*(?:windows|window)\.daily\S*/gi, '');
  text = text.replace(/(?:windows|window)\.daily[=?\S]*/gi, '');
  text = text.replace(/查看知乎(原文|讨论)[^\n]*/gi, '');
  text = text.replace(/window\.daily\s*=?\s*true?/gi, '');
  return text.trim();
}

/** 正文富文本块：text=文本段；image=图片段（可长按下载）。 */
export interface HtmlBlock {
  type: 'text' | 'image';
  text: string;
  url: string;
}

/** 从 <img ...> 标签里按优先级取真实 URL（知乎懒加载：data-actualsrc > data-original > data-src > src） */
function extractImgSrc(tag: string): string {
  const attrNames: string[] = ['data-actualsrc', 'data-original', 'data-src', 'src'];
  for (let i = 0; i < attrNames.length; i++) {
    const re: RegExp = new RegExp(attrNames[i] + '="([^"]+)"', 'i');
    const m: RegExpExecArray | null = re.exec(tag);
    if (m !== null && m[1].length > 0) {
      return m[1];
    }
  }
  return '';
}

/**
 * 解析 HTML 正文 → 文本/图片交替块（正文内嵌图片显示 + 可长按下载）。
 * 按 <img> 切分：片段走 stripHtml（剥标签+实体解码），图片标签提取 src。
 */
export function parseHtmlBlocks(html: string): HtmlBlock[] {
  const blocks: HtmlBlock[] = [];
  if (html === null || html === undefined || typeof html !== 'string') {
    return blocks;
  }
  const regex: RegExp = /<img[^>]*>/gi;
  const seen: Set<string> = new Set<string>();
  let last: number = 0;
  let m: RegExpExecArray | null = regex.exec(html);
  while (m !== null) {
    const seg: string = html.substring(last, m.index);
    const t: string = stripHtml(seg);
    if (t.length > 0) {
      blocks.push({ type: 'text', text: t, url: '' });
    }
    const url: string = extractImgSrc(m[0]);
    // 知乎正文每张图有两个 img：原图(src=_r.jpg) + 懒加载占位(src=_720w.jpg 或 svg)，
    // URL 不同但同一张图；用 v2-token 做去重 key。
    const tk: RegExpExecArray | null = /v2-[a-f0-9]{20,}/i.exec(url);
    const key: string = tk !== null ? tk[0] : url;
    if (url.length > 0 && url.indexOf('data:') !== 0 && !seen.has(key)) {
      seen.add(key);
      blocks.push({ type: 'image', text: '', url: url });
    }
    last = m.index + m[0].length;
    m = regex.exec(html);
  }
  const tail: string = stripHtml(html.substring(last));
  if (tail.length > 0) {
    blocks.push({ type: 'text', text: tail, url: '' });
  }
  return blocks;
}

/** 从 HTML 中抽出所有图片地址（去重，按出现顺序）。 */
export function extractImageUrls(html: string): string[] {
  const out: string[] = [];
  if (html === null || html === undefined) {
    return out;
  }
  const seen: Set<string> = new Set<string>();
  const regex: RegExp = /<img[^>]+src="([^">]+)"/gi;
  let m: RegExpExecArray | null = regex.exec(html);
  while (m !== null) {
    const url: string = m[1];
    if (url.length > 0 && !seen.has(url)) {
      seen.add(url);
      out.push(url);
    }
    m = regex.exec(html);
  }
  return out;
}

/** 数字缩写：1.2万 / 3.4亿。 */
export function formatCount(count: number): string {
  if (count === null || count === undefined || isNaN(count)) {
    return '0';
  }
  if (count >= 100000000) {
    return (count / 100000000).toFixed(1) + '亿';
  }
  if (count >= 10000) {
    return (count / 10000).toFixed(1) + '万';
  }
  return String(count);
}

/**
 * 写操作登录守卫。已登录返回 true；未登录 toast 提示并跳登录页，返回 false。
 */
export function guardLogin(): boolean {
  if (authStore.isLoggedIn) {
    return true;
  }
  promptAction.showToast({ message: '请先登录' });
  router.pushUrl({ url: 'pages/LoginPage' });
  return false;
}

/** 把 router 参数 Record 安全取出字符串字段。 */
export function readStringParam(params: Record<string, object> | null, key: string): string {
  if (params === null || params === undefined) {
    return '';
  }
  const v: object | undefined = params[key];
  if (v === undefined || v === null) {
    return '';
  }
  return String(v);
}
