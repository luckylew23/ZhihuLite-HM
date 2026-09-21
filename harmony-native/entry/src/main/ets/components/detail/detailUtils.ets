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

/** 富文本 → 纯文本。块级标签先转成换行，再剥标签、解码实体。keepMarkdown=true 时行内 strong/b/em/i/code 转成 ** * ` markdown 标记。 */
export function stripHtml(html: string, keepMarkdown: boolean = false): string {
  if (html === null || html === undefined) {
    return '';
  }
  if (typeof html !== 'string') {
    return '';
  }
  let text: string = html;
  if (keepMarkdown) {
    text = text.replace(/<strong[^>]*>([\s\S]*?)<\/strong>/gi, '**$1**');
    text = text.replace(/<b[^>]*>([\s\S]*?)<\/b>/gi, '**$1**');
    text = text.replace(/<em[^>]*>([\s\S]*?)<\/em>/gi, '*$1*');
    text = text.replace(/<i[^>]*>([\s\S]*?)<\/i>/gi, '*$1*');
    text = text.replace(/<code[^>]*>([\s\S]*?)<\/code>/gi, '`$1`');
    text = text.replace(/<a[^>]*>([\s\S]*?)<\/a>/gi, '$1');
  }
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

/** 正文富文本块：text=段落；heading=标题；quote=引用；code=代码块；list=列表项；image=图片。 */
export interface HtmlBlock {
  type: 'text' | 'heading' | 'quote' | 'code' | 'list' | 'image';
  text: string;
  url: string;
  level?: number;  // heading level 1-6
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
 * 解析 HTML 正文 → 结构化块（标题/引用/代码/列表/段落/图片）。
 */
export function parseHtmlBlocks(html: string): HtmlBlock[] {
  const blocks: HtmlBlock[] = [];
  if (html === null || html === undefined || typeof html !== 'string') {
    return blocks;
  }
  // 先按 <img> 切分，图片单独成块
  const imgRe: RegExp = /<img[^>]*>/gi;
  const seen: Set<string> = new Set<string>();
  let last: number = 0;
  let m: RegExpExecArray | null = imgRe.exec(html);
  while (m !== null) {
    const seg: string = html.substring(last, m.index);
    htmlToBlocks(seg, blocks);
    const url: string = extractImgSrc(m[0]);
    const tk: RegExpExecArray | null = /v2-[a-f0-9]{20,}/i.exec(url);
    const key: string = tk !== null ? tk[0] : url;
    if (url.length > 0 && url.indexOf('data:') !== 0 && !seen.has(key)) {
      seen.add(key);
      blocks.push({ type: 'image', text: '', url: url });
    }
    last = m.index + m[0].length;
    m = imgRe.exec(html);
  }
  htmlToBlocks(html.substring(last), blocks);
  return blocks;
}

/** 把一段 HTML 转成结构化 blocks（不处理图片）。 */
function htmlToBlocks(html: string, out: HtmlBlock[]): void {
  let text: string = html;
  // 去掉 script/style
  text = text.replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '');
  text = text.replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '');
  // 块级标签按行切分
  // 先按行处理，识别 heading/quote/code/list
  // 用正则提取块级元素
  const blockRe: RegExp = /<(h[1-6]|blockquote|pre|ul|ol|li|p|div|section)[^>]*>([\s\S]*?)<\/\1>/gi;
  let lm: RegExpExecArray | null = blockRe.exec(text);
  let lastPos: number = 0;
  while (lm !== null) {
    // 块之前的文本
    const before: string = text.substring(lastPos, lm.index);
    const plainBefore: string = stripHtml(before, true);
    if (plainBefore.length > 0) {
      pushTextBlocks(plainBefore, out);
    }
    const tag: string = lm[1].toLowerCase();
    const inner: string = lm[2];
    if (tag.startsWith('h')) {
      const lv: number = parseInt(tag.substring(1), 10);
      const t: string = stripHtml(inner, true);
      if (t.length > 0) out.push({ type: 'heading', text: t, url: '', level: lv });
    } else if (tag === 'blockquote') {
      const t: string = stripHtml(inner, true);
      if (t.length > 0) out.push({ type: 'quote', text: t, url: '' });
    } else if (tag === 'pre') {
      const t: string = stripHtml(inner);
      if (t.length > 0) out.push({ type: 'code', text: t, url: '' });
    } else if (tag === 'li') {
      const t: string = stripHtml(inner, true);
      if (t.length > 0) out.push({ type: 'list', text: t, url: '' });
    } else {
      // p/div/section 普通段落
      const t: string = stripHtml(inner, true);
      if (t.length > 0) out.push({ type: 'text', text: t, url: '' });
    }
    lastPos = lm.index + lm[0].length;
    lm = blockRe.exec(text);
  }
  // 剩余文本
  const rest: string = text.substring(lastPos);
  const plainRest: string = stripHtml(rest, true);
  if (plainRest.length > 0) {
    pushTextBlocks(plainRest, out);
  }
}

/** 把纯文本按换行拆成 text blocks。 */
function pushTextBlocks(plain: string, out: HtmlBlock[]): void {
  const lines: string[] = plain.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const ln: string = lines[i].trim();
    if (ln.length > 0) {
      out.push({ type: 'text', text: ln, url: '' });
    }
  }
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

/** 行内富文本片段：bold=粗体；italic=斜体；code=等宽。 */
export interface InlinePart {
  bold: boolean;
  italic: boolean;
  code: boolean;
  text: string;
}

/** 解析 markdown 行内标记（**粗体** / *斜体* / `代码`）成富文本片段。 */
export function parseInline(text: string): InlinePart[] {
  const out: InlinePart[] = [];
  if (text === null || text === undefined || text.length === 0) {
    return out;
  }
  const codeSegs: string[] = text.split(/(`[^`]+`)/g);
  for (let ci = 0; ci < codeSegs.length; ci++) {
    const cs: string = codeSegs[ci];
    if (cs.length === 0) continue;
    if (cs.startsWith('`') && cs.endsWith('`') && cs.length > 2) {
      out.push({ bold: false, italic: false, code: true, text: cs.substring(1, cs.length - 1) });
      continue;
    }
    const bSegs: string[] = cs.split(/(\*\*[^*]+\*\*)/g);
    for (let bi = 0; bi < bSegs.length; bi++) {
      const bs: string = bSegs[bi];
      if (bs.length === 0) continue;
      if (bs.startsWith('**') && bs.endsWith('**') && bs.length > 4) {
        out.push({ bold: true, italic: false, code: false, text: bs.substring(2, bs.length - 2) });
        continue;
      }
      const iSegs: string[] = bs.split(/(\*[^*]+\*)/g);
      for (let ii = 0; ii < iSegs.length; ii++) {
        const is: string = iSegs[ii];
        if (is.length === 0) continue;
        if (is.startsWith('*') && is.endsWith('*') && is.length > 2) {
          out.push({ bold: false, italic: true, code: false, text: is.substring(1, is.length - 1) });
        } else {
          out.push({ bold: false, italic: false, code: false, text: is });
        }
      }
    }
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
