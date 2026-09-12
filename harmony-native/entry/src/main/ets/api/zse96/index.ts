/**
 * ZSE-96 签名入口 —— 移植自上游 zhihu--/api/zse96/index.ts。
 * 改动：去掉 `new URL(...)`（ArkTS 下需显式 import，且签名只需 path+query，
 * 用纯字符串解析等价实现，保持 Node / ArkTS 双端可跑）。
 */

import { getSignaturePurity } from './zse_purity';

export { hmacSha1Hex } from './hmac';
export { encryptZseV4 } from './zse_purity';

export const ZSE_VERSION = '101_3_3.0';

/** 取 URL 的 pathname + search（等价于 new URL(url, base).pathname + .search）。 */
function getPathWithQuery(url: string): string {
  const clean = url.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, '');
  const hashIdx = clean.indexOf('#');
  const noHash = hashIdx >= 0 ? clean.substring(0, hashIdx) : clean;
  const slash = noHash.indexOf('/');
  if (slash < 0) {
    return '/';
  }
  return noHash.substring(slash);
}

/**
 * 获取 cookie 中的 d_c0 值
 */
function getDc0(cookieString: string): string {
  const match = cookieString.match(/d_c0=([^;]+)/);
  return match ? match[1] : '';
}

/**
 * 转换后的签名函数
 */
export async function signRequest96(
  url: string,
  _body: string | null, // 新逻辑不再需要 body
  cookie: string,
): Promise<string> {
  const dc0 = getDc0(cookie);

  // 核心：Zhihu 签名需要包含 query string (search params)
  const pathname = getPathWithQuery(url);

  try {
    // 调用移植自 zhi-purity 的新签名算法
    return await getSignaturePurity(pathname, dc0);
  } catch (e) {
    console.error('zse96签名失败', e);
    throw new Error('zse96签名失败！请向开发者反馈');
  }
}
