// expo-file-system → OHOS 兼容垫片
// 以 KV 模拟文件读写（documentDirectory / cacheDirectory 等）。
// 说明：downloadAsync 在 OHOS 上仅做 best-effort（文本下载），
// 真正的图片落盘保存依赖 @react-native-ohos/... 媒体模块，见 EXPO_OHOS_MAPPING.md。
import { kvGet, kvSet, kvDel } from './_kv';

export const documentDirectory = 'ohosdocument://';
export const cacheDirectory = 'ohoscache://';
export const bundleDirectory = '';

export const Paths = {
  document: { uri: documentDirectory },
  cache: { uri: cacheDirectory },
  data: { uri: documentDirectory },
  library: { uri: documentDirectory },
  temporary: { uri: cacheDirectory },
};

function keyOf(uri: string): string {
  return `fs:${uri}`;
}

export const File = {
  async readAsStringAsync(uri: string): Promise<string> {
    return (await kvGet(keyOf(uri))) ?? '';
  },
  async writeAsStringAsync(uri: string, content: string): Promise<void> {
    await kvSet(keyOf(uri), content);
  },
  async deleteAsync(uri: string): Promise<void> {
    await kvDel(keyOf(uri));
  },
  async getInfoAsync(uri: string) {
    const raw = await kvGet(keyOf(uri));
    return {
      exists: raw !== null,
      uri,
      isDirectory: false,
      size: raw ? raw.length : 0,
      modificationTime: 0,
    };
  },
};

export async function getInfoAsync(uri: string, _options?: any) {
  return File.getInfoAsync(uri);
}
export async function readAsStringAsync(uri: string, _options?: any) {
  return File.readAsStringAsync(uri);
}
export async function writeAsStringAsync(uri: string, content: string, _options?: any) {
  return File.writeAsStringAsync(uri, content);
}
export async function deleteAsync(uri: string, _options?: any) {
  return File.deleteAsync(uri);
}
export async function makeDirectoryAsync(_uri: string, _options?: any): Promise<void> {}
export async function moveAsync(_options: { from: string; to: string }): Promise<void> {}
export async function copyAsync(_options: { from: string; to: string }): Promise<void> {}
export async function downloadAsync(url: string, uri: string, _options?: any) {
  try {
    const res = await fetch(url);
    const text = await res.text();
    await kvSet(keyOf(uri), text);
  } catch (e) {
    console.warn('[OHOS fs] downloadAsync 降级：无法下载', url, e);
  }
  return { uri };
}
export async function uploadAsync(_url: string, _uri: string, _options?: any) {
  return { body: '', status: 0, headers: {} };
}

export const EncodingType = { UTF8: 'utf8', Base64: 'base64' };
export const FileSystemSessionType = { BACKGROUND: 'background', FOREGROUND: 'foreground' };
export const FileSystemUploadType = { BINARY_CONTENT: 'binary', MULTIPART: 'multipart' };

export default {
  documentDirectory,
  cacheDirectory,
  bundleDirectory,
  Paths,
  File,
  getInfoAsync,
  readAsStringAsync,
  writeAsStringAsync,
  deleteAsync,
  makeDirectoryAsync,
  moveAsync,
  copyAsync,
  downloadAsync,
  uploadAsync,
  EncodingType,
  FileSystemSessionType,
  FileSystemUploadType,
};
