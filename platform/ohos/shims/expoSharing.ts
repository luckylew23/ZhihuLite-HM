// expo-sharing → OHOS 兼容垫片（委托给 react-native Share）
import { Share } from 'react-native';

export async function shareAsync(url: string, options?: any): Promise<void> {
  try {
    await Share.share(
      { url, message: options?.message ?? url, title: options?.title },
      options?.android ?? options?.iOS,
    );
  } catch (e) {
    console.warn('[OHOS] 分享失败', e);
  }
}

export async function isAvailableAsync(): Promise<boolean> {
  return true;
}

export default { shareAsync, isAvailableAsync };
