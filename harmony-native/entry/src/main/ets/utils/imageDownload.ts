/**
 * utils/imageDownload —— 长按图片下载原图（无水印）到系统相册
 * ----------------------------------------------------------------------------
 * 流程：申请相册权限 → 原图 URL（imageUrl.ts）→ http 二进制下载 →
 *       photoAccessHelper.createAsset 写入相册 → toast 反馈
 * 依赖权限：ohos.permission.WRITE_IMAGEVIDEO（module.json5 已声明，运行时申请）
 */

import { http } from '@kit.NetworkKit';
import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { isZhihuImage, toOriginalImageUrl } from './imageUrl';

const TAG: string = 'ZhihuLite';
const DOMAIN: number = 0x0002;

const IMAGE_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

function extOf(url: string): string {
  const path: string = url.split('?')[0];
  const dot: number = path.lastIndexOf('.');
  if (dot >= 0) {
    const ext: string = path.substring(dot + 1).toLowerCase();
    if (ext === 'jpg' || ext === 'jpeg' || ext === 'png' || ext === 'gif' || ext === 'webp') {
      return ext === 'jpeg' ? 'jpg' : ext;
    }
  }
  return 'jpg';
}

function toast(msg: string): void {
  promptAction.showToast({ message: msg, duration: 2500 });
}

/** 下载图片（网络 URL）到系统相册；优先原图、无水印 */
export async function downloadImageToGallery(rawUrl: string, context: common.UIAbilityContext): Promise<void> {
  if (!rawUrl || rawUrl.length === 0) {
    return;
  }
  // 1. 相册权限（user_grant，首次弹窗）
  try {
    const atManager = abilityAccessCtrl.createAtManager();
    const res = await atManager.requestPermissionsFromUser(context, ['ohos.permission.WRITE_IMAGEVIDEO']);
    if (res.authResults.length === 0 || res.authResults[0] !== 0) {
      toast('需要相册权限才能保存图片');
      return;
    }
  } catch (e) {
    toast('权限申请失败');
    return;
  }

  // 2. 原图 URL（知乎图床去水印参数 + 去压缩/尺寸段）
  const target: string = isZhihuImage(rawUrl) ? toOriginalImageUrl(rawUrl) : rawUrl;
  const ext: string = extOf(target);
  toast('正在下载原图…');

  const httpRequest = http.createHttp();
  try {
    // 3. 二进制下载
    const resp = await httpRequest.request(target, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      header: {
        'User-Agent': IMAGE_UA,
        'Referer': 'https://www.zhihu.com/',
      },
      connectTimeout: 15000,
      readTimeout: 30000,
    });
    if (resp.responseCode !== 200) {
      toast('图片下载失败（HTTP ' + resp.responseCode + '）');
      return;
    }
    const buf: ArrayBuffer = resp.result as ArrayBuffer;
    if (buf.byteLength === 0) {
      toast('图片下载失败（空数据）');
      return;
    }

    // 4. 写入系统相册
    const helper = photoAccessHelper.getPhotoAccessHelper(context);
    const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, ext);
    const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, buf);
    fileIo.closeSync(file);
    toast('已保存原图到相册');
    hilog.info(DOMAIN, TAG, 'image saved url=%{public}s', target);
  } catch (e) {
    const err: Error = e as Error;
    hilog.error(DOMAIN, TAG, 'image download failed: %{public}s', err.message);
    toast('下载失败，请稍后重试');
  } finally {
    httpRequest.destroy();
  }
}
