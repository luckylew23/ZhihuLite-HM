// platform/index.ts
// 运行时判断当前是否处于 HarmonyOS (OHOS) 构建。
// 业务代码可选择性地根据 isOHOS 做差异化处理，但绝大多数逻辑应无需分支。
import { Platform } from 'react-native';

// 注意：Expo/RN 的 PlatformOSType 不含 'ohos'（OHOS 构建下由 @react-native-ohos/react-native 注入），
// 因此先 as string 再比较，避免 Android/iOS 构建时触发 TS2367。
export const isOHOS = (Platform.OS as string) === 'ohos';
export const isHarmonyOS = isOHOS;

export type PlatformName = 'ios' | 'android' | 'web' | 'ohos' | 'windows' | 'macos';

export function platformName(): PlatformName {
  return ((Platform.OS as string) ?? 'ohos') as PlatformName;
}

export { isOHOS as default };
