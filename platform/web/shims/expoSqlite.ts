// expo-sqlite → Web 降级垫片
// ---------------------------------------------------------------------------
// 为什么需要它：
//   expo-sqlite 的 web 实现（node_modules/expo-sqlite/web/worker.ts）会
//   `import './wa-sqlite/wa-sqlite.wasm'`，而 Metro 默认不把 .wasm 当资源，
//   直接报 "Unable to resolve module ./wa-sqlite/wa-sqlite.wasm"，
//   导致 `expo export --platform web` 打包失败。
//
// 为什么不用 platform/ohos/shims/expoSqlite.ts：
//   那个垫片 require('@react-native-ohos/sqlite-storage')，web 下必然缺失，
//   openDatabaseAsync 会 reject —— 若业务侧未 catch 就会触发未处理拒绝，
//   在 ArkWeb 里表现为错误浮层或功能异常。
//
// 这里改为「永不失败的内存降级」：写操作全部成功，读操作返回空结果。
// 影响范围仅限本地去重 / 曝光记录 / 信息流缓存等非核心能力，
// 首屏渲染与联网功能完全不受影响。
// ---------------------------------------------------------------------------

export interface SQLiteDatabase {
  execAsync(source: string): Promise<void>;
  runAsync(
    sql: string,
    params?: any[],
  ): Promise<{ lastInsertRowId: number; rowsAffected: number }>;
  getFirstAsync<T = any>(sql: string, params?: any[]): Promise<T | null>;
  getAllAsync<T = any>(sql: string, params?: any[]): Promise<T[]>;
  closeAsync(): Promise<void>;
}

function createNoopDatabase(): SQLiteDatabase {
  return {
    execAsync: async () => {},
    runAsync: async () => ({ lastInsertRowId: 0, rowsAffected: 0 }),
    getFirstAsync: async () => null,
    getAllAsync: async () => [],
    closeAsync: async () => {},
  };
}

export function openDatabaseAsync(_name: string): Promise<SQLiteDatabase> {
  return Promise.resolve(createNoopDatabase());
}

export const enableUnsafeNativeMethod = () => {};
export const SQLite = { openDatabaseAsync };

export default { openDatabaseAsync, enableUnsafeNativeMethod, SQLite };
