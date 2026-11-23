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
import { splitBack } from '../utils/contentOpener';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, HtmlBlock, parseContent, readStringParam, blocksToMarkdown, saveMarkdownToFile } from '../components/detail/detailUtils';
import { RichBody } from '../components/detail/RichBody';
import { DetailActionBar } from '../components/detail/DetailActionBar';

/** 想法详情视图（全屏页与宽屏右栏共用同一框架）。 */
@Component
export struct PinDetailView {
  @Prop @Watch('onIdChanged') pinId: string = '';
  @Prop inSplit: boolean = false;
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State pin: ZhihuPinDetail | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
  @State likeCount: number = 0;
  @State commentCount: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  onIdChanged(): void {
    this.load();
  }

  onRefreshTick(): void {
    this.load();
  }

  private goBack(): void {
    if (this.inSplit) {
      splitBack();
    } else {
      router.back();
    }
  }

  private async load(): Promise<void> {
    this.loading = true;
    hilog.info(0x3100, 'ZhihuLiteDBG', 'PIN load START id=%{public}s', this.pinId);
    this.error = '';
    try {
      const pin: ZhihuPinDetail = await getPin(this.pinId);
      this.pin = pin;
      const html: string = pin.content_html ?? pin.content ?? '';
      this.likeCount = this.pin.like_count ?? 0;
      this.commentCount = this.pin.comment_count ?? 0;
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

  private pinShareTitle(): string {
    const c: string = this.pin?.content ?? '';
    if (c.length > 50) {
      return c.substring(0, 50) + '…';
    }
    return c.length > 0 ? c : '知乎想法';
  }

  private async saveContent(): Promise<void> {
    if (this.bodyBlocks.length === 0) {
      return;
    }
    try {
      const title: string = this.pin?.author?.name ? ('想法_' + this.pin.author.name) : '想法';
      const md: string = blocksToMarkdown(this.bodyBlocks, title, '', 'https://www.zhihu.com/pin/' + this.pinId);
      await saveMarkdownToFile(getContext(this), title, md);
    } catch (e) {
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: '想法', onBack: (): void => { this.goBack(); } })

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

        // 操作条（公共组件，想法无反对/收藏）
        DetailActionBar({
          upvoted: false,
          downvoted: false,
          upvoteCount: this.likeCount,
          commentCount: this.commentCount,
          collected: false,
          showDownvote: false,
          showCollect: false,
          onUpvote: () => {},
          onDownvote: () => {},
          onComment: () => this.onComment(),
          onCollect: () => {},
          onSave: () => this.saveContent(),
          shareLink: 'https://www.zhihu.com/pin/' + this.pinId,
          shareTitle: this.pinShareTitle(),
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
    // 右滑返回：全屏 = router.back()；右栏 = splitBack() 逐层出栈。
    // PanGesture + 位移判断（SwipeGesture 有速度阈值，慢速拖动无法触发）：
    // 水平右移超过 60vp 且水平位移大于垂直位移才算右滑，避免与正文垂直滚动冲突。
    .gesture(
      PanGesture({ fingers: 1 })
        .onActionEnd((e: GestureEvent) => {
          if (e.offsetX > 60 && Math.abs(e.offsetX) > Math.abs(e.offsetY)) {
            this.goBack();
          }
        })
    )
  }
}


// ---------------------------------------------------------------------------
// 全屏壳页（路由 pages/PinDetailPage）
// ---------------------------------------------------------------------------

@Entry
@Component
struct PinDetailPage {
  @State pinIdParam: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.pinIdParam = readStringParam(p, 'id');
  }

  build() {
    Column() {
      PinDetailView({ pinId: this.pinIdParam, inSplit: false })
    }
    .width('100%')
    .height('100%')
  }
}
