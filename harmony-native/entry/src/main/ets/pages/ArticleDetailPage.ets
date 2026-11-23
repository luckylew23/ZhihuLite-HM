/**
 * pages/ArticleDetailPage —— 专栏文章详情。
 * 上游：app/article/[id].tsx。
 * 结构：自绘导航栏 + 标题 + 作者 + 正文(纯文本降级) + 点赞/评论。
 * 降级：HTML 正文剥标签用 Text 渲染，不做 WebView；文章点赞走 POST /articles/{id}/voters {voting:1}。
 */

import hilog from '@ohos.hilog';
import { router, promptAction } from '@kit.ArkUI';
import { getArticle, voteArticle } from '../api/article';
import { readContentCache, writeContentCache } from '../utils/cacheStore';

import { getArticleCollectionStatus, removeArticleFromCollection } from '../api/collection';
import { ZhihuArticle } from '../model/zhihu';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { writeDebugLog } from '../utils/debugLog';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { splitBack } from '../utils/contentOpener';
import { StatusView } from '../components/detail/StatusView';
import { NetImage } from '../components/NetImage';
import { formatCount, guardLogin, HtmlBlock, parseContent, readStringParam, blocksToMarkdown, saveMarkdownToFile } from '../components/detail/detailUtils';
import { RichBody } from '../components/detail/RichBody';
import { DetailActionBar } from '../components/detail/DetailActionBar';
import { contentVotingOf } from '../utils/voteState';
import { common } from '@kit.AbilityKit';


interface CachedArticle { savedAt: number; data: ZhihuArticle; }

/** 文章详情视图（全屏页与宽屏右栏共用同一框架）。 */
@Component
export struct ArticleDetailView {
  @Prop @Watch('onIdChanged') articleId: string = '';
  @Prop inSplit: boolean = false;
  @Prop @Watch('onRefreshTick') refreshTick: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State article: ZhihuArticle | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
  @State collected: boolean = false;
  @State upvoted: boolean = false;
  @State upCount: number = 0;
  @State ccCount: number = 0;
  @State collectionId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';

  onCollectPicked(): void {
    const prefix: string = this.articleId + ':';
    if (this.collectPicked.startsWith(prefix)) {
      const flag: string = this.collectPicked.substring(prefix.length);
      this.collected = flag === 'true';
      this.collectPicked = '';
    }
  }

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

  private async refreshCollectionStatus(): Promise<void> {
    if (this.articleId.length === 0) {
      return;
    }
    try {
      const st = await getArticleCollectionStatus(this.articleId, 1);
      // 知乎状态接口返回全部收藏夹列表；已收藏 = 顶层 collected 为 true 或列表中任一项 is_favorited
      const list = st.data ?? [];
      let fav = false;
      for (const it of list) {
        const rec = it as Record<string, object>;
        const favStr: string = String(rec['is_favorited']);
        if (favStr === 'true' || favStr === '1') {
          fav = true;
          break;
        }
      }
      if (st.collected === true || fav) {
        this.collected = true;
        if (list.length > 0) {
          const first = list[0] as Record<string, object>;
          this.collectionId = String(first['id'] ?? '');
        }
      }
    } catch (e) {
    }
  }

  private onCollect(): void {
    if (!guardLogin()) {
      return;
    }
    router.pushUrl({
      url: 'pages/CollectionPickerPage',
      params: { resourceType: 'article', resourceId: this.articleId },
    });
  }

  private async saveContent(): Promise<void> {
    if (this.bodyBlocks.length === 0) {
      promptAction.showToast({ message: '内容为空，无法保存' });
      return;
    }
    try {
      const title: string = this.article?.title ?? ('文章_' + this.articleId);
      const author: string = this.article?.author?.name ?? '';
      const md: string = blocksToMarkdown(this.bodyBlocks, title, author, 'https://zhuanlan.zhihu.com/p/' + this.articleId);
      await saveMarkdownToFile(getContext(this), title, md);
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '保存失败: ' + errMsg.substring(0, 50) });
    }
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    let hadCache: boolean = false;
    const cached = readContentCache<CachedArticle>('article', this.articleId);
    if (cached) {
      const a = cached.data;
      this.article = a;
      this.upCount = a.voteup_count ?? 0;
      this.upvoted = contentVotingOf(a) === 1;
      this.ccCount = a.comment_count ?? 0;
      this.bodyBlocks = parseContent(a.content);
      this.loading = false;
      this.refreshCollectionStatus();
      hadCache = true;
    }
    try {
      const a: ZhihuArticle = await getArticle(this.articleId);
      this.article = a;
      this.upCount = a.voteup_count ?? 0;
      this.upvoted = contentVotingOf(a) === 1;
      this.ccCount = a.comment_count ?? 0;
      this.bodyBlocks = parseContent(a.content);
      writeContentCache('article', this.articleId, a as object);
      this.refreshCollectionStatus();
    } catch (e) {
      if (!hadCache) {
        this.error = getZhihuErrorMessage(e as object);
      }
    } finally {
      this.loading = false;
    }
  }

  /** 文章点赞：再点一次取消。失败时回滚并 toast 具体原因。 */
  private async onVote(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    const prevUp: boolean = this.upvoted;
    const prevCount: number = this.upCount;
    this.upvoted = !prevUp;
    this.upCount = this.upvoted ? prevCount + 1 : Math.max(0, prevCount - 1);
    const next: 1 | 0 = this.upvoted ? 1 : 0;
    try {
      await voteArticle(this.articleId, next);
    } catch (e) {
      this.upvoted = prevUp;
      this.upCount = prevCount;
      promptAction.showToast({ message: '点赞失败：' + getZhihuErrorMessage(e as object), duration: 2000 });
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
      DetailNavBar({ title: this.article ? this.article.title : '文章', onBack: (): void => { this.goBack(); } })

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
              Image(this.article.author.avatar_url).onClick(() => { const author = this.article?.author; if (author) { const token = author.url_token || author.id; if (token) { router.pushUrl({ url: 'pages/PeoplePage', params: { urlToken: token } }); } } })
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

            RichBody({ blocks: this.bodyBlocks })
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(ZhihuColors.backgroundSecondary)

        DetailActionBar({
          upvoted: this.upvoted,
          upvoteCount: this.upCount,
          commentCount: this.ccCount,
          collected: this.collected,
          showDownvote: false,
          onUpvote: () => this.onVote(),
          onComment: () => this.onComment(),
          onCollect: () => this.onCollect(),
          onSave: () => this.saveContent(),
          shareLink: 'https://zhuanlan.zhihu.com/p/' + this.articleId,
          shareTitle: this.article?.title ?? '知乎文章',
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
// 全屏壳页（路由 pages/ArticleDetailPage）
// ---------------------------------------------------------------------------

@Entry
@Component
struct ArticleDetailPage {
  @State articleIdParam: string = '';
  @State refreshTick: number = 0;
  private shownOnce: boolean = false;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.articleIdParam = readStringParam(p, 'id');
  }

  onPageShow(): void {
    if (this.shownOnce) {
      this.refreshTick++;
    }
    this.shownOnce = true;
  }

  build() {
    Column() {
      ArticleDetailView({ articleId: this.articleIdParam, inSplit: false, refreshTick: this.refreshTick })
    }
    .width('100%')
    .height('100%')
  }
}
