// expo-media-library → OHOS 兼容垫片
// OHOS 真机保存图片到相册需接入 @react-native-ohos/media-library 或系统 Ability。
// 此处 requestPermissionsAsync 返回未授权，使 utils/saveImage.ts 自然降级为「系统分享」，
// 保证不崩溃。接入原生保存能力后，可在此实现 saveToLibraryAsync。
export enum PermissionStatus {
  GRANTED = 'granted',
  DENIED = 'denied',
  UNDETERMINED = 'undetermined',
}

export async function getPermissionsAsync(): Promise<{ status: PermissionStatus; granted: boolean }> {
  return { status: PermissionStatus.UNDETERMINED, granted: false };
}

export async function requestPermissionsAsync(): Promise<{ status: PermissionStatus; granted: boolean }> {
  // 未接入原生相册权限，返回未授权以触发上层「系统分享」降级路径。
  return { status: PermissionStatus.UNDETERMINED, granted: false };
}

export async function saveToLibraryAsync(_localUri: string): Promise<void> {
  throw new Error('[OHOS] 未接入原生相册保存，请使用系统分享另存（详见 EXPO_OHOS_MAPPING.md）');
}

export async function createAssetAsync(_localUri: string): Promise<any> {
  await saveToLibraryAsync(_localUri);
}

export default {
  PermissionStatus,
  getPermissionsAsync,
  requestPermissionsAsync,
  saveToLibraryAsync,
  createAssetAsync,
};
