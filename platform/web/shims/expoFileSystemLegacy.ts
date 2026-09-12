/**
 * expo-file-system/legacy 的 Web 垫片
 * ---------------------------------------------------------------------------
 * 背景：SSG（Node 端静态渲染）阶段 `expo-file-system/legacy` 的 getInfoAsync
 * 在 Web 平台直接抛 UnavailabilityError，导致 zustand persist 水合失败、
 * expo export 崩溃。ArkWeb（resource://rawfile）里也没有真实文件系统。
 *
 * 策略：
 *   - 有 localStorage 时用它持久化（HAP 内跨刷新生效）
 *   - 没有 localStorage（Node/SSG）时退化为进程内 Map，保证不抛错
 *   - 所有 API 都返回与原生一致的数据结构，业务侧无感
 * ---------------------------------------------------------------------------
 */

const PREFIX = 'hmos-fs:';

const memory = new Map<string, string>();

function rawGet(key: string): string | null {
  try {
    const ls = (globalThis as any)?.localStorage;
    if (ls && typeof ls.getItem === 'function') {
      return ls.getItem(PREFIX + key);
    }
  } catch {
    /* 忽略：隐私模式 / 无 localStorage */
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
    /* 忽略：配额超限等 */
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

export const documentDirectory = 'hmos-fs://documents/';
export const cacheDirectory = 'hmos-fs://caches/';
export const bundleDirectory = 'hmos-fs://bundle/';

export const EncodingType = {
  UTF8: 'utf8',
  Base64: 'base64',
} as const;

export interface FileInfo {
  exists: boolean;
  uri: string;
  size?: number;
  isDirectory?: boolean;
  modificationTime?: number;
  md5?: string;
}

export async function getInfoAsync(
  uri: string,
  _options?: { md5?: boolean; size?: boolean },
): Promise<FileInfo> {
  const value = rawGet(String(uri));
  if (value == null) {
    return { exists: false, uri: String(uri), isDirectory: false };
  }
  return {
    exists: true,
    uri: String(uri),
    size: value.length,
    isDirectory: false,
    modificationTime: Date.now(),
  };
}

export async function readAsStringAsync(
  uri: string,
  _options?: { encoding?: 'utf8' | 'base64'; length?: number; position?: number },
): Promise<string> {
  const value = rawGet(String(uri));
  if (value == null) {
    throw new Error(`[expo-file-system/web] 文件不存在: ${uri}`);
  }
  return value;
}

export async function writeAsStringAsync(
  uri: string,
  contents: string,
  _options?: { encoding?: 'utf8' | 'base64' },
): Promise<void> {
  rawSet(String(uri), String(contents));
}

export async function deleteAsync(
  uri: string,
  _options?: { idempotent?: boolean },
): Promise<void> {
  if (rawGet(String(uri)) == null && _options?.idempotent === false) {
    throw new Error(`[expo-file-system/web] 文件不存在: ${uri}`);
  }
  rawDelete(String(uri));
}

export async function makeDirectoryAsync(
  _uri: string,
  _options?: { intermediates?: boolean },
): Promise<void> {
  // 虚拟文件系统，目录无需真实创建
}

export async function readDirectoryAsync(_uri: string): Promise<string[]> {
  return [];
}

export async function copyAsync(_options: {
  from: string;
  to: string;
}): Promise<void> {
  const value = rawGet(String(_options?.from));
  if (value != null) rawSet(String(_options?.to), value);
}

export async function moveAsync(_options: {
  from: string;
  to: string;
}): Promise<void> {
  const value = rawGet(String(_options?.from));
  if (value != null) {
    rawSet(String(_options?.to), value);
    rawDelete(String(_options?.from));
  }
}

export async function getFreeDiskStorageAsync(): Promise<number> {
  return Number.MAX_SAFE_INTEGER;
}

export async function getTotalDiskCapacityAsync(): Promise<number> {
  return Number.MAX_SAFE_INTEGER;
}

const FileSystemShim = {
  documentDirectory,
  cacheDirectory,
  bundleDirectory,
  EncodingType,
  getInfoAsync,
  readAsStringAsync,
  writeAsStringAsync,
  deleteAsync,
  makeDirectoryAsync,
  readDirectoryAsync,
  copyAsync,
  moveAsync,
  getFreeDiskStorageAsync,
  getTotalDiskCapacityAsync,
};

export default FileSystemShim;
