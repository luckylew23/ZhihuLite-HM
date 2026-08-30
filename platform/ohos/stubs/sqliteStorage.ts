// @react-native-ohos/sqlite-storage 的降级 stub
// 该包在 npm/ohpm 上并未发布；当它缺失时回退到此文件，避免打包中断。
// openDatabase 直接抛出明确错误 —— expo-sqlite 垫片会把它转成 reject，
// 仅影响「本地去重/曝光」等非核心功能（storage/localDatabase.ts）。
export function openDatabase(_params: any, _cb1?: any, _cb2?: any): never {
  throw new Error(
    '[OHOS] 未安装 @react-native-ohos/sqlite-storage，SQLite 功能不可用（仅影响本地曝光去重）',
  );
}

export function deleteDatabase(_params: any): void {}

export const enablePromise = (_enabled: boolean) => {};
export const DEBUG = false;

export default { openDatabase, deleteDatabase, enablePromise, DEBUG };
