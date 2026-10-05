/**
 * EntryAbility —— 原生版入口。
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { setAppContext } from '../store/authStore';
import { bindWindow } from '../utils/windowBars';
import { setPendingDeepLink } from '../utils/deepLink';

const DOMAIN: number = 0x0000;
const TAG: string = 'ZhihuNativeEntry';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 注入 Context：authStore（preferences 持久化）需要
    setAppContext(this.context);
    this.captureDeepLink(want);
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    // 应用已运行：系统再次拉起知乎链接时接管
    this.captureDeepLink(want);
    hilog.info(DOMAIN, TAG, 'Ability onNewWant');
  }

  private captureDeepLink(want: Want): void {
    if (!want) {
      return;
    }
    if (want.uri && (want.uri as string).length > 0) {
      setPendingDeepLink(want.uri as string);
      return;
    }
    // 分享文本：提取第一个 http(s) 链接
    const params: Record<string, Object> = want.parameters as Record<string, Object>;
    if (!params) {
      return;
    }
    const raw: Object | undefined = params['text'];
    if (raw === undefined) {
      return;
    }
    const text: string = raw as string;
    const m: RegExpExecArray | null = /https?:\/\/[^\s]+/i.exec(text);
    if (m !== null) {
      setPendingDeepLink(m[0]);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    try {
      bindWindow(windowStage.getMainWindowSync());
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'bind window failed');
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}
