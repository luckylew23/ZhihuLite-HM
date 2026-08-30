// RNPackages —— 注册自定义 RN OHOS 包（TurboModule / Fabric 组件）。
// 当前项目沿用 expo-router 兼容垫片（platform/ohos/shims/expoRouter），
// 若后续接入原生能力，在此追加对应 Package 即可。
import type { RNPackage } from '@rnoh/react-native-openharmony';
import type { PackageContext } from '@rnoh/react-native-openharmony';

export function RNPackages(ctx: PackageContext): RNPackage[] {
  // 返回已启用的自定义 RN 包列表
  return [];
}
