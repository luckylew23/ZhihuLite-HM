/**
 * components/NetImage —— 可交互网络图片组件（含加载失败兜底）
 * ----------------------------------------------------------------------------
 * 用法：NetImage({ url, w, h, r, fit, mt, mr, mb, ml, tapView })
 * 1) 直连 Image 加载；失败（onError）→ 带 UA/Referer 的 http 下载 → 缓存到沙箱 → 本地显示
 * 2) tapView=true 时：单击 → 全屏看图（去水印原图）；长按 → 底部菜单「保存到相册 / 复制图片链接」
 * 3) tapView=false（列表缩略图等）：仅长按保存，不拦截卡片点击
 */

import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';
import { downloadImageToGallery } from '../utils/imageDownload';
import { toOriginalImageUrl } from '../utils/imageUrl';

const TAG: string = 'ZhihuLite';
const DOMAIN: number = 0x0002;

const IMAGE_UA: string =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36';

/** 简单字符串 hash（缓存文件名用，避免 URL 特殊字符） */
function urlHash(s: string): string {
  let h: number = 0;
  for (let i = 0; i < s.length; i++) {
    h = (h * 31 + s.charCodeAt(i)) >>> 0;
  }
  return h.toString(36);
}

/** 带请求头下载到沙箱缓存，返回 file:// 本地路径；失败返回空串 */
async function fetchToCache(url: string, context: common.UIAbilityContext): Promise<string> {
  const httpRequest = http.createHttp();
  try {
    const resp = await httpRequest.request(url, {
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
      hilog.warn(DOMAIN, TAG, 'img fallback http=%{public}d url=%{public}s', resp.responseCode, url);
      return '';
    }
    const buf: ArrayBuffer = resp.result as ArrayBuffer;
    if (buf.byteLength === 0) {
      return '';
    }
    const dir: string = `${context.cacheDir}/zhihu_img`;
    try {
      fileIo.accessSync(dir);
    } catch (e) {
      fileIo.mkdirSync(dir);
    }
    const path: string = `${dir}/${urlHash(url)}.jpg`;
    const f = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(f.fd, buf);
    fileIo.closeSync(f);
    hilog.info(DOMAIN, TAG, 'img fallback cached n=%{public}d url=%{public}s', buf.byteLength, url);
    return `file://${path}`;
  } catch (e) {
    const err: Error = e as Error;
    hilog.warn(DOMAIN, TAG, 'img fallback failed: %{public}s url=%{public}s', err.message, url);
    return '';
  } finally {
    httpRequest.destroy();
  }
}

@Component
export struct NetImage {
  @Prop url: string = '';
  @Prop w: number = 100;
  @Prop h: number = 100;
  @Prop r: number = 0;
  @Prop fit: ImageFit = ImageFit.Cover;
  @Prop mt: number = 0;
  @Prop mr: number = 0;
  @Prop mb: number = 0;
  @Prop ml: number = 0;
  /** true=可交互：单击全屏看图，长按出操作菜单；false=仅长按保存，不拦截父级点击 */
  @Prop tapView: boolean = false;

  @State src: string = '';
  @State fallbackTried: boolean = false;
  @State showMenu: boolean = false;

  @Builder
  imageMenu() {
    Column({ space: 4 }) {
      Text('复制图片链接')
        .width('100%')
        .height(52)
        .textAlign(TextAlign.Center)
        .fontSize(17)
        .fontColor(ZhihuColors.text)
        .onClick(() => {
          this.showMenu = false;
          this.copyLink();
        })
      Divider().color(ZhihuColors.backgroundTertiary)
      Text('取消')
        .width('100%')
        .height(52)
        .textAlign(TextAlign.Center)
        .fontSize(17)
        .fontColor(ZhihuColors.textTertiary)
        .onClick(() => {
          this.showMenu = false;
        })
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .padding({ bottom: 24 })
  }

  build() {
    Stack() {
      Image(this.src.length > 0 ? this.src : this.url)
        .width('100%')
        .height('100%')
        .objectFit(this.fit)
        .backgroundColor(ZhihuColors.backgroundTertiary)
        .onError(() => {
          hilog.warn(DOMAIN, TAG, 'img direct error url=%{public}s', this.url);
          this.tryFallback();
        })
    }
    .width(this.w > 0 ? this.w : '100%')
    .height(this.h > 0 ? this.h : '100%')
    .borderRadius(this.r)
    .margin({ top: this.mt, right: this.mr, bottom: this.mb, left: this.ml })
    .clip(true)
    .onClick(() => {
      if (this.tapView) {
        this.openViewer();
      }
    })
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          if (this.tapView) {
            this.showMenu = true;
          } else {
            this.save();
          }
        })
    )
    .bindSheet($$this.showMenu, this.imageMenu(), {
      height: 220,
      dragBar: false,
    })
  }

  private tryFallback(): void {
    if (this.fallbackTried || this.src === this.url) {
      return;
    }
    if (!this.url.startsWith('http')) {
      return;
    }
    this.fallbackTried = true;
    const ctx = getContext(this) as common.UIAbilityContext;
    this.loadLocal(ctx);
  }

  private async loadLocal(ctx: common.UIAbilityContext): Promise<void> {
    const local: string = await fetchToCache(this.url, ctx);
    if (local.length > 0) {
      this.src = local;
    }
  }

  /** 单击 → 全屏看原图（去水印） */
  private openViewer(): void {
    if (this.url.length === 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/ImageViewerPage',
      params: { url: this.url },
    });
  }

  /** 保存无水印原图到相册 */
  private save(): void {
    if (this.url.length === 0) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    downloadImageToGallery(toOriginalImageUrl(this.url), ctx);
  }

  /** 复制图片直链到剪贴板 */
  private copyLink(): void {
    const pb = pasteboard.getSystemPasteboard();
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, toOriginalImageUrl(this.url));
    pb.setData(data).then(() => {
      promptAction.showToast({ message: '链接已复制', duration: 1500 });
    }).catch((e: Error) => {
      promptAction.showToast({ message: '复制失败', duration: 1500 });
    });
  }
}
