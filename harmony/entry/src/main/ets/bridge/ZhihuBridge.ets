// bridge/ZhihuBridge.ets —— 原生网络桥
// ----------------------------------------------------------------------------
// 为什么需要它：
//   ArkWeb 经 $rawfile('index.html') 加载时，页面源是 resource://rawfile，
//   属于 **opaque origin**。知乎接口不返回 Access-Control-Allow-Origin，
//   因此页面里所有 XHR/fetch 都会被浏览器 CORS 策略直接拦死
//   → 表现为「界面出来了但永远空态 + NetworkError」。
//
//   本桥把知乎域名的请求转交 @ohos.net.http 在原生侧发出：
//     · 原生请求不受 CORS 约束
//     · 可携带任意自定义签名头（x-zse-96 等）
//     · 由原生侧统一维护 Cookie Jar（并持久化），游客/登录态都能保持
//
// 暴露给 JS 的方法（见 pages/index.ets 的 javaScriptProxy 注册）：
//   request(url, method, headersJson, body) -> Promise<string>  JSON 回包
//   bootstrap()                             -> Promise<string>  预热游客 cookie
//   getCookies()                            -> string           当前 Cookie Jar(JSON)
//   setCookie(url, cookieString)            -> string           写入单条/多条
//   clearCookies()                          -> string           清空
// ----------------------------------------------------------------------------
import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const DOMAIN: number = 0x0001;
const TAG: string = 'ZhihuBridge';

const COOKIE_STORE_KEY: string = 'zhihu_cookie_jar';
const PREF_NAME: string = 'zhihu_bridge';

/** 预热游客 cookie 的入口页（知乎在此下发 d_c0 等） */
const BOOTSTRAP_URL: string = 'https://www.zhihu.com/';

const DESKTOP_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

export interface BridgeResult {
  status: number;
  statusText: string;
  headers: Record<string, string>;
  body: string;
  error: string;
}

interface CookieEntry {
  name: string;
  value: string;
  domain: string;
  path: string;
}

/** 由 EntryAbility.onCreate 注入，用于持久化 Cookie Jar */
let appContext: common.Context | null = null;

export function setAppContext(ctx: common.Context): void {
  appContext = ctx;
}

function lowerKeys(src: Record<string, string>): Record<string, string> {
  const out: Record<string, string> = {};
  const keys = Object.keys(src);
  for (const k of keys) {
    out[k.toLowerCase()] = src[k];
  }
  return out;
}

function hasKey(src: Record<string, string>, target: string): boolean {
  const keys = Object.keys(src);
  for (const k of keys) {
    if (k.toLowerCase() === target) {
      return true;
    }
  }
  return false;
}

