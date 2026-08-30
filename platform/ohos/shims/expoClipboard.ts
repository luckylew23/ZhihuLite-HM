// expo-clipboard → OHOS 兼容垫片
// OHOS 上真实系统剪贴板需接入 @react-native-ohos/clipboard；
// 此处先以应用内 KV 兜底，保证 copyToClipboard / 剪贴板监听等逻辑不崩溃。
import { kvGet, kvSet } from './_kv';

const LAST_KEY = 'clipboard:last';

export async function setStringAsync(text: string, _options?: any): Promise<boolean> {
  try {
    const Clipboard = require('@react-native-ohos/clipboard');
    if (Clipboard && typeof Clipboard.setString === 'function') {
      await Clipboard.setString(text);
      return true;
    }
  } catch {
    // 未安装原生剪贴板时走 KV 兜底
  }
  await kvSet(LAST_KEY, text);
  return true;
}

export async function getStringAsync(): Promise<string | null> {
  try {
    const Clipboard = require('@react-native-ohos/clipboard');
    if (Clipboard && typeof Clipboard.getString === 'function') {
      return await Clipboard.getString();
    }
  } catch {
    /* ignore */
  }
  return kvGet(LAST_KEY);
}

export async function hasStringAsync(): Promise<boolean> {
  return !!(await getStringAsync());
}

export const getString = getStringAsync;
export const setString = setStringAsync;

export default { setStringAsync, getStringAsync, hasStringAsync, getString, setString };
