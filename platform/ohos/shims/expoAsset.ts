// expo-asset → OHOS 兼容垫片
// ----------------------------------------------------------------------------
// expo-asset 负责解析/下载资源（字体、图片）。它依赖 expo-modules-core 的原生桥，
// 在 OHOS 上没有等价实现。本垫片提供 expo-font（经 @expo/vector-icons 的 Ionicons）
// 实际用到的最小接口：Asset.fromURI / fromModule / downloadAsync / downloaded / localUri。
// 行为：视为「已下载」，直接把 uri 当作 localUri，避免字体加载流程抛错。
// ----------------------------------------------------------------------------

export interface AssetDescriptor {
  name?: string;
  type?: string;
  uri?: string | number;
  width?: number;
  height?: number;
}

export class Asset {
  name: string;
  type: string;
  uri?: string | number;
  localUri?: string;
  width?: number;
  height?: number;
  downloaded = true;
  downloading = false;
  hash?: string;

  constructor(descriptor: AssetDescriptor = {}) {
    const uri = descriptor.uri;
    this.name = descriptor.name ?? String(uri ?? '');
    this.type = descriptor.type ?? this.inferType(uri);
    this.uri = uri;
    this.localUri = typeof uri === 'string' ? uri : undefined;
    this.width = descriptor.width;
    this.height = descriptor.height;
  }

  private inferType(uri?: string | number): string {
    if (typeof uri !== 'string') return 'asset';
    const ext = uri.split('.').pop()?.toLowerCase();
    return ext ?? 'asset';
  }

  static fromURI(uri: string): Asset {
    return new Asset({ uri });
  }

  static fromModule(mod: string | number): Asset {
    // RN 的 require('x.png') 在打包后是资源 ID（数字）或对象
    const uri = typeof mod === 'number' ? String(mod) : (mod as string);
    return new Asset({ uri });
  }

  static fromMetadata(meta: AssetDescriptor): Asset {
    return new Asset(meta);
  }

  async downloadAsync(): Promise<this> {
    this.downloaded = true;
    this.downloading = false;
    return this;
  }

  async downloadAsyncIfNeeded(): Promise<this> {
    return this.downloadAsync();
  }
}

export function useAssets(_modules: any[]): [Asset[] | undefined, Error | undefined] {
  return [undefined, undefined];
}

export default Asset;
