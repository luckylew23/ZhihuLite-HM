// @react-native-ohos/clipboard 的降级 stub
// 仅当真实 OHOS 原生包未安装时回退使用（见 metro.config.js 的 resolveRequest）。
// 内存实现：仅保证同一进程内的复制/读取可用，不写入系统剪贴板。
let content: string = '';

export function setString(text: string): void {
  content = text;
}

export async function getString(): Promise<string> {
  return content;
}

export function hasString(): boolean {
  return content.length > 0;
}

export function addListener(_cb: (c: string) => void) {
  return { remove: () => {} };
}

const Clipboard = { setString, getString, hasString, addListener };
export default Clipboard;
