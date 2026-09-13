/**
 * 认证状态（单账号，v1.0 简化版）—— 对应上游 store/useAuthStore.ts 的 Cookie 部分。
 * 由 httpClient 在每次响应后回写 cookie；UI 通过登录页/启动 bootstrap 驱动。
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
// AppStorage 为全局 API（V1），SDK 6.0.2 起不再从 @kit.ArkUI 导出，无需 import

const PREF_NAME: string = 'zhihu_native';
const COOKIE_KEY: string = 'auth_cookie';
const USER_NAME_KEY: string = 'user_name';

let appContext: common.Context | null = null;

/** 登录态版本号：登录/登出翻转时 +1，主框架据此强制重建各列表页（登录后状态刷新）。 */
function bumpLoginVersion(): void {
  const v = AppStorage.get<number>('loginVersion') ?? 0;
  AppStorage.setOrCreate('loginVersion', v + 1);
}

export function setAppContext(ctx: common.Context): void {
  appContext = ctx;
  authStore.loadFromDisk();
}

export function hasAuthenticationCookie(cookie: string): boolean {
  return cookie.length > 0 && /(?:^|;\s*)z_c0=/.test(cookie);
}

function getDc0(cookie: string): string {
  const match = cookie.match(/d_c0=([^;]+)/);
  return match ? match[1] : '';
}

function getXsrf(cookie: string): string {
  const match = cookie.match(/_xsrf=([^;]+)/);
  return match ? match[1] : '';
}

class AuthStore {
  private pref: preferences.Preferences | null = null;
  private loaded: boolean = false;
  private cookie: string = '';
  private displayName: string = '';

  loadFromDisk(): void {
    if (this.loaded) {
      return;
    }
    this.loaded = true;
    try {
      if (!appContext) {
        return;
      }
      this.pref = preferences.getPreferencesSync(appContext, { name: PREF_NAME });
      this.cookie = this.pref.getSync(COOKIE_KEY, '') as string;
      this.displayName = this.pref.getSync(USER_NAME_KEY, '') as string;
    } catch (e) {
      this.pref = null;
    }
  }

  get cookies(): string {
    return this.cookie;
  }

  get isLoggedIn(): boolean {
    return hasAuthenticationCookie(this.cookie);
  }

  get dc0(): string {
    return getDc0(this.cookie);
  }

  get xsrf(): string {
    return getXsrf(this.cookie);
  }

  get userName(): string {
    return this.displayName;
  }

  setCookies(cookie: string): void {
    const wasLoggedIn = hasAuthenticationCookie(this.cookie);
    this.cookie = cookie;
    this.persist();
    if (wasLoggedIn !== hasAuthenticationCookie(this.cookie)) {
      bumpLoginVersion();
    }
  }

  setUserName(name: string): void {
    this.displayName = name;
    try {
      if (this.pref) {
        this.pref.putSync(USER_NAME_KEY, name);
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }

  clear(): void {
    const wasLoggedIn = this.isLoggedIn;
    this.cookie = '';
    this.displayName = '';
    this.persist();
    if (wasLoggedIn) {
      bumpLoginVersion();
    }
  }

  private persist(): void {
    try {
      if (this.pref) {
        this.pref.putSync(COOKIE_KEY, this.cookie);
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }
}

export const authStore = new AuthStore();

/**
 * 暴露已初始化的应用上下文（供同 preferences 体系的其它 store 懒加载复用，
 * 避免重复改 EntryAbility）。未初始化时返回 null。
 */
export function getAppContext(): common.Context | null {
  return appContext;
}
