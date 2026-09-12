/**
 * 设置持久化 store —— 对应上游 store/useSettingsStore.ts 的本地后处理 / 服务端开关 /
 * 主题模式部分，写法照 store/authStore.ts（preferences 单例 + 同步读写）。
 *
 * 持久化 key（preferences 名：zhihu_settings）：
 *   content_filter_enabled   本地后处理·内容过滤 总开关（默认关）
 *   feed_dedup_enabled       本地后处理·去重与缓存·本地 Feed 去重（默认关）
 *   keep_recommend_on_launch 本地后处理·去重与缓存·启动时保留推荐流（默认关）
 *   send_desktop_param       服务端请求参数·发送 desktop=true（默认开）
 *   send_ad_interval_param   服务端请求参数·发送 ad_interval（默认开）
 *   theme_mode               主题模式：auto | light | dark（默认 auto）
 *   feed_dedup_ids           本地去重记录（JSON 字符串数组，有上限）
 *   visible_tabs             栏目可见性（JSON 字符串数组，默认六栏）
 *   default_tab               启动默认栏目 key（默认 following）
 */

import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { getAppContext } from './authStore';

const PREF_NAME: string = 'zhihu_settings';

const KEY_CONTENT_FILTER = 'content_filter_enabled';
const KEY_FEED_DEDUP = 'feed_dedup_enabled';
const KEY_KEEP_RECOMMEND = 'keep_recommend_on_launch';
const KEY_SEND_DESKTOP = 'send_desktop_param';
const KEY_SEND_AD_INTERVAL = 'send_ad_interval_param';
const KEY_THEME_MODE = 'theme_mode';
const KEY_DEDUP_IDS = 'feed_dedup_ids';
const KEY_VISIBLE_TABS = 'visible_tabs';
const KEY_DEFAULT_TAB = 'default_tab';

const DEDUP_ID_CAP: number = 800;

const DEFAULT_VISIBLE_TABS: string[] =
  ['following', 'recommend', 'hot', 'daily', 'publish', 'profile'];
const DEFAULT_DEFAULT_TAB: string = 'recommend'; // 上游 useSettingsStore.ts 默认 defaultTab='recommend'（打开进推荐）

export type ThemeMode = 'auto' | 'light' | 'dark';

function asThemeMode(raw: string): ThemeMode {
  if (raw === 'light' || raw === 'dark') {
    return raw;
  }
  return 'auto';
}

class SettingsStore {
  private pref: preferences.Preferences | null = null;
  private loaded: boolean = false;

  private contentFilterEnabled: boolean = false;
  private feedDedupEnabled: boolean = false;
  private keepRecommendOnLaunch: boolean = false;
  private sendDesktop: boolean = true;
  private sendAdInterval: boolean = true;
  private themeMode: ThemeMode = 'auto';
  private dedupIds: string[] = [];
  private systemDark: boolean = false;
  private visibleTabs: string[] = DEFAULT_VISIBLE_TABS.slice();
  private defaultTab: string = DEFAULT_DEFAULT_TAB;
  private version: number = 0;

  /** @Entry 页面 aboutToAppear 调用；也会回退到 authStore 已初始化的 context。 */
  init(context?: common.Context): void {
    const ctx: common.Context | null = context ?? getAppContext();
    if (!ctx) {
      return;
    }
    try {
      this.pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
      this.contentFilterEnabled = this.pref.getSync(KEY_CONTENT_FILTER, false) as boolean;
      this.feedDedupEnabled = this.pref.getSync(KEY_FEED_DEDUP, false) as boolean;
      this.keepRecommendOnLaunch = this.pref.getSync(KEY_KEEP_RECOMMEND, false) as boolean;
      this.sendDesktop = this.pref.getSync(KEY_SEND_DESKTOP, true) as boolean;
      this.sendAdInterval = this.pref.getSync(KEY_SEND_AD_INTERVAL, true) as boolean;
      this.themeMode = asThemeMode(this.pref.getSync(KEY_THEME_MODE, 'auto') as string);
      this.dedupIds = this.parseIds(this.pref.getSync(KEY_DEDUP_IDS, '[]') as string);
      this.visibleTabs = this.parseTabList(
        this.pref.getSync(KEY_VISIBLE_TABS, '') as string);
      this.defaultTab = this.pref.getSync(KEY_DEFAULT_TAB, DEFAULT_DEFAULT_TAB) as string;
      this.sanitizeTabs();
      this.captureSystemDark(ctx);
      // 启动语义：未勾选“启动时保留推荐流”→ 启动即清空上次的去重记录
      if (!this.keepRecommendOnLaunch && this.dedupIds.length > 0) {
        this.dedupIds = [];
        this.persistIds();
      }
      this.loaded = true;
      this.version++;
    } catch (e) {
      this.pref = null;
    }
  }

