// EntryAbility —— React Native OpenHarmony 入口
// 说明：此文件为 RN OHOS 模板约定结构。若与本地 @rnoh/react-native-openharmony
// 版本签名不符，请运行 `npx @react-native-ohos/cli init` 重新生成 harmony/ 目录，
// 再把本文件中的 appKey / 路由相关自定义合并回来。
import { RNAbility, PackageContext } from '@rnoh/react-native-openharmony';
import { RNPackages } from './RNPackages';

export default class EntryAbility extends RNAbility {
  /**
   * RNAbility 把它声明为 `protected abstract getPagePath(): string`，
   * 子类必须实现，否则 ArkTS 编译直接失败。
   * 该页面即承载 RNApp（RN 根组件）的 ArkUI 页面，对应
   * entry/src/main/ets/pages/index.ets 与 main_pages.json 中的 "pages/index"。
   */
  protected getPagePath(): string {
    return 'pages/index';
  }

  // 注册自定义 TurboModule / Fabric 组件包（如有）。
  getRNPackages(ctx: PackageContext): any[] {
    return RNPackages(ctx);
  }
}
