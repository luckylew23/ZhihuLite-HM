// expo-crypto → OHOS 兼容垫片（纯 JS 实现，见 cryptoImpl.ts）
import { digest } from './cryptoImpl';

export enum CryptoDigestAlgorithm {
  MD5 = 'MD5',
  SHA1 = 'SHA-1',
  SHA256 = 'SHA-256',
  SHA384 = 'SHA-384',
  SHA512 = 'SHA-512',
}

export enum CryptoEncoding {
  HEX = 'hex',
  BASE64 = 'base64',
}

function toBase64(hex: string): string {
  let bin = '';
  for (let i = 0; i < hex.length; i += 2) {
    bin += String.fromCharCode(parseInt(hex.substr(i, 2), 16));
  }
  if (typeof btoa !== 'undefined') return btoa(bin);
  // Hermes 无 btoa 时退化为 hex（调用方通常只校验 hex）
  return hex;
}

export async function digestStringAsync(
  algorithm: CryptoDigestAlgorithm | string,
  data: string,
  options?: { encoding?: CryptoEncoding },
): Promise<string> {
  // CryptoDigestAlgorithm 是字符串枚举，运行时值本身就是 'MD5'/'SHA-256' 等，
  // 直接 String() 归一即可（不能用 .valueOf()，TS 会把 else 分支收窄为 never）。
  const algo = String(algorithm);
  const hex = digest(algo, data);
  if (options?.encoding === CryptoEncoding.BASE64) return toBase64(hex);
  return hex;
}

export default { digestStringAsync, CryptoDigestAlgorithm, CryptoEncoding };
