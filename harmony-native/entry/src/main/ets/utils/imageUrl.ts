/**
 * utils/imageUrl —— 知乎图床 URL 处理
 * ----------------------------------------------------------------------------
 * 知乎图床 URL 规律（pic*.zhimg.com）：
 *   - 列表压缩图：/80/v2-xxx_400x400.jpg?source=1940ef5c
 *   - 原图：       /v2-xxx.jpg（去掉压缩段 /80/、尺寸段 _400x400、水印参数 source=...）
 *   - 水印由 URL query 的 source 参数控制，去掉 query 即无水印
 */

/** 判断是否知乎图床图片 */
export function isZhihuImage(url: string): boolean {
  return url.includes('zhimg.com') || url.includes('zhihu.com/photo');
}

/**
 * 转为原图（无水印）URL：
 *  - 去 query（source= 水印/裁剪参数）
 *  - 去尺寸段 _400x400 / _200x112 / _720w 等
 *  - 去压缩段 /80/、/r/、/720w/
 */
export function toOriginalImageUrl(url: string): string {
  if (!url || url.length === 0) {
    return url;
  }
  let clean: string = url.split('?')[0];
  // 尺寸段 _400x400 / _1200x630 / _200x112 …
  clean = clean.replace(/_\d{2,5}x\d{2,5}/g, '');
  // 宽度段 _720w / _1080w
  clean = clean.replace(/_\d{2,5}w/g, '');
  // 压缩/缩放路径段 /80/、/r/、/720w/
  clean = clean.replace(/\/80\//g, '/');
  clean = clean.replace(/\/r\//g, '/');
  clean = clean.replace(/\/720w\//g, '/');
  return clean;
}
