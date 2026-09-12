// harmony/hvigorfile.ts
// ----------------------------------------------------------------------------
// 构建任务来自官方插件 @ohos/hvigor-ohos-plugin。
//
// ⚠️ 不要写成 `import { appTasks } from '@rnoh/react-native-openharmony'`：
//    RNOH 0.82 / 0.84 的 har 只导出 RN **运行时** API（RNApp / RNAbility / RNSurface …），
//    其自带的 hvigorfile.ts 也只是 `export { harTasks } from '@ohos/hvigor-ohos-plugin'`，
//    早已不再内置 appTasks / entryTasks 构建任务 —— 那样写必然报
//    "Cannot find module '@rnoh/react-native-openharmony'"。
//
// JS bundle 由 scripts/build-ohos-bundle.js（Metro，platform=harmony）单独产出到
// harmony/entry/src/main/resources/rawfile/bundle.harmony.js，
// ArkTS 侧 pages/index.ets 用 ResourceJSBundleProvider 直接加载该 rawfile，
// 因此本工程**不依赖** RNOH 的 hvigor 打包插件，也无需其 codegen（RNPackages 为空）。
// ----------------------------------------------------------------------------
import { appTasks } from '@ohos/hvigor-ohos-plugin';

export default {
  system: appTasks,
  plugins: [],
};
