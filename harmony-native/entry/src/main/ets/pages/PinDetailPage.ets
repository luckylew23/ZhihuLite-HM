/**
 * pages/PinDetailPage —— 想法（图文）详情。
 * 上游：app/pin/[id].tsx。
 * 结构：自绘导航栏 + 作者 + 正文纯文本 + 正文内图片 + 点赞/评论。
 * 降级：HTML 正文剥标签为纯文本；图片从 content_html 的 <img src> 抽取后单独渲染。
 */

import hilog from '@ohos.hilog';
import { router } from '@kit.ArkUI';
import { NetImage } from '../components/NetImage';
import { getPin, ZhihuPinDetail } from '../api/pin';
import { ZhihuColors } from '../utils/theme';
import { formatDateTime } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, HtmlBlock, parseContent, readStringParam, blocksToMarkdown, saveMarkdownToFile } from '../components/detail/detailUtils';
import { RichBody } from '../components/detail/RichBody';

@Entry
@Component
struct PinDetailPage {
  @State pinId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State pin: ZhihuPinDetail | null = null;
  @State bodyBlocks: HtmlBlock[] = [];

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.pinId = readStringParam(p, 'id');
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    hilog.info(0x3100, 'ZhihuLiteDBG', 'PIN load START id=%{public}s', this.pinId);
    this.error = '';
    try {
      const pin: ZhihuPinDetail = await getPin(this.pinId);
      this.pin = pin;
      const html: string = pin.content_html ?? pin.content ?? '';
      this.bodyBlocks = parseContent(html);
    } catch (e) {
      hilog.error(0x3100, 'ZhihuLiteDBG', 'PIN load FAIL id=%{public}s err=%{public}s', this.pinId, JSON.stringify(e as object));
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private onComment(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',
      params: { resourceType: 'pins', resourceId: this.pinId },
    });
  }

  private async saveContent(): Promise<void> {
    if (this.bodyBlocks.length === 0) {
      return;
    }
    try {
      const title: string = this.pin?.author?.name ? ('想法_' + this.pin.author.name) : '想法';
      const md: string = blocksToMarkdown(this.bodyBlocks, title, '');
      await saveMarkdownToFile(getContext(this), title, md);
    } catch (e) {
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: '想法' })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ error: this.error, onRetry: () => { this.load(); } })
      } else if (this.pin !== null && this.pin.author !== undefined) {
        Scroll() {
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              Image(this.pin.author.avatar_url).onClick(() => { const author = this.pin?.author; if (author) { const token = author.url_token || author.id; if (token) { router.pushUrl({ url: 'pages/PeoplePage', params: { urlToken: token } }); } } })
                .width(40).height(40).borderRadius(20)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
              Column({ space: 2 }) {
                Text(this.pin.author.name)
                  .fontSize(17).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                if (this.pin.created && this.pin.created > 0) {
                  Text(formatDateTime(this.pin.created))
                    .fontSize(14).fontColor(ZhihuColors.textTertiary)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            // 正文（结构化富文本）
            RichBody({ blocks: this.bodyBlocks })
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(ZhihuColors.backgroundSecondary)

        Row({ space: 4 }) {
          Row({ space: 4 }) {
            Text('▲')
            Text(formatCount(this.pin.like_count ?? 0))
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })

          Row({ space: 4 }) {
            Text('○')
            Text(formatCount(this.pin.comment_count ?? 0))
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onComment();
          })

          Row({ space: 4 }) {
            Text('⇩')
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })
          .onClick(() => this.saveContent())
        }
        .width('100%')
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .border({ width: { top: 0.5 }, color: ZhihuColors.border })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