  private ensure(): void {
    if (this.loaded) {
      return;
    }
    this.init();
  }

  private captureSystemDark(ctx: common.Context): void {
    try {
      // 通用 common.Context 无 .config 属性；经 resourceManager 同步读取当前配置。
      // 注意：此处 colorMode 为 resourceManager.ColorMode（DARK=0 / LIGHT=1），
      // 与 @kit.AbilityKit 的 ConfigurationConstant.ColorMode 不是同一枚举，不能混用比较。
      const colorMode = ctx.resourceManager.getConfigurationSync().colorMode;
      this.systemDark = colorMode === 0;
    } catch (e) {
      this.systemDark = false;
    }
  }

  private parseIds(raw: string): string[] {
    if (!raw || raw.length === 0) {
      return [];
    }
    try {
      const arr = JSON.parse(raw) as string[];
      return Array.isArray(arr) ? arr : [];
    } catch (e) {
      return [];
    }
  }

  /** 解析 visible_tabs；非法/空时回退默认六栏。 */
  private parseTabList(raw: string): string[] {
    if (!raw || raw.length === 0) {
      return DEFAULT_VISIBLE_TABS.slice();
    }
    try {
      const arr = JSON.parse(raw) as string[];
      if (!Array.isArray(arr) || arr.length === 0) {
        return DEFAULT_VISIBLE_TABS.slice();
      }
      return arr.slice();
    } catch (e) {
      return DEFAULT_VISIBLE_TABS.slice();
    }
  }

  /** 保证 profile 常驻、至少保留一栏、defaultTab 仍在可见列表内。 */
  private sanitizeTabs(): void {
    // profile 不可隐藏
    if (this.visibleTabs.indexOf('profile') < 0) {
      this.visibleTabs = this.visibleTabs.concat(['profile']);
    }
    if (this.visibleTabs.length === 0) {
      this.visibleTabs = DEFAULT_VISIBLE_TABS.slice();
    }
    if (this.visibleTabs.indexOf(this.defaultTab) < 0) {
      this.defaultTab = this.visibleTabs[0];
    }
  }

