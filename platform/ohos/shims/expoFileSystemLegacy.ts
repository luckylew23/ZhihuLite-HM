// expo-file-system/legacy → OHOS 兼容垫片
// 项目在 useAuthStore / saveImage / UpdateChecker 中通过 /legacy 子路径引入，
// 此处直接复用主模块的同名 API，保持接口一致。
export * from './expoFileSystem';
