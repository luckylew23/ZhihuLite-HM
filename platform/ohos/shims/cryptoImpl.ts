// cryptoImpl.ts — 纯 JS 实现的 MD5 与 SHA-256。
// 之所以自带实现而非依赖原生模块，是为了让 zse96 签名在 OHOS 上零额外原生依赖即可运行。
// 算法为标准实现，可直接替换 expo-crypto 的 digestStringAsync。

function toUtf8Bytes(str: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < str.length; i++) {
    let c = str.charCodeAt(i);
    if (c < 0x80) out.push(c);
    else if (c < 0x800) {
      out.push(0xc0 | (c >> 6), 0x80 | (c & 0x3f));
    } else if (c >= 0xd800 && c <= 0xdbff && i + 1 < str.length) {
      const c2 = str.charCodeAt(++i);
      c = 0x10000 + ((c & 0x3ff) << 10) + (c2 & 0x3ff);
      out.push(
        0xf0 | (c >> 18),
        0x80 | ((c >> 12) & 0x3f),
        0x80 | ((c >> 6) & 0x3f),
        0x80 | (c & 0x3f),
      );
    } else {
      out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 0x3f), 0x80 | (c & 0x3f));
    }
  }
  return out;
}

function rotl(x: number, c: number): number {
  return (x << c) | (x >>> (32 - c));
}

// SHA-256 使用右旋（ROTR），MD5 使用左旋（ROTL）；两者不可混用。
function rotr(x: number, c: number): number {
  return (x >>> c) | (x << (32 - c));
}

function md5(bytes: number[]): string {
  const s = [
    7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9,
    14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
    4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
  ];
  const K = [
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613,
    0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193,
    0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d,
    0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed,
    0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122,
    0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa,
    0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244,
    0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
    0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb,
    0xeb86d391,
  ];
  const a0 = 0x67452301, b0 = 0xefcdab89, c0 = 0x98badcfe, d0 = 0x10325476;
  const msg = bytes.slice();
  const origLen = msg.length;
  msg.push(0x80);
  while (msg.length % 64 !== 56) msg.push(0);
  const bits = origLen * 8;
  msg.push(
    bits >>> 0 & 0xff, (bits >>> 8) & 0xff, (bits >>> 16) & 0xff, (bits >>> 24) & 0xff,
    0, 0, 0, 0,
  );
  let A = a0, B = b0, C = c0, D = d0;
  const m = new Int32Array(16);
  for (let i = 0; i < msg.length; i += 64) {
    for (let j = 0; j < 16; j++) {
      m[j] =
        (msg[i + j * 4] |
          (msg[i + j * 4 + 1] << 8) |
          (msg[i + j * 4 + 2] << 16) |
          (msg[i + j * 4 + 3] << 24)) >>>
        0;
    }
    let a = A, b = B, c = C, d = D;
    for (let k = 0; k < 64; k++) {
      let f: number, g: number;
      if (k < 16) {
        f = (b & c) | (~b & d);
        g = k;
      } else if (k < 32) {
        f = (d & b) | (~d & c);
        g = (5 * k + 1) % 16;
      } else if (k < 48) {
        f = b ^ c ^ d;
        g = (3 * k + 5) % 16;
      } else {
        f = c ^ (b | ~d);
        g = (7 * k) % 16;
      }
      f = (f + a + K[k] + m[g]) >>> 0;
      a = d;
      d = c;
      c = b;
      b = (b + rotl(f, s[k])) >>> 0;
    }
    A = (A + a) >>> 0;
    B = (B + b) >>> 0;
    C = (C + c) >>> 0;
    D = (D + d) >>> 0;
  }
  const hex = (n: number) =>
    (n & 0xff).toString(16).padStart(2, '0') +
    ((n >>> 8) & 0xff).toString(16).padStart(2, '0') +
    ((n >>> 16) & 0xff).toString(16).padStart(2, '0') +
    ((n >>> 24) & 0xff).toString(16).padStart(2, '0');
  return hex(A) + hex(B) + hex(C) + hex(D);
}

function sha256(bytes: number[]): string {
  const K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4,
    0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe,
    0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f,
    0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc,
    0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
    0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116,
    0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7,
    0xc67178f2,
  ];
  const h = [
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
    0x5be0cd19,
  ];
  const msg = bytes.slice();
  const origLen = msg.length;
  msg.push(0x80);
  while (msg.length % 64 !== 56) msg.push(0);
  // 注意：JS 的位移运算对移位量取模 32（x >>> 56 === x >>> 24），
  // 因此必须拆分高低 32 位分别取字节，不能直接 `(bits >>> (i * 8))`。
  const bits = origLen * 8;
  const bitsHi = Math.floor(bits / 0x100000000);
  const bitsLo = bits >>> 0;
  msg.push(
    (bitsHi >>> 24) & 0xff, (bitsHi >>> 16) & 0xff, (bitsHi >>> 8) & 0xff, bitsHi & 0xff,
    (bitsLo >>> 24) & 0xff, (bitsLo >>> 16) & 0xff, (bitsLo >>> 8) & 0xff, bitsLo & 0xff,
  );

  const w = new Int32Array(64);
  for (let i = 0; i < msg.length; i += 64) {
    for (let j = 0; j < 16; j++) {
      w[j] =
        (msg[i + j * 4] << 24) |
        (msg[i + j * 4 + 1] << 16) |
        (msg[i + j * 4 + 2] << 8) |
        msg[i + j * 4 + 3];
    }
    for (let j = 16; j < 64; j++) {
      const s0 = rotr(w[j - 15], 7) ^ rotr(w[j - 15], 18) ^ (w[j - 15] >>> 3);
      const s1 = rotr(w[j - 2], 17) ^ rotr(w[j - 2], 19) ^ (w[j - 2] >>> 10);
      w[j] = (w[j - 16] + s0 + w[j - 7] + s1) | 0;
    }
    let a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], h1 = h[7];
    for (let j = 0; j < 64; j++) {
      const S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      const ch = (e & f) ^ (~e & g);
      const t1 = (h1 + S1 + ch + K[j] + w[j]) | 0;
      const S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      const maj = (a & b) ^ (a & c) ^ (b & c);
      const t2 = (S0 + maj) | 0;
      h1 = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
    }
    h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0;
    h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + h1) | 0;
  }
  const hex = (n: number) => (n >>> 0).toString(16).padStart(8, '0');
  return h.map(hex).join('');
}

export function digest(algorithm: string, data: string): string {
  const bytes = toUtf8Bytes(data);
  switch (algorithm) {
    case 'MD5':
      return md5(bytes);
    case 'SHA-256':
      return sha256(bytes);
    case 'SHA-1':
      // 未实现：切勿返回 data 充当摘要（会产生看似正常的错误结果）。
      // 本项目 zse96 签名仅使用 MD5；若后续需要 SHA-1，请补齐实现后再放开。
      throw new Error('OHOS crypto shim 尚未实现 SHA-1');
    default:
      throw new Error(`OHOS crypto shim 暂不支持算法: ${algorithm}`);
  }
}
