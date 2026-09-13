/**
 * 原生 HTTP 客户端（对应上游 api/client.ts 的适配层）
 * ----------------------------------------------------------------------------
 * 用 @ohos.net.http 替代 axios：
 *   · 原生请求不受 CORS 约束
 *   · 自动携带知乎签名头（x-zse-96 / x-zse-93 / X-Udid …）
 *   · 原生侧统一维护 Cookie Jar（持久化到 preferences，游客/登录态都保持）
 *   · 401 时自动刷新会话（token refresh + oauth sign_in，复用 hmac/encryptZseV4）
 *
 * v1.0 简化：单账号、无 AbortSignal、无并发去重。
 */

import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { signRequest96, hmacSha1Hex, encryptZseV4, ZSE_VERSION } from './zse96/index';
import { authStore, hasAuthenticationCookie } from '../store/authStore';

const DOMAIN: number = 0x0002;
const TAG: string = 'ZhihuHttp';

const ZHIHU_BASE: string = 'https://www.zhihu.com';
const BOOTSTRAP_URL: string = ZHIHU_BASE + '/';
const DESKTOP_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

// 知乎 oauth 固定参数（与上游 client.ts 一致）
const OAUTH_CLIENT_ID: string = 'c3cef7c66a1843f8b3a9e6a1e3160e20';
const OAUTH_SECRET: string = 'd1b964811afb40118a12068ff74a12f4';

export interface ApiResponse<T> {
  status: number;
  headers: Record<string, string>;
  data: T;
}

export interface RequestOptions {
  headers?: Record<string, string>;
  /** 请求体（raw string） */
  data?: string;
  /** 401 时是否自动刷新会话并重试（默认 true） */
  retryOnUnauthorized?: boolean;
}

export class ApiError extends Error {
  status: number;
  code: number;
  body: string;

  constructor(message: string, status: number, code: number, body: string) {
    super(message);
    this.status = status;
    this.code = code;
    this.body = body;
  }
}

// ---------------------------------------------------------------------------
// Cookie Jar
// ---------------------------------------------------------------------------

interface CookieEntry {
  name: string;
  value: string;
  domain: string;
  path: string;
}

