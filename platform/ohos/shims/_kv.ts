// _kv.ts — 共享 KV 存储（OHOS 垫片的基础设施）
// 优先使用 @react-native-ohos/async-storage（OpenHarmony RN 标准端口）；
// 若未安装则退化为内存存储（重启丢失，仅用于开发/降级）。
let _mem: Record<string, string> = {};
let _as:
  | { getItem: (k: string) => Promise<string | null>; setItem: (k: string, v: string) => Promise<void>; removeItem: (k: string) => Promise<void> }
  | null = null;
let _resolved = false;

function resolveAS() {
  if (_resolved) return _as;
  _resolved = true;
  try {
    const mod = require('@react-native-ohos/async-storage');
    _as = mod && (mod.default || mod);
  } catch {
    _as = null;
  }
  return _as;
}

export async function kvGet(key: string): Promise<string | null> {
  const as = resolveAS();
  if (as && typeof as.getItem === 'function') return (await as.getItem(key)) ?? null;
  return key in _mem ? _mem[key] : null;
}

export async function kvSet(key: string, value: string): Promise<void> {
  const as = resolveAS();
  if (as && typeof as.setItem === 'function') return as.setItem(key, value);
  _mem[key] = value;
}

export async function kvDel(key: string): Promise<void> {
  const as = resolveAS();
  if (as && typeof as.removeItem === 'function') return as.removeItem(key);
  delete _mem[key];
}
