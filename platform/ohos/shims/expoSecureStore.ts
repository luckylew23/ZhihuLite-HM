// expo-secure-store → OHOS 兼容垫片
// expo-secure-store 在本项目中用于持久化登录 Cookie 等小数据。
// OHOS 下退化为通用 KV 存储（见 _kv.ts）。如需真·加密存储，可替换为
// @react-native-ohos/async-storage 的加密封装或系统 Preferences。
import { kvGet, kvSet, kvDel } from './_kv';

export async function getItemAsync(
  key: string,
  _options?: { requireAuthentication?: boolean; authenticationPrompt?: string },
): Promise<string | null> {
  return kvGet(`secure:${key}`);
}

export async function setItemAsync(
  key: string,
  value: string,
  _options?: { requireAuthentication?: boolean; authenticationPrompt?: string; keychainService?: string },
): Promise<void> {
  await kvSet(`secure:${key}`, value);
}

export async function deleteItemAsync(
  key: string,
  _options?: { keychainService?: string },
): Promise<void> {
  await kvDel(`secure:${key}`);
}

export async function isAvailableAsync(): Promise<boolean> {
  return true;
}

export const WHEN_UNLOCKED = 'after_first_unlock';
export const AFTER_FIRST_UNLOCK = 'after_first_unlock';
export const ALWAYS = 'always';
