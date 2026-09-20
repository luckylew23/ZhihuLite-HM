/**
 * pages/DailyDetailPage —— 日报文章详情。
 * 上游：app/article/[id].tsx（source=daily 分支，用 getDailyDetail）。
 * 结构：DetailNavBar + 头图 + 标题 + hint + 正文（HTML 剥标签纯文本降级）。
 */

import { router } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DailyDetailResponse,
  getDailyDetail,
} from '../api/daily';
import { ZhihuColors } from '../utils/theme';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { HtmlBlock, parseHtmlBlocks, readStringParam } from '../components/detail/detailUtils';
import { NetImage } from '../components/NetImage';

@Entry
@Component
struct DailyDetailPage {
  @State storyId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State detail: DailyDetailResponse | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
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
      // 头图已用 images[0]，正文里的 [图片] 占位用 images[1..] 依次替换
      const bodyImgs: string[] = (d.images !== undefined && d.images.length > 1) ? d.images.slice(1) : [];
      let blocks: HtmlBlock[] = this.fillPlaceholders(parseHtmlBlocks(d.body), bodyImgs);
      // 正文第一个图片块即答主头像，标记为小圆形头像渲染
      for (let k = 0; k < blocks.length; k++) {
        if (blocks[k].type === 'image') {
          blocks[k] = { type: 'image', text: '__avatar__', url: blocks[k].url };
          break;
        }
      }
      this.bodyBlocks = blocks;
    } catch (e) {
      this.error = '日报内容加载失败，请稍后重试';
    } finally {
      this.loading = false;
    }
  }

  /** 把正文文本里的 [图片] 字面占位，按顺序替换为正文图片块（对应 images[1..]）。
   *  第一个 [图片] 实际是答主头像（紧邻作者介绍文字），打 '__avatar__' 标记渲染成小圆形头像。 */
  private fillPlaceholders(blocks: HtmlBlock[], imgs: string[]): HtmlBlock[] {
    const out: HtmlBlock[] = [];
    let pi = 0;
    for (let i = 0; i < blocks.length; i++) {
      const b: HtmlBlock = blocks[i];
      if (b.type === 'text') {
        const parts: string[] = b.text.split('[图片]');
        for (let j = 0; j < parts.length; j++) {
          if (parts[j].length > 0) {
            out.push({ type: 'text', text: parts[j], url: '' });
          }
          if (j < parts.length - 1 && pi < imgs.length) {
            const tag: string = pi === 0 ? '__avatar__' : '';
            out.push({ type: 'image', text: tag, url: imgs[pi] });
            pi++;
          }
        }
      } else {
        out.push(b);
      }
    }
    return out;
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

  /** 用系统浏览器打开知乎讨论页 */
  private openZhihuDiscussion(): void {
    const url = this.detail?.share_url ?? '';
    if (url.length === 0) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const w: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url,
    };
    ctx.startAbility(w);
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
                .fontSize(21)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
                .width('100%')
              if (this.detail?.hint && this.detail.hint.length > 0) {
                Text(this.detail.hint)
                  .fontSize(15)
                  .fontColor(ZhihuColors.textSecondary)
                  .width('100%')
              }
              if (this.bodyBlocks.length > 0) {
                Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ top: 4, bottom: 4 })
                ForEach(this.bodyBlocks, (b: HtmlBlock) => {
                  if (b.type === 'text') {
                    Text(b.text)
                      .fontSize(19)
                      .lineHeight(28)
                      .fontColor(ZhihuColors.text)
                      .width('100%')
                  } else if (b.text === '__avatar__') {
                    // 答主头像：小圆形 48px
                    Row() {
                      NetImage({ url: b.url, w: 48, h: 48, r: 24 })
                    }
                    .width('100%')
                  } else {
                    NetImage({ url: b.url, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
                  }
                }, (b: HtmlBlock, i: number) => i.toString() + b.url + b.text.substring(0, 8))
              } else {
                Text('正文暂无法展示')
                  .fontSize(16)
                  .fontColor(ZhihuColors.textTertiary)
                  .width('100%')
                  .padding({ top: 20 })
              }
            }
            .padding({ left: 16, right: 16, top: 12, bottom: 24 })
            if (this.detail?.share_url && this.detail.share_url.length > 0) {
              Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ top: 8, bottom: 12 })
                .padding({ left: 16, right: 16 })
              Row() {
                Text('查看知乎讨论 ›')
                  .fontSize(15)
                  .fontColor(ZhihuColors.primary)
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 24 })
              .onClick(() => {
                this.openZhihuDiscussion();
              })
            }
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
