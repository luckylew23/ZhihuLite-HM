/**
 * 图片 API —— 移植自上游 zhihu--/api/zhihu/image.ts。
 *
 * 【降级说明】按任务要求，HarmonyOS 端不实现真正的 multipart / 阿里云 OSS 上传：
 *   · 仅保留 getImage(imageId)：通过设备态图片接口读取已存在图片的公开 URL。
 *   · uploadImage(...) 保留函数签名与类型（LocalImageAsset / UploadedImage），
 *     但调用即抛出明确错误，提示「仅支持读取图片 URL，不支持本地上传」。
 *   · 上游 expo-crypto HMAC-SHA1 / expo-file-system 二进制 PUT / 轮询处理 等
 *     上传链路代码整体不移植（ArkTS 无对应 expo 模块，且本任务明确不做上传）。
 */

import { zhihuClient } from './httpClient';
import { getZhihuAppEndpointHeaders } from './appApi';

const IMAGE_API_URL = 'https://api.zhihu.com/images';

export interface LocalImageAsset {
  uri: string;
  width: number;
  height: number;
  mimeType?: string | null;
  fileName?: string | null;
}

export interface ZhihuImage {
  imageId: string;
  imageKey?: string;
  src: string;
  originalSrc?: string;
  watermark?: string;
  watermarkSrc?: string;
}

export interface UploadedImage extends ZhihuImage {
  width: number;
  height: number;
}

interface ImageDetailResponse {
  status?: string;
  src?: string;
  original_hash?: string;
  original_src?: string;
  watermark?: string;
  watermark_src?: string;
}

function normalizeImage(
  imageId: string | number,
  data: ImageDetailResponse,
): ZhihuImage {
  if (data.status !== 'success' || !data.src) {
    throw new Error('知乎图片尚未处理完成');
  }
  return {
    imageId: String(imageId),
    imageKey: data.original_hash,
    src: data.src,
    originalSrc: data.original_src,
    watermark: data.watermark,
    watermarkSrc: data.watermark_src,
  };
}

/** 按图片 id 拉取公开图片 URL（设备态端点，合并 app 端点头）。 */
export async function getImage(imageId: string | number): Promise<ZhihuImage> {
  const url: string =
    IMAGE_API_URL + '/' + encodeURIComponent(String(imageId));
  const response = await zhihuClient.get<ImageDetailResponse>(url, {
    headers: getZhihuAppEndpointHeaders(url),
  });
  return normalizeImage(imageId, response.data);
}

/**
 * 【已降级】创建/复用知乎图片并上传本地文件。
 * HarmonyOS 端不实现 multipart/OSS 上传，调用即抛错。
 * 如需图片，请先用其它方式获得 imageId，再调用 getImage() 取 URL。
 */
export async function uploadImage(
  _asset: LocalImageAsset,
  _source: string = 'comment',
): Promise<UploadedImage> {
  throw new Error(
    '图片上传在 HarmonyOS 端已降级：暂不实现 multipart/OSS 上传，' +
      '仅支持通过 getImage(imageId) 读取图片 URL。',
  );
}
