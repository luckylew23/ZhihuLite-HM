/**
 * expo-secure-store 的 Web 垫片
 * ---------------------------------------------------------------------------
 * 背景：Web 平台下 expo-secure-store 没有原生实现，
 * 运行时会抛 `ExpoSecureStore.default.setValueWithKeyAsync is not a function`，
 * 在 SSG 阶段直接让 expo export 崩溃（主题 store 水合时写值触发）。
 *
 * 策略：退化为 localStorage（HAP 为本地离线单文件应用，无跨应用攻击面，
 * 安全性可接受）；Node/SSG 环境退化为进程内 Map。
 * ---------------------------------------------------------------------------
 */

const PREFIX = 'hmos-secure:';

const memory = new Map<string, string>();

function rawGet(key: string): string | null {
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.getItem === 'function') {
      return ls.getItem(PREFIX + key);
    }
  } catch {
    /* 忽略 */
  }
  return memory.has(key) ? (memory.get(key) as string) : null;
}

function rawSet(key: string, value: string): void {
  memory.set(key, value);
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.setItem === 'function') {
      ls.setItem(PREFIX + key, value);
    }
  } catch {
    /* 忽略：配额超限 */
  }
}

function rawDelete(key: string): void {
  memory.delete(key);
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.removeItem === 'function') {
      ls.removeItem(PREFIX + key);
    }
  } catch {
    /* 忽略 */
  }
}

export async function isAvailableAsync(): Promise<boolean> {
  return true;
}

export async function getItemAsync(key: string): Promise<string | null> {
  return rawGet(String(key));
}

export async function setItemAsync(
  key: string,
  value: string,
  _options?: Record<string, unknown>,
): Promise<void> {
  rawSet(String(key), String(value));
}

export async function deleteItemAsync(
  key: string,
  _options?: Record<string, unknown>,
): Promise<void> {
  rawDelete(String(key));
}

/** expo-secure-store 的选项常量（保持 API 形状一致，Web 下无实际作用） */
export const WHEN_UNLOCKED = 'whenUnlocked';
export const AFTER_FIRST_UNLOCK = 'afterFirstUnlock';
export const ALWAYS = 'always';
export const WHEN_PASSCODE_SET_THIS_DEVICE_ONLY = 'whenPasscodeSetThisDeviceOnly';
export const WHEN_UNLOCKED_THIS_DEVICE_ONLY = 'whenUnlockedThisDeviceOnly';
export const AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY =
  'afterFirstUnlockThisDeviceOnly';
export const ALWAYS_THIS_DEVICE_ONLY = 'alwaysThisDeviceOnly';

const SecureStoreShim = {
  isAvailableAsync,
  getItemAsync,
  setItemAsync,
  deleteItemAsync,
  WHEN_UNLOCKED,
  AFTER_FIRST_UNLOCK,
  ALWAYS,
  WHEN_PASSCODE_SET_THIS_DEVICE_ONLY,
  WHEN_UNLOCKED_THIS_DEVICE_ONLY,
  AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
  ALWAYS_THIS_DEVICE_ONLY,
};

export default SecureStoreShim;
