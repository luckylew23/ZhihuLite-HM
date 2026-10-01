/**
 * utils/windowBars —— 应用级窗口沉浸式。
 * 把状态栏 / 导航条背景色设为页面根背景色（跟随主题），消除系统默认白色上下边；
 * 状态栏 / 导航条内容（时间、电量、手势条）颜色随明暗主题切换。
 */

import { window } from '@kit.ArkUI';
import { settingsStore } from '../store/settingsStore';

let mainWin: window.Window | null = null;

function isDarkNow(): boolean {
  const mode: string = settingsStore.getThemeMode();
  if (mode === 'dark') {
    return true;
  }
  if (mode === 'light') {
    return false;
  }
  return settingsStore.isSystemDark();
}

/** 绑定主窗口并立即应用系统栏颜色。 */
export function bindWindow(win: window.Window): void {
  mainWin = win;
  applyWindowBars();
}

/** 主题切换后调用，刷新系统栏颜色。 */
export function applyWindowBars(): void {
  if (!mainWin) {
    return;
  }
  const dark: boolean = isDarkNow();
  const bg: string = dark ? '#FF121212' : '#FFF6F6F6';
  try {
    mainWin.setWindowSystemBarProperties({
      statusBarColor: bg,
      navigationBarColor: bg,
      statusBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
      navigationBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
    } as window.SystemBarProperties);
  } catch (e) {
    // 忽略：窗口系统栏设置失败不影响功能
  }
}
