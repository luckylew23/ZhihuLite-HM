/**
 * pages/PinDetailPage —— 想法（图文）详情。
 * 上游：app/pin/[id].tsx。
 * 结构：自绘导航栏 + 作者 + 正文纯文本 + 正文内图片 + 点赞/评论。
 * 降级：HTML 正文剥标签为纯文本；图片从 content_html 的 <img src> 抽取后单独渲染。
 */

import { router } from '@kit.ArkUI';
import { NetImage } from '../components/NetImage';
import { getPin, ZhihuPinDetail } from '../api/pin';
import { ZhihuColors } from '../utils/theme';
import { formatDateTime } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, HtmlBlock, parseHtmlBlocks, readStringParam } from '../components/detail/detailUtils';

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
    this.error = '';
    try {
      const pin: ZhihuPinDetail = await getPin(this.pinId);
      this.pin = pin;
      const html: string = pin.content_html ?? pin.content ?? '';
      this.bodyBlocks = parseHtmlBlocks(html);
    } catch (e) {
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
              Image(this.pin.author.avatar_url)
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

            ForEach(this.bodyBlocks, (b: HtmlBlock) => {
              if (b.type === 'text') {
                Text(b.text)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(20)
                  .fontColor(ZhihuColors.text)
                  .lineHeight(30)
                  .width('100%')
                  .textAlign(TextAlign.Start)
              } else {
                NetImage({ url: b.url, w: 0, h: 280, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
              }
            }, (b: HtmlBlock, i: number) => i.toString() + b.url + b.text.substring(0, 8))
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
