/**
 * components/NetImage —— 可长按下载原图的网络图片组件
 * ----------------------------------------------------------------------------
 * 用法：NetImage({ url, width, height, radius, fit, backgroundColor })
 * 长按 → 下载原图（无水印）到系统相册（toast 反馈 + 权限弹窗）
 */

import { common } from '@kit.AbilityKit';
import { ZhihuColors } from '../utils/theme';
import { downloadImageToGallery } from '../utils/imageDownload';

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

  build() {
    Stack() {
      Image(this.url)
        .width('100%')
        .height('100%')
        .objectFit(this.fit)
        .backgroundColor(ZhihuColors.backgroundTertiary)
    }
    .width(this.w > 0 ? this.w : '100%')
    .height(this.h > 0 ? this.h : '100%')
    .borderRadius(this.r)
    .margin({ top: this.mt, right: this.mr, bottom: this.mb, left: this.ml })
    .clip(true)
    .gesture(
      LongPressGesture({ repeat: false, duration: 300 })
        .onAction(() => {
          this.save();
        })
    )
  }

  private save(): void {
    if (this.url.length === 0) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    downloadImageToGallery(this.url, ctx);
  }
}
