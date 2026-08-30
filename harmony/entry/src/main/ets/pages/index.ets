// pages/index.ets —— RN OHOS 渲染宿主页面
// ----------------------------------------------------------------------------
// 组件名是 **RNApp**（不是 RNOHApp —— RNOH 包里没有 RNOHApp 这个导出）。
// RNApp 有两个 @Require 参数：
//   - rnInstanceConfig : 托管模式需提供 createRNPackages(ctx) => RNPackage[]
//   - appKey           : 必须与 ohos/index.tsx 中 AppRegistry.registerComponent 的名称一致
// jsBundleProvider 虽非 @Require，但**不传就不会加载任何 bundle**（RNApp 文档明确说明），
// 因此这里显式构造 ResourceJSBundleProvider 指向 rawfile/bundle.harmony.js。
// ----------------------------------------------------------------------------
import {
  RNApp,
  RNOHCoreContext,
  ResourceJSBundleProvider,
  RNPackageContext,
  RNPackage,
} from '@rnoh/react-native-openharmony';
import { RNPackages } from '../RNPackages';

const BUNDLE_NAME = 'bundle.harmony.js';

@Entry
@Component
struct Index {
  // RNAbility 会把 RNOHCoreContext 放入 AppStorage，页面通过它拿到 resourceManager
  @StorageLink('RNOHCoreContext') private rnohCoreContext: RNOHCoreContext | undefined = undefined;

  build() {
    Column() {
      if (this.rnohCoreContext) {
        RNApp({
          rnInstanceConfig: {
            name: 'zhihu--',
            createRNPackages: (ctx: RNPackageContext): RNPackage[] => RNPackages(ctx),
            enableDebugger: false,
          },
          appKey: 'zhihu--',
          jsBundleProvider: new ResourceJSBundleProvider(
            this.rnohCoreContext!.uiAbilityContext.resourceManager,
            BUNDLE_NAME,
          ),
        })
      }
    }
    .height('100%')
    .width('100%')
  }
}
