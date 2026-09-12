/**
 * @preeternal/react-native-cookie-manager 的 Web 垫片
 * ---------------------------------------------------------------------------
 * 背景：该库是纯原生 TurboModule，Web 下 `TurboModuleRegistry.getEnforcing`
 * 返回 undefined，模块工厂一执行就抛
 *   "Cannot read properties of undefined (reading 'getEnforcing')"
 * 因为 api/client.ts 在模块顶层 import 它，整个 bundle 直接构建失败。
 *
 * 策略：以 localStorage 维护一个 JS Cookie Jar，契约与 OHOS 垫片
 * （platform/ohos/shims/reactNativeCookies.ts）保持一致：
 *   get(url, true)  -> Record<name, { name, value, ... }>
 *   get(url, false) -> "a=1; b=2"
 *   set(url, { name, value, ... })      单条
 *   set(url, { z_c0: {...}, d_c0: {...} })  批量
 * 无 localStorage（Node/SSG）时退化为进程内对象。
 * ---------------------------------------------------------------------------
 */

const JAR_KEY = 'hmos-cookies:jar';

let memoryJar: Record<string, any> | null = null;

function readJarSync(): Record<string, any> {
  if (memoryJar) return memoryJar;
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.getItem === 'function') {
      const raw = ls.getItem(JAR_KEY);
      if (raw) {
        const parsed = JSON.parse(raw);
        if (parsed && typeof parsed === 'object') return parsed;
      }
    }
  } catch {
    /* 忽略 */
  }
  return {};
}

function writeJarSync(jar: Record<string, any>): void {
  memoryJar = jar;
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.setItem === 'function') {
      ls.setItem(JAR_KEY, JSON.stringify(jar));
    }
  } catch {
    /* 忽略：配额超限 */
  }
}

function readJar(): Promise<Record<string, any>> {
  return Promise.resolve(readJarSync());
}

function writeJar(jar: Record<string, any>): Promise<void> {
  writeJarSync(jar);
  return Promise.resolve();
}

function parseCookieString(cookie: string): Record<string, any> {
  const jar: Record<string, any> = {};
  cookie.split(';').forEach((pair) => {
    const idx = pair.indexOf('=');
    if (idx <= 0) return;
    const name = pair.slice(0, idx).trim();
    const value = pair.slice(idx + 1).trim();
    if (name) jar[name] = { name, value };
  });
  return jar;
}

export type Cookie = {
  name: string;
  value: string;
  domain?: string;
  path?: string;
  expires?: string;
  secure?: boolean;
  httpOnly?: boolean;
  sameSite?: 'None' | 'Lax' | 'Strict';
  [k: string]: any;
};

export type Cookies = Record<string, Cookie>;

const CookieManager = {
  /** useJSON=true 返回对象映射（含 name 字段）；false 返回 "a=1; b=2" */
  async get(_url?: string, useJSON = true): Promise<any> {
    const jar = await readJar();
    if (useJSON) return jar;
    return Object.entries(jar)
      .map(([n, c]) => `${n}=${(c as any)?.value ?? ''}`)
      .join('; ');
  },

  async getAll(_useWebKit?: boolean): Promise<Cookies> {
    return readJar();
  },

  async getAllAsArray(_useWebKit?: boolean): Promise<Cookie[]> {
    return Object.values(await readJar());
  },

  async getAsArray(_url?: string, _useWebKit?: boolean): Promise<Cookie[]> {
    return Object.values(await readJar());
  },

  async getCookieHeader(_url?: string, _useWebKit?: boolean): Promise<string> {
    const jar = await readJar();
    return Object.entries(jar)
      .map(([n, c]) => `${n}=${(c as any)?.value ?? ''}`)
      .join('; ');
  },

  async set(_url: string, cookie: any, _useJSON = true): Promise<boolean> {
    const jar = await readJar();

    if (typeof cookie === 'string') {
      Object.assign(jar, parseCookieString(cookie));
    } else if (cookie && typeof cookie === 'object') {
      if (typeof cookie.name === 'string') {
        // 单条形态：{ name, value, domain, path }
        jar[cookie.name] = { ...cookie };
      } else {
        // 批量形态：{ z_c0: {...}, d_c0: {...} }
        for (const [name, c] of Object.entries(cookie as Record<string, any>)) {
          if (c && typeof c === 'object') {
            jar[name] = { ...(c as object), name };
          } else if (typeof c === 'string') {
            jar[name] = { name, value: c };
          }
        }
      }
    }

    await writeJar(jar);
    return true;
  },

  async setFromResponse(_url: string, cookie: string): Promise<boolean> {
    const jar = await readJar();
    Object.assign(jar, parseCookieString(cookie));
    await writeJar(jar);
    return true;
  },

  async clearByName(_url: string, name: string): Promise<boolean> {
    const jar = await readJar();
    delete jar[name];
    await writeJar(jar);
    return true;
  },

  async clearAll(_useWebKit?: boolean): Promise<boolean> {
    await writeJar({});
    return true;
  },

  async clearAllStores(): Promise<boolean> {
    await writeJar({});
    return true;
  },

  async removeSessionCookies(_options?: any): Promise<boolean> {
    await writeJar({});
    return true;
  },

  async flush(): Promise<void> {},

  /** @deprecated 上游同名方法，Web 下不支持自行发请求，返回空集合 */
  async getFromResponse(_url: string): Promise<Cookies> {
    return readJar();
  },
};

export default CookieManager;
