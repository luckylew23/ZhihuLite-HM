// EntryAbility —— 纯 UIAbility（WebView 壳方案，不依赖 RNOH）
//
// 方案说明：本工程不再做 React Native 原生移植（RNOH）。RNOH 的 har 内含
// boost / folly / glog / libevent / fast_float 的完整 C++ 源码且 libs/ 为空（无预编译 .so），
// assembleHap 会触发一次完整的 CMake 原生构建（数十分钟级）。
// 改为与 Tydora-HMOS 同一条路线：
//   Expo Web 静态产物 → 内联为单文件 index.html → 放进 rawfile → ArkWeb 加载。
// 这样 assembleHap 只做 ArkTS 编译与打包，**秒级完成**。
import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN: number = 0x0000;
const TAG: string = 'ZhihuEntry';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/index', (err) => {
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
