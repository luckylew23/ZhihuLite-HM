// expo-modules-core → OHOS 兼容垫片
// ----------------------------------------------------------------------------
// expo-modules-core 是 Expo 的「原生模块桥」。OHOS 上没有等价实现（RNOH 有自己的
// 原生模块体系），因此这里提供最小可用的 JS 表面，让依赖它的 expo-* 包
// （如 expo-font → @expo/vector-icons 的 Ionicons）能被打包并优雅降级。
// 业务代码本身并不直接使用本模块。
// ----------------------------------------------------------------------------

export class CodedError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'CodedError';
    this.code = code;
  }
}

export class UnavailabilityError extends Error {
  constructor(moduleName: string, propertyName: string) {
    super(`The method or property ${moduleName}.${propertyName} is not available on HarmonyOS`);
    this.name = 'UnavailabilityError';
  }
}

// expo-font 等包会判断 Platform.OS === 'web' 来决定走 Web 还是原生分支
export const Platform = {
  OS: 'harmony',
  select<T>(spec: Record<string, T>): T {
    return (spec.harmony ?? spec.native ?? spec.default) as T;
  },
};

// 已知原生模块的降级实现
const NATIVE_STUBS: Record<string, any> = {
  ExpoFontLoader: {
    getLoadedFonts: () => [] as string[],
    loadAsync: async (_name: string, _localUri?: string) => {},
    isLoaded: (_name: string) => true,
  },
};

/** 返回原生模块；OHOS 上无真实实现时给出惰性 no-op 代理，避免打包/运行崩溃 */
export function requireNativeModule(name: string): any {
  const known = NATIVE_STUBS[name];
  if (known) return known;
  return new Proxy(
    {},
    {
      get(_target, prop) {
        // 避免被当作 thenable，否则 await 该模块会永久挂起
        if (prop === 'then' || prop === Symbol.toPrimitive) return undefined;
        return async () => undefined;
      },
    },
  );
}

/** 可选原生模块：缺失时返回 null（expo-font 的 ExpoFontUtils 走此路径） */
export function requireOptionalNativeModule(name: string): any {
  try {
    return requireNativeModule(name);
  } catch {
    return null;
  }
}

export function registerWebModule(cls: any, _name?: string): any {
  return cls;
}

export class NativeModule {}

export const EventEmitter = class {
  addListener(_event: string, _cb: (...args: any[]) => void) {
    return { remove: () => {} };
  }
  removeAllListeners(_event?: string) {}
  emit(_event: string, ..._args: any[]) {}
};

export const uuid = {
  v4: () => '00000000-0000-0000-0000-000000000000',
};

export default {
  CodedError,
  UnavailabilityError,
  Platform,
  requireNativeModule,
  requireOptionalNativeModule,
  registerWebModule,
  NativeModule,
  EventEmitter,
  uuid,
};
