/**
 * components/interaction/textUtil —— 富文本降级为纯文本的共享工具。
 * 按 PORTING_SPEC 第3节：评论/正文 HTML 剥标签 + 实体解码，不引入 WebView。
 */

/** 把知乎评论/正文的 HTML 降级为纯文本。 */
export function stripHtml(html: string): string {
  if (html === undefined || html === null || html.length === 0) {
    return '';
  }
  let s: string = html;
  // <br> 转为换行
  s = s.replace(/<br\s*\/?>/gi, '\n');
  // <p> 段间换行
  s = s.replace(/<\/p\s*>/gi, '\n');
  // 去掉其余标签
  s = s.replace(/<[^>]+>/g, '');
  // 实体解码
  s = s.replace(/&nbsp;/gi, ' ')
    .replace(/&emsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&ldquo;/gi, '“')
    .replace(/&rdquo;/gi, '”');
  // 折叠多余空行
  s = s.replace(/\n{3,}/g, '\n\n');
  return s.trim();
}

/** 从搜索高亮文本中剥掉 <em> 高亮标签（保留纯文字）。 */
export function plainHighlight(text: string): string {
  if (text === undefined || text === null) {
    return '';
  }
  let s: string = text;
  s = s.replace(/&lt;em&gt;/gi, '').replace(/&lt;\/em&gt;/gi, '');
  s = s.replace(/<\/?em>/gi, '');
  return stripHtml(s);
}
