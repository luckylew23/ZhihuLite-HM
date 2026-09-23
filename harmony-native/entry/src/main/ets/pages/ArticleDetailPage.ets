/**
 * pages/ArticleDetailPage —— 专栏文章详情。
 * 上游：app/article/[id].tsx。
 * 结构：自绘导航栏 + 标题 + 作者 + 正文(纯文本降级) + 点赞/评论。
 * 降级：HTML 正文剥标签用 Text 渲染，不做 WebView；文章点赞仅展示计数（本期无 voteArticle 接口）。
 */

import hilog from '@ohos.hilog';
import { router, promptAction } from '@kit.ArkUI';
import { getArticle } from '../api/article';
import { getArticleCollectionStatus, removeArticleFromCollection } from '../api/collection';
import { ZhihuArticle } from '../model/zhihu';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { writeDebugLog } from '../utils/debugLog';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { NetImage } from '../components/NetImage';
import { formatCount, guardLogin, HtmlBlock, parseContent, readStringParam } from '../components/detail/detailUtils';
import { RichBody } from '../components/detail/RichBody';
import { common } from '@kit.AbilityKit';

@Entry
@Component
struct ArticleDetailPage {
  @State articleId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State article: ZhihuArticle | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
  @State collected: boolean = false;
  @State collectionId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';

  onCollectPicked(): void {
    if (this.collectPicked === this.articleId) {
      this.collected = true;
      this.collectPicked = '';
    }
  }

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.articleId = readStringParam(p, 'id');
    this.load();
  }

  private async refreshCollectionStatus(): Promise<void> {
    if (this.articleId.length === 0) {
      return;
    }
    try {
      const st = await getArticleCollectionStatus(this.articleId, 1);
      if (st.collected === true) {
        this.collected = true;
        const list = st.data ?? [];
        if (list.length > 0) {
          const first = list[0] as Record<string, object>;
          this.collectionId = String(first['id'] ?? '');
        }
      }
    } catch (e) {
    }
  }

  private async onCollect(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    if (this.collected) {
      if (this.collectionId.length === 0) {
        await this.refreshCollectionStatus();
        if (this.collectionId.length === 0) {
          promptAction.showToast({ message: '无法获取收藏夹信息' });
          return;
        }
      }
      try {
        await removeArticleFromCollection(this.collectionId, this.articleId);
        this.collected = false;
        this.collectionId = '';
        promptAction.showToast({ message: '已取消收藏' });
      } catch (e) {
        promptAction.showToast({ message: '取消收藏失败' });
      }
      return;
    }
    router.pushUrl({
      url: 'pages/CollectionPickerPage',
      params: { resourceType: 'article', resourceId: this.articleId },
    });
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const a: ZhihuArticle = await getArticle(this.articleId);
      this.article = a;
      this.bodyBlocks = parseContent(a.content);
      const actx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      writeDebugLog(actx, 'ARTICLE', 'id=' + this.articleId + ' len=' + a.content.length + ' preview=' + a.content.substring(0, 400));
      writeDebugLog(actx, 'ARTICLE', 'blocks=' + JSON.stringify(this.bodyBlocks.map((b: HtmlBlock) => b.type)));
      this.refreshCollectionStatus();
    } catch (e) {
      hilog.error(0x3100, 'ZhihuLiteDBG', 'ARTICLE load FAIL id=%{public}s err=%{public}s', this.articleId, JSON.stringify(e as object));
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private onComment(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',
      params: { resourceType: 'articles', resourceId: this.articleId },
    });
  }

  build() {
    Column() {
      DetailNavBar({ title: this.article ? this.article.title : '文章' })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ error: this.error, onRetry: () => { this.load(); } })
      } else if (this.article !== null) {
        Scroll() {
          Column({ space: 12 }) {
            Text(this.article.title)
              .fontSize(21)
              .fontWeight(FontWeight.Bold)
              .fontColor(ZhihuColors.text)
              .width('100%')
              .textAlign(TextAlign.Start)

            Row({ space: 10 }) {
              Image(this.article.author.avatar_url)
                .width(36).height(36).borderRadius(18)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
              Column({ space: 2 }) {
                Text(this.article.author.name)
                  .fontSize(16).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                Text(formatDate(this.article.created))
                  .fontSize(14).fontColor(ZhihuColors.textTertiary)
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
                NetImage({ url: b.url, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 6, tapView: true })
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
            Text(formatCount(this.article.voteup_count ?? 0))
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })

          Row({ space: 4 }) {
            Text('○')
              .fontSize(16)
              .fontColor(ZhihuColors.textTertiary)
            Text(formatCount(this.article.comment_count))
              .fontSize(15)
              .fontColor(ZhihuColors.textSecondary)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onComment();
          })

          Row({ space: 4 }) {
            Text(this.collected ? '★' : '☆')
              .fontSize(17)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
            Text(this.collected ? '已收藏' : '收藏')
              .fontSize(16)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center).padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onCollect();
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