function hostOf(url: string): string {
  try {
    const noProto: string = url.replace(/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//, '');
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

class CookieJar {
  private jar: Map<string, CookieEntry> = new Map<string, CookieEntry>();

  /** 从持久化 cookie 串恢复（启动时） */
  hydrate(cookieString: string): void {
    const parts: string[] = cookieString.split(';');
    for (const part of parts) {
      const eq: number = part.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      const name: string = part.substring(0, eq).trim();
      const value: string = part.substring(eq + 1).trim();
      if (name.length > 0 && value.length > 0) {
        this.jar.set(name, { name: name, value: value, domain: '', path: '/' });
      }
    }
  }

  ingest(raw: string, fallbackHost: string): void {
    if (!raw || raw.length === 0) {
      return;
    }
    const entries: CookieEntry[] = parseSetCookie(raw, fallbackHost);
    for (const c of entries) {
      if (c.value.length === 0 || c.value === 'deleted') {
        this.jar.delete(c.name);
      } else {
        this.jar.set(c.name, c);
      }
    }
  }

  cookieStringFor(url: string): string {
    const host: string = hostOf(url);
    let out: string = '';
    this.jar.forEach((c: CookieEntry) => {
      if (host.length === 0 || c.domain.length === 0 || host.endsWith(c.domain)) {
        out += (out.length > 0 ? '; ' : '') + c.name + '=' + c.value;
      }
    });
    return out;
  }

  toString(): string {
    let out: string = '';
    this.jar.forEach((c: CookieEntry) => {
      out += (out.length > 0 ? '; ' : '') + c.name + '=' + c.value;
    });
    return out;
  }

  size(): number {
    return this.jar.size;
  }
}

// ---------------------------------------------------------------------------
// HTTP 客户端
// ---------------------------------------------------------------------------

class ZhihuHttpClient {
  private jar: CookieJar = new CookieJar();
  private bootstrapPromise: Promise<boolean> | null = null;
  private refreshPromise: Promise<boolean> | null = null;

  /** 未登录时预热游客 cookie（d_c0 等），首页匿名可读 */
  ensureGuestCookies(): Promise<boolean> {
    if (this.jar.size() > 0 || authStore.cookies.length > 0) {
      return Promise.resolve(true);
    }
    if (!this.bootstrapPromise) {
      this.bootstrapPromise = this.bootstrap();
    }
    return this.bootstrapPromise;
  }

  private async bootstrap(): Promise<boolean> {
    try {
      const resp = await this.rawRequest('GET', BOOTSTRAP_URL, {
        'User-Agent': DESKTOP_UA,
        'Accept': 'text/html,application/xhtml+xml',
      }, '');
      const setCookie = resp.headers['set-cookie'] ?? '';
      if (setCookie.length > 0) {
        this.ingestCookies(setCookie, 'www.zhihu.com');
      }
      hilog.info(DOMAIN, TAG, 'bootstrap ok, cookies=%{public}d', this.jar.size());
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'bootstrap failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  private ingestCookies(raw: string, host: string): void {
    this.jar.ingest(raw, host);
    // 同步持久化（登录态保持）
    const all = this.jar.toString();
    if (all.length > 0) {
      authStore.setCookies(all);
    }
  }

  /** 登录页 Web 组件捕获的 cookie 导入（同步 jar + 持久化） */
  importCookies(cookieString: string): void {
    if (!cookieString || cookieString.length === 0) {
      return;
    }
    this.jar.hydrate(cookieString);
    authStore.setCookies(cookieString);
  }

  /** 当前完整 cookie 串（登录页读取用） */
  exportCookies(): string {
    const jar = this.jar.toString();
    return jar.length > 0 ? jar : authStore.cookies;
  }

  get<T>(url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request('GET', url, options);
  }

  post<T>(url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request('POST', url, options);
  }

  put<T>(url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request('PUT', url, options);
  }

  delete<T>(url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request('DELETE', url, options);
  }

  patch<T>(url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request('PATCH', url, options);
  }

  /** 通用 method 入口（与 get/post 同一条 cookie/签名/401 刷新通道） */
  send<T>(method: string, url: string, options?: RequestOptions): Promise<ApiResponse<T>> {
    return this.request(method, url, options);
  }

  private async request<T>(
    method: string,
    url: string,
    options?: RequestOptions,
  ): Promise<ApiResponse<T>> {
    await this.ensureGuestCookies();
    if (this.jar.size() === 0 && authStore.cookies.length > 0) {
      this.jar.hydrate(authStore.cookies);
    }

    const cookie = this.jar.cookieStringFor(url);
    const headers = await this.buildHeaders(url, options?.headers, options?.data, cookie);

    let resp = await this.doSignedRequest(method, url, headers, options?.data ?? '');
    if (
      resp.status === 401 &&
      hasAuthenticationCookie(authStore.cookies) &&
      (options?.retryOnUnauthorized ?? true)
    ) {
      const refreshed = await this.refreshSession();
      if (refreshed) {
        const cookie2 = this.jar.cookieStringFor(url);
        const headers2 = await this.buildHeaders(url, options?.headers, options?.data, cookie2);
        resp = await this.doSignedRequest(method, url, headers2, options?.data ?? '');
      }
    }

    if (resp.status >= 400) {
      throw this.buildError(resp.status, resp.body);
    }
    return {
      status: resp.status,
      headers: resp.headers,
      data: this.parseJson<T>(resp.body),
    };
  }

  private async doSignedRequest(
    method: string,
    url: string,
    headers: Record<string, string>,
    body: string,
  ): Promise<{ status: number; headers: Record<string, string>; body: string }> {
    const resp = await this.rawRequest(method, url, headers, body);
    const setCookie = resp.headers['set-cookie'] ?? '';
    if (setCookie.length > 0) {
      this.ingestCookies(setCookie, hostOf(url));
    }
    return resp;
  }

  private async rawRequest(
    method: string,
    url: string,
    headers: Record<string, string>,
    body: string,
  ): Promise<{ status: number; headers: Record<string, string>; body: string }> {
    const req = http.createHttp();
    try {
      const lower: Record<string, string> = {};
      const keys = Object.keys(headers);
      for (const k of keys) {
        lower[k.toLowerCase()] = headers[k];
      }
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
      let resp;
      try {
        resp = await req.request(url, options);
      } catch (e) {
        // 网络层异常（DNS 失败/连接失败/超时/权限被拒等）——转成带错误码的 ApiError，
        // 让页面能显示具体原因而非通用文案。
        let msg = '网络请求失败';
        let code = -1;
        if (e instanceof Error) {
          msg = e.message;
        } else if (e && typeof e === 'object') {
          const obj = e as Record<string, object>;
          const errObj = obj['cause'] as Record<string, object> | undefined;
          const inner = errObj ?? obj;
          if (typeof inner['message'] === 'string') {
            msg = inner['message'] as string;
          }
          if (typeof inner['code'] === 'number') {
            code = inner['code'] as number;
          } else if (typeof obj['code'] === 'number') {
            code = obj['code'] as number;
          }
        }
        hilog.error(DOMAIN, TAG, 'http error: %{public}s code=%{public}d', msg, code);
        throw new ApiError(msg, 0, code, '');
      }
      const status: number = typeof resp.responseCode === 'number' ? resp.responseCode : 0;
      const respHeaders: Record<string, string> = {};
      const rawHeaders = resp.header as Record<string, string>;
      if (rawHeaders) {
        const hKeys = Object.keys(rawHeaders);
        for (const k of hKeys) {
          respHeaders[k.toLowerCase()] = String(rawHeaders[k]);
        }
      }
      let text: string = '';
      if (typeof resp.result === 'string') {
        text = resp.result;
      } else if (resp.result !== undefined && resp.result !== null) {
        text = String(resp.result);
      }
      return { status: status, headers: respHeaders, body: text };
    } finally {
      try {
        req.destroy();
      } catch (e) {
        // ignore
      }
    }
  }

  private async buildHeaders(
    url: string,
    extra: Record<string, string> | undefined,
    body: string | null,
    cookie: string,
  ): Promise<Record<string, string>> {
    const headers: Record<string, string> = {};
    if (cookie && cookie.length > 0) {
      headers['Cookie'] = cookie;
      const dc0 = this.dc0Of(cookie);
      const xsrf = this.xsrfOf(cookie);
      if (xsrf.length > 0) {
        headers['x-xsrftoken'] = xsrf;
      }
      if (dc0.length > 0) {
        const udidParts = dc0.split('|');
        headers['X-Udid'] = udidParts.length > 0 ? udidParts[0] : dc0;
        const hostname = hostOf(url);
        if (hostname !== 'zhuanlan.zhihu.com') {
          try {
            headers['x-zse-96'] = await signRequest96(url, body, cookie);
          } catch (e) {
            hilog.warn(DOMAIN, TAG, 'sign failed: %{public}s', JSON.stringify(e));
          }
          headers['x-zse-93'] = ZSE_VERSION;
        }
        headers['x-requested-with'] = 'fetch';
        headers['Referer'] = hostname === 'zhuanlan.zhihu.com'
          ? 'https://zhuanlan.zhihu.com/write'
          : 'https://www.zhihu.com/';
      }
    }
    headers['User-Agent'] = DESKTOP_UA;
    if (extra) {
      const extraKeys = Object.keys(extra);
      for (const k of extraKeys) {
        headers[k] = extra[k];
      }
    }
    return headers;
  }

  private dc0Of(cookie: string): string {
    const match = cookie.match(/d_c0=([^;]+)/);
    return match ? match[1] : '';
  }

  private xsrfOf(cookie: string): string {
    const match = cookie.match(/_xsrf=([^;]+)/);
    return match ? match[1] : '';
  }

  // ---------- 401 会话刷新（上游 performZhihuSessionRefresh 的简化移植） ----------

  private refreshSession(): Promise<boolean> {
    if (this.refreshPromise) {
      return this.refreshPromise;
    }
    const promise = this.doRefreshSession().finally(() => {
      this.refreshPromise = null;
    });
    this.refreshPromise = promise;
    return promise;
  }

  private async doRefreshSession(): Promise<boolean> {
    const cookie = authStore.cookies;
    if (!hasAuthenticationCookie(cookie)) {
      return false;
    }
    const commonHeaders: Record<string, string> = {
      'Cookie': cookie,
      'Origin': ZHIHU_BASE,
      'Referer': ZHIHU_BASE + '/signin',
      'x-requested-with': 'fetch',
      'User-Agent': DESKTOP_UA,
    };
    try {
      // 1) 换取 refresh_token
      const tokenResp = await this.rawRequest(
        'POST',
        ZHIHU_BASE + '/api/account/prod/token/refresh',
        commonHeaders,
        '',
      );
      const tokenSetCookie = tokenResp.headers['set-cookie'] ?? '';
      if (tokenSetCookie.length > 0) {
        this.ingestCookies(tokenSetCookie, 'www.zhihu.com');
      }
      const tokenBody = this.tryParse(tokenResp.body);
      const refreshToken = this.getStringField(tokenBody, 'refresh_token');
      if (!refreshToken) {
        return false;
      }

      // 2) oauth sign_in
      const timestamp = Date.now();
      const signature = hmacSha1Hex(
        OAUTH_SECRET,
        'refresh_token' + OAUTH_CLIENT_ID + 'com.zhihu.web' + String(timestamp),
      );
      const formData =
        'client_id=' + encodeURIComponent(OAUTH_CLIENT_ID) +
        '&grant_type=' + encodeURIComponent('refresh_token') +
        '&timestamp=' + encodeURIComponent(String(timestamp)) +
        '&source=' + encodeURIComponent('com.zhihu.web') +
        '&signature=' + encodeURIComponent(signature) +
        '&refresh_token=' + encodeURIComponent(refreshToken);

      const oauthHeaders: Record<string, string> = {
        'Cookie': this.jar.cookieStringFor(ZHIHU_BASE + '/api/v3/oauth/sign_in') || cookie,
        'Origin': ZHIHU_BASE,
        'Referer': ZHIHU_BASE + '/signin',
        'x-requested-with': 'fetch',
        'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
        'x-zse-83': '3_3.0',
        'User-Agent': DESKTOP_UA,
      };
      const oauthResp = await this.rawRequest(
        'POST',
        ZHIHU_BASE + '/api/v3/oauth/sign_in',
        oauthHeaders,
        encryptZseV4(formData),
      );
      const oauthSetCookie = oauthResp.headers['set-cookie'] ?? '';
      if (oauthSetCookie.length > 0) {
        this.ingestCookies(oauthSetCookie, 'www.zhihu.com');
      }
      return hasAuthenticationCookie(authStore.cookies);
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'session refresh failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  // ---------- 工具 ----------

  private tryParse(text: string): Record<string, object> {
    if (!text || text.length === 0) {
      return {};
    }
    try {
      const obj = JSON.parse(text) as Record<string, object>;
      return obj || {};
    } catch (e) {
      return {};
    }
  }

  private getStringField(record: Record<string, object>, field: string): string | null {
    const value = record[field];
    return typeof value === 'string' && (value as string).length > 0 ? value as string : null;
  }

  private parseJson<T>(text: string): T {
    if (!text || text.length === 0) {
      throw new ApiError('响应为空', 0, -1, text);
    }
    try {
      const obj = JSON.parse(text) as T;
      return obj;
    } catch (e) {
      throw new ApiError('响应解析失败', 0, -1, text.substring(0, 200));
    }
  }

  private buildError(status: number, body: string): ApiError {
    const record = this.tryParse(body);
    // 尝试 { error: { message } } / { message }
    const errorObj = record['error'];
    let message: string = '';
    if (errorObj && typeof errorObj === 'object') {
      const m = this.getStringField(errorObj as Record<string, object>, 'message');
      if (m) {
        message = m;
      }
    }
    if (!message) {
      const m2 = this.getStringField(record, 'message');
      if (m2) {
        message = m2;
      }
    }
    if (!message) {
      message = this.statusMessage(status);
    }
    let code: number = -1;
    if (errorObj && typeof errorObj === 'object') {
      const c = (errorObj as Record<string, object>)['code'];
      if (typeof c === 'number') {
        code = c as number;
      }
    }
    return new ApiError(message, status, code, body.substring(0, 500));
  }

  private statusMessage(status: number): string {
    if (status === 400) return '请求参数无效，请检查后重试';
    if (status === 401) return '登录状态已失效，请重新登录';
    if (status === 403) return '当前账号没有执行此操作的权限';
    if (status === 404) return '请求的内容不存在或已被删除';
    if (status === 408) return '请求超时，请稍后重试';
    if (status === 429) return '操作太频繁，请稍后重试';
    if (status >= 500) return '知乎服务暂时不可用，请稍后重试';
    return '请求失败（' + String(status) + '）';
  }

  private toMethod(m: string): http.RequestMethod {
    const up = (m ?? 'GET').toUpperCase();
    switch (up) {
      case 'POST': return http.RequestMethod.POST;
      case 'PUT': return http.RequestMethod.PUT;
      case 'DELETE': return http.RequestMethod.DELETE;
      case 'HEAD': return http.RequestMethod.HEAD;
      case 'OPTIONS': return http.RequestMethod.OPTIONS;
      // 已知限制：@ohos.net.http 的 RequestMethod 枚举无 PATCH（SDK 未提供），
      // 映射为 POST。上游 article.ts 草稿保存用 PATCH，zhuanlan 对 POST 兼容，
      // 属可接受降级（AUDIT M7）。
      case 'PATCH': return http.RequestMethod.POST;
      default: return http.RequestMethod.GET;
    }
  }
}

export const zhihuClient = new ZhihuHttpClient();
