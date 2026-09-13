/**
 * pages/PublishPinPage —— 发想法（按 Android v0.6.0 截图 05 重构布局）。
 * 结构：×关闭 + 标题「发想法」+ 右侧蓝色圆角「发布」胶囊按钮；
 *       标题输入 + 多行正文输入；已选图片缩略图网格(右上角×删除)；
 *       底部「添加图片 (N/9)」按钮。
 *
 * 【降级说明】图片选择已接 photoAccessHelper.pickPhotos（本地预览/删除/计数 N/9），
 *       但 api/image.ts 的 uploadImage 在 HarmonyOS 端已降级（不实现 OSS 上传），
 *       因此带图发布暂时被拦截并提示，仅纯文本可真正发布。
 */

import { router } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { createPin } from '../api/pin';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';

interface PickedImage {
  uri: string;
}

const MAX_IMAGES: number = 9;

function toParagraphHtml(text: string): string {
  const trimmed = text.trim();
  if (trimmed.length === 0) {
    return '';
  }
  const lines: string[] = trimmed.split('\n');
  let html: string = '<p>';
  for (let i = 0; i < lines.length; i++) {
    if (i > 0) {
      html += '</p><p>';
    }
    html += lines[i];
  }
  html += '</p>';
  return html;
}

@Entry
@Component
struct PublishPinPage {
  @State title: string = '';
  @State content: string = '';
  @State submitting: boolean = false;
  @State error: string = '';
  @State images: PickedImage[] = [];

  private async pickImages(): Promise<void> {
    const remain: number = MAX_IMAGES - this.images.length;
    if (remain <= 0) {
      this.error = '最多选择 9 张图片';
      return;
    }
    try {
      // 系统相册选择走 PhotoViewPicker（无需上下文），返回的是 uri 字符串数组。
      const picker: photoAccessHelper.PhotoViewPicker =
        new photoAccessHelper.PhotoViewPicker();
      const options: photoAccessHelper.PhotoSelectOptions =
        new photoAccessHelper.PhotoSelectOptions();
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      options.maxSelectNumber = remain;
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      const picked: PickedImage[] = [];
      for (const uri of result.photoUris) {
        picked.push({ uri: uri });
      }
      this.images = this.images.concat(picked);
      this.error = '';
    } catch (e) {
      this.error = '打开相册失败，请重试';
    }
  }

  private removeImage(index: number): void {
    const next: PickedImage[] = [];
    for (let i = 0; i < this.images.length; i++) {
      if (i !== index) {
        next.push(this.images[i]);
      }
    }
    this.images = next;
  }

  private async submit(): Promise<void> {
    if (this.submitting) {
      return;
    }
    if (this.content.trim().length === 0) {
      this.error = '请输入想法内容';
      return;
    }
    if (this.images.length > 0) {
      this.error = '图片上传暂未开放（已降级），当前仅支持纯文本发布，请先移除已选图片';
      return;
    }
    this.submitting = true;
    this.error = '';
    try {
      await createPin(toParagraphHtml(this.content), {
        title: this.title.trim(),
      });
      router.back();
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.submitting = false;
    }
  }

  @Builder
  topBar() {
    Row() {
      Text('✕')
        .fontSize(24)
        .fontColor(ZhihuColors.text)
        .width(44)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text('发想法')
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
      Blank()
      Row() {
        if (this.submitting) {
          LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
        } else {
          Text('发布')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.textInverse)
            .height(36)
            .padding({ left: 20, right: 20 })
            .backgroundColor(ZhihuColors.primary)
            .borderRadius(18)
            .onClick(() => {
              this.submit();
            })
        }
      }
      .width(72)
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  loginPrompt() {
    Column({ space: 16 }) {
      Blank()
      Text('发布想法前请先登录知乎账号')
        .fontSize(16)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(17)
        .backgroundColor(ZhihuColors.primary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  imageGrid() {
    if (this.images.length > 0) {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.images, (img: PickedImage, index: number) => {
          Stack({ alignContent: Alignment.TopEnd }) {
            Image(img.uri)
              .width(96)
              .height(96)
              .borderRadius(8)
              .objectFit(ImageFit.Cover)
              .backgroundColor(ZhihuColors.backgroundTertiary)
            Stack() {
              Text('✕')
            }
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor('#80000000')
            .margin({ top: -6, right: -6 })
            .onClick(() => {
              this.removeImage(index);
            })
          }
          .margin({ right: 10, bottom: 10 })
        }, (img: PickedImage, index: number) => index + '-' + img.uri)
      }
      .width('100%')
    }
  }

  @Builder
  addImageButton() {
    Row({ space: 8 }) {
      Text('🖼')
      Text('添加图片 (' + this.images.length + '/' + MAX_IMAGES + ')')
        .fontSize(17)
        .fontColor(ZhihuColors.primary)
    }
    .width('100%')
    .height(46)
    .justifyContent(FlexAlign.Center)
    .borderRadius(23)
    .border({ width: 1, color: ZhihuColors.primary })
    .opacity(this.images.length >= MAX_IMAGES ? 0.4 : 1)
    .onClick(() => {
      this.pickImages();
    })
  }

  @Builder
  form() {
    Scroll() {
      Column({ space: 12 }) {
        TextInput({ text: $$this.title, placeholder: '标题（可选）' })
          .width('100%')
          .height(50)
          .fontSize(19)
          .fontWeight(FontWeight.Medium)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(Color.Transparent)
          .margin({ top: 8 })

        Divider().color(ZhihuColors.border)

        TextArea({ text: $$this.content, placeholder: '这一刻的想法…' })
          .width('100%')
          .height(220)
          .fontSize(18)
          .placeholderColor(ZhihuColors.textTertiary)
          .backgroundColor(Color.Transparent)

        this.imageGrid()

        this.addImageButton()

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(15)
            .fontColor(ZhihuColors.danger)
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  build() {
    Column() {
      this.topBar()
      if (!authStore.isLoggedIn) {
        this.loginPrompt()
      } else {
        this.form()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
