/**
 * utils/deepLink —— 深链（系统打开知乎链接）入口。
 * EntryAbility 收到浏览意图后把 URL 暂存，首页 onPageShow 时取出并按 zhihuRouter 路由。
 */

import { openZhihuUrl } from './zhihuRouter';

let pending: string = '';

export function setPendingDeepLink(url: string): void {
  pending = url;
}

/** 取出并处理挂起的深链；有且成功路由返回 true。 */
export function handleDeepLinkIfAny(): boolean {
  const u: string = pending;
  if (u.length === 0) {
    return false;
  }
  pending = '';
  return openZhihuUrl(u);
}
