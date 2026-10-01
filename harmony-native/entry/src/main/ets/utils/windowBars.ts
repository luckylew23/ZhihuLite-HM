/**
 * utils/windowBars —— 应用级窗口沉浸式（真·全屏）。
 * 1) setWindowLayoutFullScreen(true)：窗口布局延伸到状态栏/导航条，内容可绘制到系统栏区域；
 * 2) 状态栏 / 导航条背景透明，内容色随明暗主题切换；
 * 3) 导出系统栏高度（px），供页面顶部/底部组件做安全区 padding（px2vp 换算）。
 */

import { window } from '@kit.ArkUI';
import { settingsStore } from '../store/settingsStore';

let mainWin: window.Window | null = null;

/** 状态栏高度（px），0 = 未获取到。 */
export let statusBarHeight: number = 0;
/** 底部导航条高度（px）。 */
export let navBarHeight: number = 0;

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

/** 绑定主窗口：开启全屏、透明系统栏、记录安全区高度。 */
export function bindWindow(win: window.Window): void {
  mainWin = win;
  try {
    win.setWindowLayoutFullScreen(true);
  } catch (e) {
    // 忽略
  }
  try {
    const area = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
    statusBarHeight = area.topRect.height;
    navBarHeight = area.bottomRect.height;
  } catch (e) {
    // 忽略
  }
  applyWindowBars();
}

/** 主题切换后调用，刷新系统栏内容颜色。 */
export function applyWindowBars(): void {
  if (!mainWin) {
    return;
  }
  const dark: boolean = isDarkNow();
  try {
    mainWin.setWindowBackgroundColor(dark ? '#121212' : '#f6f6f6');
  } catch (e) {
    // 忽略
  }
  try {
    mainWin.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
      navigationBarContentColor: dark ? '#FFFFFFFF' : '#FF000000',
    } as window.SystemBarProperties);
  } catch (e) {
    // 忽略
  }
}
