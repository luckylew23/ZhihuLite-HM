/**
 * pages/DailyDetailPage —— 日报文章详情。
 * 上游：app/article/[id].tsx（source=daily 分支，用 getDailyDetail）。
 * 结构：DetailNavBar + 头图 + 标题 + hint + 正文（HTML 剥标签纯文本降级）。
 */

import { router } from '@kit.ArkUI';
import {
  DailyDetailResponse,
  getDailyDetail,
  htmlToPlainText,
} from '../api/daily';
import { ZhihuColors } from '../utils/theme';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { readStringParam } from '../components/detail/detailUtils';

@Entry
@Component
struct DailyDetailPage {
  @State storyId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State detail: DailyDetailResponse | null = null;
  private bodyText: string = '';
  private fallbackTitle: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.storyId = readStringParam(p, 'id');
    this.fallbackTitle = readStringParam(p, 'title');
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const d: DailyDetailResponse = await getDailyDetail(this.storyId);
      this.detail = d;
      this.bodyText = htmlToPlainText(d.body);
    } catch (e) {
      this.error = '日报内容加载失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  private coverUrl(): string {
    const d = this.detail;
    if (!d) {
      return '';
    }
    if (d.image && d.image.length > 0) {
      return d.image;
    }
    if (d.images && d.images.length > 0 && d.images[0].length > 0) {
      return d.images[0];
    }
    return '';
  }

  build() {
    Column() {
      DetailNavBar({ title: this.detail ? this.detail.title : (this.fallbackTitle.length > 0 ? this.fallbackTitle : '日报') })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ loading: false, error: this.error, onRetry: () => this.load() })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 头图
            if (this.coverUrl().length > 0) {
              Image(this.coverUrl())
                .width('100%')
                .height(220)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
            }
            Column({ space: 10 }) {
              Text(this.detail?.title ?? '')
                .copyOption(CopyOptions.LocalDevice)
                .fontSize(21)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
                .width('100%')
              if (this.detail?.hint && this.detail.hint.length > 0) {
                Text(this.detail.hint)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(13)
                  .fontColor(ZhihuColors.textSecondary)
                  .width('100%')
              }
              if (this.bodyText.length > 0) {
                Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ top: 4, bottom: 4 })
                Text(this.bodyText)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(15)
                  .lineHeight(24)
                  .fontColor(ZhihuColors.text)
                  .width('100%')
              } else {
                Text('正文暂无法展示')
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(14)
                  .fontColor(ZhihuColors.textTertiary)
                  .width('100%')
                  .padding({ top: 20 })
              }
            }
            .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