/** 从 URL 取 host（失败返回空串） */
function hostOf(url: string): string {
  try {
    const noProto: string = url.replace(/^[a-zA-Z]+:\/\//, '');
    const slash: number = noProto.indexOf('/');
    const hostPort: string = slash >= 0 ? noProto.substring(0, slash) : noProto;
    const at: number = hostPort.indexOf('@');
    const host: string = at >= 0 ? hostPort.substring(at + 1) : hostPort;
    const colon: number = host.indexOf(':');
    return colon >= 0 ? host.substring(0, colon) : host;
  } catch (e) {
    return '';
  }
}

function parseSetCookie(setCookie: string, fallbackHost: string): CookieEntry[] {
  const out: CookieEntry[] = [];
  const parts: string[] = setCookie.split(/,(?=[^;]+=)/);
  for (const part of parts) {
    const segments: string[] = part.split(';');
    const pair: string = (segments.length > 0 ? segments[0] : '').trim();
    const eq: number = pair.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    const name: string = pair.substring(0, eq).trim();
    let value: string = pair.substring(eq + 1).trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    if (name.length === 0 || value.length === 0) {
      continue;
    }
    let domain: string = fallbackHost;
    let path: string = '/';
    for (let i = 1; i < segments.length; i++) {
      const seg: string = segments[i].trim();
      const sEq: number = seg.indexOf('=');
      const k: string = (sEq >= 0 ? seg.substring(0, sEq) : seg).trim().toLowerCase();
      const v: string = sEq >= 0 ? seg.substring(sEq + 1).trim() : '';
      if (k === 'domain' && v.length > 0) {
        domain = v.replace(/^\./, '');
      } else if (k === 'path' && v.length > 0) {
        path = v;
      }
    }
    out.push({ name: name, value: value, domain: domain, path: path });
  }
  return out;
}

export class ZhihuBridge {
  /** name -> CookieEntry */
  private jar: Map<string, CookieEntry> = new Map<string, CookieEntry>();
  private store: preferences.Preferences | null = null;
  private loaded: boolean = false;

  // ---------- 持久化 ----------
  private ensureLoaded(): void {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    try {
      if (!appContext) {
        return;
      }
      this.store = preferences.getPreferencesSync(appContext, { name: PREF_NAME });
      const raw = this.store.getSync(COOKIE_STORE_KEY, '[]') as string;
      const arr = JSON.parse(raw) as CookieEntry[];
      if (arr && arr.length > 0) {
        for (const c of arr) {
          if (c && typeof c.name === 'string') {
            this.jar.set(c.name, c);
          }
        }
        hilog.info(DOMAIN, TAG, 'cookie jar loaded: %{public}d', this.jar.size);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'load cookie jar failed: %{public}s', JSON.stringify(e));
      this.store = null;
    }
  }

  private persist(): void {
    try {
      if (!this.store) {
        return;
      }
      const arr: CookieEntry[] = [];
      this.jar.forEach((v: CookieEntry) => {
        arr.push(v);
      });
      this.store.putSync(COOKIE_STORE_KEY, JSON.stringify(arr));
      this.store.flushSync();
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'persist cookie jar failed: %{public}s', JSON.stringify(e));
    }
  }

  // ---------- Cookie Jar ----------
  private ingestSetCookie(raw: string, fallbackHost: string): void {
    if (!raw || raw.length === 0) {
      return;
    }
    const entries: CookieEntry[] = parseSetCookie(raw, fallbackHost);
    for (const c of entries) {
      // 值被清空视为删除
      if (c.value.length === 0 || c.value === 'deleted') {
        this.jar.delete(c.name);
      } else {
        this.jar.set(c.name, c);
      }
    }
    if (entries.length > 0) {
      this.persist();
    }
  }

  private cookieStringFor(url: string): string {
    const host: string = hostOf(url);
    let out: string = '';
    this.jar.forEach((c: CookieEntry) => {
      if (host.length === 0 || c.domain.length === 0 || host.endsWith(c.domain)) {
        out += (out.length > 0 ? '; ' : '') + c.name + '=' + c.value;
      }
    });
    return out;
  }

  // ---------- 暴露给 JS ----------
  public getCookies(): string {
    this.ensureLoaded();
    const out: Record<string, string> = {};
    this.jar.forEach((c: CookieEntry) => {
      out[c.name] = c.value;
    });
    return JSON.stringify(out);
  }

  public setCookie(url: string, cookieString: string): string {
    this.ensureLoaded();
    this.ingestSetCookie(cookieString, hostOf(url));
    return JSON.stringify({ ok: true, size: this.jar.size });
  }

  public clearCookies(): string {
    this.jar.clear();
    this.persist();
    return JSON.stringify({ ok: true });
  }

  /** 预热游客 cookie：GET 知乎首页，把下发的 Set-Cookie 收进 Jar */
  public async bootstrap(): Promise<string> {
    this.ensureLoaded();
    try {
      const req = http.createHttp();
      const resp = await req.request(BOOTSTRAP_URL, {
        method: http.RequestMethod.GET,
        header: {
          'User-Agent': DESKTOP_UA,
          'Accept': 'text/html,application/xhtml+xml',
        },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 20000,
        usingCache: false,
      });
      const ck = resp.header as Record<string, string>;
      const setCookie = ck ? String(ck['set-cookie'] ?? '') : '';
      this.ingestSetCookie(setCookie, 'www.zhihu.com');
      if (setCookie.length === 0 && resp.cookies && resp.cookies.length > 0) {
        this.ingestSetCookie(resp.cookies, 'www.zhihu.com');
      }
      req.destroy();
      hilog.info(DOMAIN, TAG, 'bootstrap done, cookies=%{public}d', this.jar.size);
      return JSON.stringify({ ok: true, cookies: this.getCookies() });
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'bootstrap failed: %{public}s', JSON.stringify(e));
      return JSON.stringify({ ok: false, error: JSON.stringify(e) });
    }
  }

  /**
   * 发起原生 HTTP 请求。
   * 返回 JSON 字符串：{ status, statusText, headers, body, error }
   */
  public async request(url: string, method: string, headersJson: string, body: string): Promise<string> {
    this.ensureLoaded();
    const result: BridgeResult = {
      status: 0,
      statusText: '',
      headers: {} as Record<string, string>,
      body: '',
      error: '',
    };

    let req: http.HttpRequest | null = null;
    try {
      const headers: Record<string, string> = {};
      if (headersJson && headersJson.length > 0) {
        try {
          const parsed = JSON.parse(headersJson) as Record<string, string>;
          if (parsed) {
            const keys = Object.keys(parsed);
            for (const k of keys) {
              const lk = k.toLowerCase();
              // 交由原生栈自己管理的头，避免重复/非法
              if (lk === 'content-length' || lk === 'host' || lk === 'connection') {
                continue;
              }
              headers[k] = String(parsed[k]);
            }
          }
        } catch (e) {
          hilog.warn(DOMAIN, TAG, 'bad headers json, ignored');
        }
      }

      const lowered = lowerKeys(headers);
      if (!hasKey(lowered, 'cookie')) {
        const jarCookie = this.cookieStringFor(url);
        if (jarCookie.length > 0) {
          headers['Cookie'] = jarCookie;
        }
      }
      if (!hasKey(lowered, 'user-agent')) {
        headers['User-Agent'] = DESKTOP_UA;
      }

      req = http.createHttp();
      const options: http.HttpRequestOptions = {
        method: this.toMethod(method),
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 25000,
        usingCache: false,
      };
      if (body && body.length > 0) {
        options.extraData = body;
      }

      const resp = await req.request(url, options);
      result.status = typeof resp.responseCode === 'number' ? resp.responseCode : 0;

      const respHeadersRaw = resp.header as Record<string, string>;
      const respHeaders: Record<string, string> = {};
      if (respHeadersRaw) {
        const keys = Object.keys(respHeadersRaw);
        for (const k of keys) {
          respHeaders[k.toLowerCase()] = String(respHeadersRaw[k]);
        }
      }
      result.headers = respHeaders;

      if (typeof resp.result === 'string') {
        result.body = resp.result;
      } else if (resp.result !== undefined && resp.result !== null) {
        result.body = String(resp.result);
      }

      const setCookie = respHeaders['set-cookie'] ?? '';
      if (setCookie.length > 0) {
        this.ingestSetCookie(setCookie, hostOf(url));
      } else if (resp.cookies && resp.cookies.length > 0) {
        this.ingestSetCookie(resp.cookies, hostOf(url));
      }

      hilog.info(DOMAIN, TAG, 'native %{public}s %{public}s -> %{public}d (%{public}d B)',
        method, url.substring(0, 90), result.status, result.body.length);
    } catch (e) {
      const err = e as BusinessError;
      result.error = JSON.stringify(e);
      const code = err && err.code !== undefined ? err.code : -1;
      const msg = err && err.message !== undefined ? err.message : 'unknown';
      hilog.error(DOMAIN, TAG, 'native request failed %{public}s code=%{public}d msg=%{public}s',
        url.substring(0, 90), code, msg);
    } finally {
      if (req) {
        try {
          req.destroy();
        } catch (e) {
          // ignore
        }
      }
    }

    return JSON.stringify(result);
  }

  private toMethod(m: string): http.RequestMethod {
    const up = (m ?? 'GET').toUpperCase();
    switch (up) {
      case 'POST':
        return http.RequestMethod.POST;
      case 'PUT':
        return http.RequestMethod.PUT;
      case 'DELETE':
        return http.RequestMethod.DELETE;
      case 'HEAD':
        return http.RequestMethod.HEAD;
      case 'OPTIONS':
        return http.RequestMethod.OPTIONS;
      case 'PATCH':
        // 该 SDK 的 http.RequestMethod 无 PATCH 枚举，退化为 POST（部分更新用 POST 替代）
        return http.RequestMethod.POST;
      case 'TRACE':
        return http.RequestMethod.TRACE;
      case 'CONNECT':
        return http.RequestMethod.CONNECT;
      default:
        return http.RequestMethod.GET;
    }
  }
}
