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
import { openZhihuUrl } from '../utils/zhihuRouter';

@Entry
@Component
struct DailyDetailPage {
  @State storyId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State detail: DailyDetailResponse | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
  @State originUrl: string = '';
  @State discussionUrl: string = '';
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
      // 提取 <a class="originUrl" href="...">查看知乎原文</a> 的真实链接（知乎主站 answer/question）
      const ou: RegExpExecArray | null = /<a[^>]*href="([^"]+)"[^>]*class="[^"]*originUrl[^"]*"[^>]*>/i.exec(d.body) || /<a[^>]*class="[^"]*originUrl[^"]*"[^>]*href="([^"]+)"/i.exec(d.body);
      if (ou !== null) {
        this.originUrl = ou[1];
      }
      // 提取 <div class="view-more"><a href="...">查看知乎讨论</a></div> 的真实链接
      const vm: RegExpExecArray | null = /<div[^>]*class="[^"]*view-more[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"/i.exec(d.body);
      if (vm !== null) {
        this.discussionUrl = vm[1];
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

  /** app 内打开知乎原文/讨论页（解析 URL 路由到原生详情页；识别不了才回退浏览器） */
  private getAuthorText(idx: number): string {
    if (idx + 1 < this.bodyBlocks.length && this.bodyBlocks[idx + 1].type === 'text') {
      return this.bodyBlocks[idx + 1].text;
    }
    return '';
  }

  private isAuthorText(idx: number): boolean {
    return idx > 0 && this.bodyBlocks[idx - 1].type === 'image' && this.bodyBlocks[idx - 1].text === '__avatar__';
  }

  private openOriginArticle(): void {
    if (this.originUrl.length === 0) return;
    if (openZhihuUrl(this.originUrl)) return;
    const ctx = getContext(this) as common.UIAbilityContext;
    const w: Want = { action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: this.originUrl };
    ctx.startAbility(w);
  }

  private openZhihuDiscussion(): void {
    // 查看知乎讨论 → 打开 question 详情页（app 内）
    const url: string = this.discussionUrl.length > 0 ? this.discussionUrl : (this.originUrl.length > 0 ? this.originUrl : (this.detail?.share_url ?? ''));
    if (url.length === 0) {
      return;
    }
    if (openZhihuUrl(url)) {
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
                ForEach(this.bodyBlocks, (b: HtmlBlock, idx: number) => {
                  if (b.type === 'image' && b.text === '__avatar__') {
                    Row({ space: 10 }) {
                      NetImage({ url: b.url, w: 48, h: 48, r: 24 })
                      Column() {
                        Text(this.getAuthorText(idx))
                          .fontSize(15)
                          .fontColor(ZhihuColors.textSecondary)
                          .maxLines(2)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                      .layoutWeight(1)
                      if (this.originUrl.length > 0) {
                        Text('查看知乎原文 ›')
                          .fontSize(14)
                          .fontColor(ZhihuColors.primary)
                          .onClick(() => this.openOriginArticle())
                      }
                    }
                    .width('100%')
                  } else if (b.type === 'image') {
                    NetImage({ url: b.url, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
                  } else if (b.type === 'heading') {
                    Text(b.text)
                      .fontSize(b.level !== undefined && b.level <= 2 ? 22 : 20)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(ZhihuColors.text)
                      .width('100%')
                      .margin({ top: 8, bottom: 4 })
                  } else if (b.type === 'quote') {
                    Text(b.text)
                      .fontSize(18)
                      .lineHeight(26)
                      .fontColor(ZhihuColors.textSecondary)
                      .fontStyle(FontStyle.Italic)
                      .width('100%')
                      .padding({ left: 12, top: 4, bottom: 4 })
                      .borderWidth({ left: 3 })
                      .borderColor({ left: ZhihuColors.primary })
                  } else if (b.type === 'code') {
                    Text(b.text)
                      .fontSize(16)
                      .lineHeight(24)
                      .fontColor(ZhihuColors.text)
                      .width('100%')
                      .padding(10)
                      .backgroundColor(ZhihuColors.backgroundSecondary)
                  } else if (b.type === 'list') {
                    Text('· ' + b.text)
                      .fontSize(19)
                      .lineHeight(28)
                      .fontColor(ZhihuColors.text)
                      .width('100%')
                  } else {
                    Text(b.text)
                      .fontSize(19)
                      .lineHeight(28)
                      .fontColor(ZhihuColors.text)
                      .width('100%')
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
              Text('查看知乎讨论 ›')
                .fontSize(15)
                .fontColor(ZhihuColors.primary)
                .width('100%')
                .onClick(() => this.openZhihuDiscussion())
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 24 })
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