  private persistTabs(): void {
    try {
      if (this.pref) {
        this.pref.putSync(KEY_VISIBLE_TABS, JSON.stringify(this.visibleTabs));
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }

  private persistDefaultTab(): void {
    try {
      if (this.pref) {
        this.pref.putSync(KEY_DEFAULT_TAB, this.defaultTab);
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }

  private persistIds(): void {
    try {
      if (this.pref) {
        this.pref.putSync(KEY_DEDUP_IDS, JSON.stringify(this.dedupIds));
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }

  private persistBool(key: string, value: boolean): void {
    try {
      if (this.pref) {
        this.pref.putSync(key, value);
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }

  // ---------------- 读取 ----------------

  getContentFilterEnabled(): boolean {
    this.ensure();
    return this.contentFilterEnabled;
  }

  isDedupEnabled(): boolean {
    this.ensure();
    return this.feedDedupEnabled;
  }

  isKeepRecommendOnLaunch(): boolean {
    this.ensure();
    return this.keepRecommendOnLaunch;
  }

  isSendDesktop(): boolean {
    this.ensure();
    return this.sendDesktop;
  }

  isSendAdInterval(): boolean {
    this.ensure();
    return this.sendAdInterval;
  }

  getThemeMode(): ThemeMode {
    this.ensure();
    return this.themeMode;
  }

  isSystemDark(): boolean {
    return this.systemDark;
  }

  /** 主题设置每变化一次 +1，供页面 @State 触发重渲染。 */
  getVersion(): number {
    return this.version;
  }

  /** 当前可见栏目 key 列表（保持上游顺序）。 */
  getVisibleTabs(): string[] {
    this.ensure();
    return this.visibleTabs;
  }

  getDefaultTab(): string {
    this.ensure();
    return this.defaultTab;
  }

  isTabVisible(key: string): boolean {
    this.ensure();
    return this.visibleTabs.indexOf(key) >= 0;
  }

  // ---------------- 写入 ----------------

  setContentFilterEnabled(value: boolean): void {
    this.contentFilterEnabled = value;
    this.persistBool(KEY_CONTENT_FILTER, value);
  }

  setDedupEnabled(value: boolean): void {
    this.feedDedupEnabled = value;
    this.persistBool(KEY_FEED_DEDUP, value);
  }

  setKeepRecommendOnLaunch(value: boolean): void {
    this.keepRecommendOnLaunch = value;
    this.persistBool(KEY_KEEP_RECOMMEND, value);
  }

  setSendDesktop(value: boolean): void {
    this.sendDesktop = value;
    this.persistBool(KEY_SEND_DESKTOP, value);
  }

  setSendAdInterval(value: boolean): void {
    this.sendAdInterval = value;
    this.persistBool(KEY_SEND_AD_INTERVAL, value);
  }

  setThemeMode(mode: ThemeMode): void {
    this.themeMode = mode;
    try {
      if (this.pref) {
        this.pref.putSync(KEY_THEME_MODE, mode);
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
    this.version++;
  }

  /** 直接设置可见栏目（含持久化）。 */
  setVisibleTabs(tabs: string[]): void {
    this.visibleTabs = tabs.slice();
    this.sanitizeTabs();
    this.persistTabs();
    this.persistDefaultTab();
    this.version++;
  }

  setDefaultTab(tab: string): void {
    this.defaultTab = tab;
    this.persistDefaultTab();
    this.version++;
  }

  /**
   * 切换栏目可见性（规则严格按上游）：
   *   · profile 不可隐藏，直接返回原数组；
   *   · 关闭某栏前若将只剩 0 个则拒绝（至少保留 1 个）；
   *   · toggle 后 defaultTab 不在新可见列表里则重置为新可见列表第一项；
   *   · 返回更新后的可见数组并持久化。
   */
  toggleTab(key: string): string[] {
    this.ensure();
    if (key === 'profile') {
      return this.visibleTabs;
    }
    const exists: boolean = this.visibleTabs.indexOf(key) >= 0;
    if (exists) {
      // 关闭：计算移除后的列表
      if (this.visibleTabs.length - 1 <= 0) {
        return this.visibleTabs; // 拒绝，至少保留 1 个
      }
      const next: string[] = [];
      for (const t of this.visibleTabs) {
        if (t !== key) {
          next.push(t);
        }
      }
      this.visibleTabs = next;
    } else {
      // 开启：追加到末尾，保持顺序
      this.visibleTabs = this.visibleTabs.concat([key]);
    }
    if (this.visibleTabs.indexOf(this.defaultTab) < 0) {
      this.defaultTab = this.visibleTabs[0];
    }
    this.persistTabs();
    this.persistDefaultTab();
    this.version++;
    return this.visibleTabs;
  }

  // ---------------- 本地去重记录 ----------------

  isFeedIdSeen(id: string): boolean {
    if (id.length === 0) {
      return false;
    }
    this.ensure();
    for (const existing of this.dedupIds) {
      if (existing === id) {
        return true;
      }
    }
    return false;
  }

  markFeedIdsSeen(ids: string[]): void {
    this.ensure();
    for (const id of ids) {
      if (id.length === 0) {
        continue;
      }
      if (this.isFeedIdSeen(id)) {
        continue;
      }
      this.dedupIds.push(id);
    }
    if (this.dedupIds.length > DEDUP_ID_CAP) {
      this.dedupIds = this.dedupIds.slice(this.dedupIds.length - DEDUP_ID_CAP);
    }
    this.persistIds();
  }

  clearDedupRecords(): void {
    this.dedupIds = [];
    try {
      if (this.pref) {
        this.pref.putSync(KEY_DEDUP_IDS, '[]');
        this.pref.flushSync();
      }
    } catch (e) {
      // ignore
    }
  }
}

export const settingsStore = new SettingsStore();
