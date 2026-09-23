/**
 * 本地文件缓存 —— 热榜 / 日报离线缓存（进入即缓存，两天内离线可看）。
 * - 存储位置：{filesDir}/zhihu_cache/<key>.json（应用沙箱，卸载即清）
 * - 写入：cacheWrite(key, payload) 同步写 JSON
 * - 读取：cacheRead(key, maxAgeMs) 同步读 + 文件年龄校验，超龄返回 null
 * 缓存失败静默忽略，不影响主流程。
 */

import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

let appContext: common.Context | null = null;
let dirReady: boolean = false;

export function initCacheStore(ctx: common.Context): void {
  appContext = ctx;
  try {
    const dir: string = ctx.filesDir + '/zhihu_cache';
    // 目录已存在时 mkdirSync(recursive) 仍可能抛 File exists，先探活
    let exists: boolean = false;
    try {
      exists = fs.accessSync(dir);
    } catch (e) {
      exists = false;
    }
    if (!exists) {
      fs.mkdirSync(dir, true);
    }
    dirReady = true;
    console.error('[ZhihuLite] cache init ok dir=' + dir);
  } catch (e) {
    dirReady = false;
    console.error('[ZhihuLite] cache init fail err=' + String(e));
  }
}

function cachePath(key: string): string {
  const safe: string = key.replace(/[^a-zA-Z0-9_]/g, '_');
  return appContext !== null ? appContext.filesDir + '/zhihu_cache/' + safe + '.json' : '';
}

/** 写入缓存（key 仅限字母数字下划线） */
export function cacheWrite(key: string, payload: object): void {
  if (!dirReady || appContext === null) {
    return;
  }
  try {
    const p: string = cachePath(key);
    if (p.length === 0) {
      return;
    }
    const f = fs.openSync(p, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(f.fd, JSON.stringify(payload));
    fs.closeSync(f);
  } catch (e) {
    console.error('[ZhihuLite] cacheWrite fail key=' + key + ' err=' + String(e));
  }
}

/** 读取缓存；超过 maxAgeMs 视为过期返回 null */
export function cacheRead<T>(key: string, maxAgeMs: number): T | null {
  if (!dirReady || appContext === null) {
    return null;
  }
  try {
    const p: string = cachePath(key);
    if (p.length === 0) {
      return null;
    }
    const stat = fs.statSync(p);
    const now: number = Date.now();
    // fileIo stat.mtime 单位为秒，Date.now() 为毫秒，换算后再比较
    const mtimeMs: number = stat.mtime * 1000;
    if (stat.size <= 0 || (now - mtimeMs) > maxAgeMs) {
      console.error('[ZhihuLite] cacheRead stale key=' + key + ' ageS=' +
        String((now - mtimeMs) / 1000));
      return null;
    }
    const text: string = fs.readTextSync(p);
    return JSON.parse(text) as T;
  } catch (e) {
    return null;
  }
}

/** 两天毫秒数（热榜/日报离线缓存有效期） */
export const CACHE_TWO_DAYS_MS: number = 2 * 24 * 60 * 60 * 1000;

/** 热榜缓存结构 */
export interface HotCachePayload {
  savedAt: number;
  items: object[];
}

/** 日报缓存结构 */
export interface DailyCachePayload {
  savedAt: number;
  date: string;
  stories: object[];
  top_stories?: object[];
}

/** 内容缓存 key 生成 */
export function contentCacheKey(type: string, id: string | number): string {
  return 'content_' + type + '_' + String(id);
}

/** 读取内容缓存 */
export function readContentCache<T>(type: string, id: string | number): T | null {
  return cacheRead<T>(contentCacheKey(type, id), CACHE_TWO_DAYS_MS);
}

/** 写入内容缓存 */
export function writeContentCache(type: string, id: string | number, data: object): void {
  cacheWrite(contentCacheKey(type, id), {
    savedAt: Date.now(),
    type: type,
    id: String(id),
    data: data,
  });
}

/** 清理过期缓存（超过2天的内容缓存文件） */
export function cleanupOldCache(): void {
  if (!dirReady || appContext === null) {
    return;
  }
  try {
    const dir: string = appContext.filesDir + '/zhihu_cache';
    const files: string[] = fs.listFileSync(dir);
    const now: number = Date.now();
    for (const f of files) {
      if (!f.startsWith('content_')) {
        continue;
      }
      try {
        const stat = fs.statSync(dir + '/' + f);
        if (now - stat.mtime * 1000 > CACHE_TWO_DAYS_MS) {
          fs.unlinkSync(dir + '/' + f);
        }
      } catch (e) {
        // skip
      }
    }
  } catch (e) {
    console.error('[ZhihuLite] cleanupOldCache fail err=' + String(e));
  }
}
