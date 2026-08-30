// expo-linking → OHOS 兼容垫片（委托给 react-native Linking）
import { Linking as RNNLinking } from 'react-native';

export function createURL(path: string, queryParams?: Record<string, any>): string {
  const base = 'zhihu--://';
  const q = queryParams
    ? '?' +
      Object.entries(queryParams)
        .map(([k, v]) => `${k}=${encodeURIComponent(String(v))}`)
        .join('&')
    : '';
  return `${base}${path}${q}`;
}

export function parse(url: string) {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return { scheme: '', path: url, queryParams: {}, hostname: '' };
  }
  const queryParams: Record<string, string> = {};
  u.searchParams.forEach((v, k) => (queryParams[k] = v));
  return {
    scheme: u.protocol.replace(':', ''),
    path: u.pathname,
    queryParams,
    hostname: u.hostname,
  };
}

export function addEventListener(type: string, handler: (e: any) => void) {
  if (type === 'url') {
    const sub = RNNLinking.addEventListener('url', (e) => handler({ url: e.url }));
    return { remove: () => sub.remove() };
  }
  return { remove: () => {} };
}

export async function getInitialURL(): Promise<string | null> {
  return RNNLinking.getInitialURL();
}

export async function openURL(url: string): Promise<void> {
  return RNNLinking.openURL(url);
}

export async function canOpenURL(url: string): Promise<boolean> {
  return RNNLinking.canOpenURL(url);
}

export async function sendIntent(action: string, extras?: any): Promise<void> {
  console.warn('[OHOS] expo-linking sendIntent 暂不支持');
}

export const Linking = RNNLinking;
export default {
  createURL,
  parse,
  addEventListener,
  getInitialURL,
  openURL,
  canOpenURL,
  sendIntent,
  Linking,
};
