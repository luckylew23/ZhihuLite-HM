// @react-native-cookies/cookies → OHOS 兼容垫片
// 在 OHOS 上以 KV 维护一个 JS Cookie Jar，供 api/client.ts 注入请求头、
// 以及 app/login/index.tsx 从 WebView 登录流程里回读 z_c0 / d_c0。
//
// 契约（必须与 @react-native-cookies/cookies 对齐，否则登录会静默失败）：
//   set(url, { name, value, domain, path }, true)  → 写入单条
//   set(url, { z_c0: {...}, d_c0: {...} }, true)   → 批量写入
//   get(url, true) → Record<name, { name, value, ... }>   ← 调用方会读 c.name 与 c.value
//   get(url, false) → "a=1; b=2"
import { kvGet, kvSet, kvDel } from './_kv';

const COOKIE_KEY = 'cookies:jar';

export interface CookieObject {
  name: string;
  value: string;
  domain?: string;
  path?: string;
  [k: string]: any;
}

type CookieMap = Record<string, CookieObject>;

async function readJar(): Promise<CookieMap> {
  const raw = await kvGet(COOKIE_KEY);
  if (!raw) return {};
  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === 'object' ? parsed : {};
  } catch {
    return {};
  }
}

async function writeJar(jar: CookieMap) {
  await kvSet(COOKIE_KEY, JSON.stringify(jar));
}

function parseCookieString(cookie: string): CookieMap {
  const jar: CookieMap = {};
  cookie.split(';').forEach((pair) => {
    const idx = pair.indexOf('=');
    if (idx <= 0) return;
    const name = pair.slice(0, idx).trim();
    const value = pair.slice(idx + 1).trim();
    if (name) jar[name] = { name, value };
  });
  return jar;
}

export const CookieManager = {
  /** useJSON=true 返回对象映射（含 name 字段）；false 返回 "a=1; b=2" 字符串 */
  async get(url?: string, useJSON = true): Promise<any> {
    const jar = await readJar();
    if (useJSON) return jar;
    return Object.entries(jar)
      .map(([n, c]) => `${n}=${c?.value ?? ''}`)
      .join('; ');
  },

  async set(url: string, cookie: any, useJSON = true): Promise<void> {
    const jar = await readJar();

    if (typeof cookie === 'string') {
      Object.assign(jar, parseCookieString(cookie));
    } else if (useJSON && cookie && typeof cookie === 'object') {
      if (typeof cookie.name === 'string') {
        // 单条形态：{ name, value, domain, path }
        jar[cookie.name] = { ...cookie };
      } else {
        // 批量形态：{ z_c0: {...}, d_c0: {...} }
        for (const [name, c] of Object.entries(cookie as Record<string, any>)) {
          if (c && typeof c === 'object') {
            jar[name] = { ...c, name };
          } else if (typeof c === 'string') {
            jar[name] = { name, value: c };
          }
        }
      }
    }
    await writeJar(jar);
  },

  async delete(url: string, name: string): Promise<void> {
    const jar = await readJar();
    delete jar[name];
    await writeJar(jar);
  },

  async clearAll(_useWebKit?: boolean): Promise<void> {
    await kvDel(COOKIE_KEY);
  },

  async flush(): Promise<void> {},
};

export default CookieManager;
