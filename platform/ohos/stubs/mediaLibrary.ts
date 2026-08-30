// @react-native-ohos/media-library 的降级 stub
// 仅当真实 OHOS 原生包未安装时回退使用（见 metro.config.js 的 resolveRequest）。
// 相册保存需要系统能力，stub 一律返回未授权，上层会自然降级为「系统分享」。
export async function requestPermissions(): Promise<{ status: string; granted: boolean }> {
  return { status: 'denied', granted: false };
}

export async function saveToLibrary(_uri: string): Promise<void> {
  throw new Error('[OHOS] 未安装 @react-native-ohos/media-library，无法保存到相册');
}

export async function getAssets(): Promise<any[]> {
  return [];
}

const MediaLibrary = { requestPermissions, saveToLibrary, getAssets };
export default MediaLibrary;
