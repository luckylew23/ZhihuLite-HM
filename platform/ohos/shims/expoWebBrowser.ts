// expo-web-browser → OHOS 兼容垫片（委托给系统 Linking 打开）
import { Linking } from 'react-native';

export async function openBrowserAsync(url: string): Promise<{ type: 'opened' | 'cancel' | 'locked' }> {
  try {
    await Linking.openURL(url);
  } catch (e) {
    console.warn('[OHOS] 打开浏览器失败', url, e);
  }
  return { type: 'opened' };
}

export async function openAuthSessionAsync(
  url: string,
  _redirectUrl?: string,
): Promise<{ type: 'opened' | 'cancel' | 'dismiss' | 'locked'; url?: string }> {
  try {
    await Linking.openURL(url);
  } catch (e) {
    console.warn('[OHOS] 打开授权会话失败', url, e);
  }
  return { type: 'opened', url };
}

export function dismissBrowser(): void {}
export function maybeCompleteAuthSession(): void {}
export const dismissAuthSession = dismissBrowser;

export default {
  openBrowserAsync,
  openAuthSessionAsync,
  dismissBrowser,
  maybeCompleteAuthSession,
  dismissAuthSession,
};
