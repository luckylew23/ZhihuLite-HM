/**
 * 原生版主题色 —— 取自上游 constants/designTokens.json 的 light / dark 调色板。
 *
 * 兼容策略：现有页面一律 `import { ZhihuColors } from '../utils/theme'` 并按属性读取，
 * 因此这里保持导出名与全部键名不变；`ZhihuColors` 是一个可就地变异的对象，
 * applyTheme() 按当前主题模式把对应调色板逐字段拷进去。已有页面无需改动即可编译，
 * 读取时（build/render 阶段）自然拿到当前模式的颜色。
 */

import { settingsStore, ThemeMode } from '../store/settingsStore';

export interface ZhihuColorPalette {
  primary: string;
  danger: string;
  success: string;
  warning: string;
  text: string;
  textSecondary: string;
  textTertiary: string;
  textInverse: string;
  background: string;
  backgroundSecondary: string;
  backgroundTertiary: string;
  surface: string;
  border: string;
  divider: string;
  tint: string;
  tabIconDefault: string;
  tabIconSelected: string;
  iconMuted: string;
  hotRankFirst: string;
  hotRankSecond: string;
  hotRankThird: string;
  hotLabel: string;
  primaryTransparent: string;
}

const LIGHT_PALETTE: ZhihuColorPalette = {
  primary: '#0084ff',
  danger: '#ff4d4f',
  success: '#2ecc71',
  warning: '#ff9800',
  text: '#1a1a1a',
  textSecondary: '#666666',
  textTertiary: '#999999',
  textInverse: '#ffffff',
  background: '#f6f6f6',
  backgroundSecondary: '#ffffff',
  backgroundTertiary: '#f3f3f3',
  surface: '#ffffff',
  border: '#eeeeee',
  divider: 'rgba(0,0,0,0.05)',
  tint: '#0084ff',
  tabIconDefault: '#cccccc',
  tabIconSelected: '#0084ff',
  iconMuted: '#888888',
  hotRankFirst: '#e73828',
  hotRankSecond: '#f65324',
  hotRankThird: '#ff8b1f',
  hotLabel: '#ff9607',
  primaryTransparent: 'rgba(0, 132, 255, 0.1)',
};

const DARK_PALETTE: ZhihuColorPalette = {
  primary: '#0084ff',
  danger: '#ff4d4f',
  success: '#2ecc71',
  warning: '#ffcf40',
  text: '#ffffff',
  textSecondary: '#bbbbbb',
  textTertiary: '#cccccc',
  textInverse: '#1a1a1a',
  background: '#121212',
  backgroundSecondary: '#1e1e22',
  backgroundTertiary: '#2c2c30',
  surface: '#1e1e22',
  border: '#333333',
  divider: 'rgba(255,255,255,0.1)',
  tint: '#0084ff',
  tabIconDefault: '#cccccc',
  tabIconSelected: '#ffffff',
  iconMuted: '#888888',
  hotRankFirst: '#e73828',
  hotRankSecond: '#f65324',
  hotRankThird: '#ff8b1f',
  hotLabel: '#ff9607',
  primaryTransparent: 'rgba(0, 132, 255, 0.15)',
};

/** 当前生效调色板（与 light 默认值一致，applyTheme 后可能变为 dark）。 */
export const ZhihuColors: ZhihuColorPalette = {
  primary: '#0084ff',
  danger: '#ff4d4f',
  success: '#2ecc71',
  warning: '#ff9800',
  text: '#1a1a1a',
  textSecondary: '#666666',
  textTertiary: '#999999',
  textInverse: '#ffffff',
  background: '#f6f6f6',
  backgroundSecondary: '#ffffff',
  backgroundTertiary: '#f3f3f3',
  surface: '#ffffff',
  border: '#eeeeee',
  divider: 'rgba(0,0,0,0.05)',
  tint: '#0084ff',
  tabIconDefault: '#cccccc',
  tabIconSelected: '#0084ff',
  iconMuted: '#888888',
  hotRankFirst: '#e73828',
  hotRankSecond: '#f65324',
  hotRankThird: '#ff8b1f',
  hotLabel: '#ff9607',
  primaryTransparent: 'rgba(0, 132, 255, 0.1)',
};

/** 当前是否为深色（运行时计算，auto 跟随系统）。 */
export function isDarkNow(): boolean {
  const mode: ThemeMode = settingsStore.getThemeMode();
  if (mode === 'dark') {
    return true;
  }
  if (mode === 'light') {
    return false;
  }
  return settingsStore.isSystemDark();
}

/** 返回当前生效的调色板（纯函数，便于在 build 中取色）。 */
export function theme(): ZhihuColorPalette {
  return isDarkNow() ? DARK_PALETTE : LIGHT_PALETTE;
}

/** 按当前模式把颜色就地写入 ZhihuColors（保持引用不变）。 */
export function applyTheme(): void {
  const p: ZhihuColorPalette = isDarkNow() ? DARK_PALETTE : LIGHT_PALETTE;
  ZhihuColors.primary = p.primary;
  ZhihuColors.danger = p.danger;
  ZhihuColors.success = p.success;
  ZhihuColors.warning = p.warning;
  ZhihuColors.text = p.text;
  ZhihuColors.textSecondary = p.textSecondary;
  ZhihuColors.textTertiary = p.textTertiary;
  ZhihuColors.textInverse = p.textInverse;
  ZhihuColors.background = p.background;
  ZhihuColors.backgroundSecondary = p.backgroundSecondary;
  ZhihuColors.backgroundTertiary = p.backgroundTertiary;
  ZhihuColors.surface = p.surface;
  ZhihuColors.border = p.border;
  ZhihuColors.divider = p.divider;
  ZhihuColors.tint = p.tint;
  ZhihuColors.tabIconDefault = p.tabIconDefault;
  ZhihuColors.tabIconSelected = p.tabIconSelected;
  ZhihuColors.iconMuted = p.iconMuted;
  ZhihuColors.hotRankFirst = p.hotRankFirst;
  ZhihuColors.hotRankSecond = p.hotRankSecond;
  ZhihuColors.hotRankThird = p.hotRankThird;
  ZhihuColors.hotLabel = p.hotLabel;
  ZhihuColors.primaryTransparent = p.primaryTransparent;
}

/** 设置主题模式并立即应用。 */
export function applyThemeMode(mode: ThemeMode): void {
  settingsStore.setThemeMode(mode);
  applyTheme();
}

// 模块加载即按已持久化模式应用一次（此时 settingsStore 可能尚未 init，回退 light）。
applyTheme();
