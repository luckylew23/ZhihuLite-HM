// expo-sqlite → OHOS 兼容垫片
// 委托给社区 OpenHarmony 端口 @react-native-ohos/sqlite-storage。
// 该包需通过 package.ohos.json 安装；缺失时 openDatabaseAsync 会抛出明确错误，
// 仅影响「本地去重/曝光」等非核心功能。接口对齐 expo-sqlite 的异步 API。
let SQLiteLib: any = null;
try {
  SQLiteLib = require('@react-native-ohos/sqlite-storage');
} catch {
  SQLiteLib = null;
}

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

export function openDatabaseAsync(name: string): Promise<SQLiteDatabase> {
  if (!SQLiteLib) {
    return Promise.reject(
      new Error(
        '[OHOS] 未安装 @react-native-ohos/sqlite-storage，请通过 package.ohos.json 安装后再构建（详见 EXPO_OHOS_MAPPING.md）',
      ),
    );
  }
  return new Promise((resolve, reject) => {
    const db = SQLiteLib.openDatabase(name, '1.0', 'zhihu--', 200000);
    const wrap: SQLiteDatabase = {
      execAsync(source: string) {
        return new Promise<void>((res, rej) => {
          db.transaction(
            (tx: any) => {
              source
                .split(';')
                .map((s) => s.trim())
                .filter(Boolean)
                .forEach((stmt) => tx.executeSql(stmt));
            },
            (e: any) => rej(e),
            () => res(),
          );
        });
      },
      runAsync(sql: string, params: any[] = []) {
        return new Promise((res, rej) => {
          db.transaction((tx: any) => {
            tx.executeSql(
              sql,
              params,
              (_t: any, r: any) => res({ lastInsertRowId: r.insertId ?? 0, rowsAffected: r.rowsAffected }),
              (_t: any, e: any) => rej(e),
            );
          });
        });
      },
      getFirstAsync(sql: string, params: any[] = []) {
        return new Promise((res, rej) => {
          db.transaction((tx: any) => {
            tx.executeSql(
              sql,
              params,
              (_t: any, r: any) => res(r.rows.length ? r.rows.item(0) : null),
              (_t: any, e: any) => rej(e),
            );
          });
        });
      },
      getAllAsync(sql: string, params: any[] = []) {
        return new Promise((res, rej) => {
          db.transaction((tx: any) => {
            tx.executeSql(
              sql,
              params,
              (_t: any, r: any) => {
                const out: any[] = [];
                for (let i = 0; i < r.rows.length; i++) out.push(r.rows.item(i));
                res(out);
              },
              (_t: any, e: any) => rej(e),
            );
          });
        });
      },
      closeAsync() {
        return new Promise<void>((res) => db.close(() => res(), () => res()));
      },
    };
    resolve(wrap);
  });
}

export const enableUnsafeNativeMethod = () => {};
export const SQLite = { openDatabaseAsync };

export default { openDatabaseAsync, enableUnsafeNativeMethod, SQLite };
