/**
 * pages/ImageViewerPage —— 全屏看图（去水印原图）。
 * 参数：url（内容图 URL）；进入后自动转原图（无水印），单击关闭。
 * 右上角：系统 SaveButton（保存到相册，无需危险权限）+ 复制链接。
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';
import { readStringParam } from '../components/detail/detailUtils';
import { toOriginalImageUrl } from '../utils/imageUrl';

const IMAGE_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

@Entry
@Component
struct ImageViewerPage {
  @State url: string = '';
  @State saving: boolean = false;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    const raw: string = readStringParam(p, 'url');
    this.url = toOriginalImageUrl(raw);
  }

  /** 先把网络图下载到内存 buffer，再经 SaveButton 授权后的 createAsset 写入相册 */
  private async saveToGallery(): Promise<void> {
    if (this.saving || this.url.length === 0) {
      return;
    }
    this.saving = true;
    try {
      const httpRequest = http.createHttp();
      const resp = await httpRequest.request(this.url, {
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
        promptAction.showToast({ message: '下载失败', duration: 1500 });
        return;
      }
      const buf: ArrayBuffer = resp.result as ArrayBuffer;
      httpRequest.destroy();

      const ctx = getContext(this) as common.UIAbilityContext;
      const helper = photoAccessHelper.getPhotoAccessHelper(ctx);
      const photoUri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const f = fileIo.openSync(photoUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, buf);
      fileIo.closeSync(f);
      promptAction.showToast({ message: '已保存到相册', duration: 1500 });
    } catch (e) {
      const err: Error = e as Error;
      promptAction.showToast({ message: `保存失败: ${err.message}`, duration: 2000 });
    } finally {
      this.saving = false;
    }
  }

  private copyLink(): void {
    const pb = pasteboard.getSystemPasteboard();
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.url);
    pb.setData(data).then(() => {
      promptAction.showToast({ message: '链接已复制', duration: 1500 });
    }).catch(() => {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    });
  }

  build() {
    Stack() {
      if (this.url.length > 0) {
        Image(this.url)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      }

      // 右上角操作层：内层 Stack 撑满并 TopEnd 对齐，按钮固定右上角
      Stack({ alignContent: Alignment.TopEnd }) {
        Row({ space: 10 }) {
          // 复制链接（圆形半透明按钮）
          Text('⧉')
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor('rgba(0,0,0,0.45)')
            .fontSize(18)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              this.copyLink();
            })
          // 系统 SaveButton：点击瞬间系统授权写相册，无需 WRITE_IMAGEVIDEO
          SaveButton({
            icon: SaveIconStyle.FULL_FILLED,
            text: SaveDescription.SAVE_IMAGE,
            buttonType: ButtonType.Circle,
          })
            .width(40)
            .height(40)
            .onClick(() => {
              this.saveToGallery();
            })
        }
        .margin({ top: 16, right: 16 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onClick(() => {
      router.back();
    })
  }
}
