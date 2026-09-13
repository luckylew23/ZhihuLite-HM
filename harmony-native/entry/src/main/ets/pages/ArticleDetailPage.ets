/**
 * pages/ArticleDetailPage —— 专栏文章详情。
 * 上游：app/article/[id].tsx。
 * 结构：自绘导航栏 + 标题 + 作者 + 正文(纯文本降级) + 点赞/评论。
 * 降级：HTML 正文剥标签用 Text 渲染，不做 WebView；文章点赞仅展示计数（本期无 voteArticle 接口）。
 */

import { router } from '@kit.ArkUI';
import { getArticle } from '../api/article';
import { ZhihuArticle } from '../model/zhihu';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, readStringParam, stripHtml } from '../components/detail/detailUtils';

@Entry
@Component
struct ArticleDetailPage {
  @State articleId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State article: ZhihuArticle | null = null;
  private bodyText: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.articleId = readStringParam(p, 'id');
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const a: ZhihuArticle = await getArticle(this.articleId);
      this.article = a;
      this.bodyText = stripHtml(a.content);
    } catch (e) {
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
                  .fontSize(15).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                Text(formatDate(this.article.created))
                  .fontSize(13).fontColor(ZhihuColors.textTertiary)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            Text(this.bodyText)
          .copyOption(CopyOptions.LocalDevice)
              .fontSize(17)
              .fontColor(ZhihuColors.text)
              .lineHeight(26)
              .width('100%')
              .textAlign(TextAlign.Start)
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
            Text('💬')
            Text(formatCount(this.article.comment_count))
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
