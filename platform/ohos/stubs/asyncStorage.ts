// @react-native-ohos/async-storage 的降级 stub
// 仅当真实 OHOS 原生包未安装时，由 metro.config.js 的 resolveRequest 回退到此文件，
// 以保证打包不中断。安装真实包后本文件不会被使用。
// ⚠️ 内存实现：应用重启后数据丢失。持久化依赖真实的 @react-native-ohos/async-storage。
const store: Record<string, string> = {};

let warned = false;
function warnOnce() {
  if (warned) return;
  warned = true;
  console.warn(
    '[OHOS] @react-native-ohos/async-storage 未安装，已回退到内存 stub（重启丢失）。' +
      '请按 package.ohos.json 安装以获得持久化。',
  );
}

export async function getItem(key: string): Promise<string | null> {
  warnOnce();
  return key in store ? store[key] : null;
}

export async function setItem(key: string, value: string): Promise<void> {
  warnOnce();
  store[key] = value;
}

export async function removeItem(key: string): Promise<void> {
  warnOnce();
  delete store[key];
}

export async function mergeItem(key: string, value: string): Promise<void> {
  warnOnce();
  const prev = store[key];
  store[key] = prev ? JSON.stringify({ ...JSON.parse(prev), ...JSON.parse(value) }) : value;
}

export async function clear(): Promise<void> {
  warnOnce();
  for (const k of Object.keys(store)) delete store[k];
}

const AsyncStorage = { getItem, setItem, removeItem, mergeItem, clear };
export default AsyncStorage;
