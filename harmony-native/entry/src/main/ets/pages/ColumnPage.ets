/**
 * pages/ColumnPage —— 专栏详情（按 Android v0.6.0 截图 08 重构布局）。
 * 上游：app/column/[id].tsx。
 * 头部：大圆角头像 + 专栏名 + 「N 关注者 · M 文章」+ 右侧「已关注/关注」描边胶囊按钮
 *       + 简介 + 创建人(小头像 + 创建人: 名字)；
 * 文章列表：标题 + 摘要 + 「N 赞同  M 评论」+ 右侧日期。
 */

import { router } from '@kit.ArkUI';
import {
  getColumn,
  getColumnItems,
  followColumn,
  unfollowColumn,
  ZhihuColumnItemsResponse,
} from '../api/column';
import { ZhihuColumnDetail } from '../model/zhihu';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import {
  formatCount,
  guardLogin,
  readStringParam,
  stripHtml,
} from '../components/detail/detailUtils';

/** 专栏 item：getColumnItems 返回 object[]，按上游渲染形状本地收窄。 */
interface ColumnArticleItem {
  id: string | number;
  title: string;
  excerpt: string;
  title_image: string;
  voteup_count: number;
  comment_count: number;
  updated: number;
}

function toColumnArticleItem(raw: object): ColumnArticleItem {
  const r = raw as Record<string, object>;
  const idRaw: object | undefined = r['id'];
  const titleRaw: object | undefined = r['title'];
  const excerptRaw: object | undefined = r['excerpt'];
  const imageRaw: object | undefined = r['title_image'];
  const voteRaw: object | undefined = r['voteup_count'];
  const commentRaw: object | undefined = r['comment_count'];
  const updatedRaw: object | undefined = r['updated'];
  return {
    id: idRaw === undefined ? '' : String(idRaw),
    title: titleRaw === undefined ? '' : String(titleRaw),
    excerpt: excerptRaw === undefined ? '' : stripHtml(String(excerptRaw)),
    title_image: imageRaw === undefined ? '' : String(imageRaw),
    voteup_count: voteRaw === undefined ? 0 : Number(voteRaw),
    comment_count: commentRaw === undefined ? 0 : Number(commentRaw),
    updated: updatedRaw === undefined ? 0 : Number(updatedRaw),
  };
}

@Entry
@Component
struct ColumnPage {
  @State columnId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State column: ZhihuColumnDetail | null = null;
  @State following: boolean = false;
  @State followerCount: number = 0;

  @State articles: ColumnArticleItem[] = [];
  @State itemsLoading: boolean = false;
  @State isEnd: boolean = false;
  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.columnId = readStringParam(p, 'id');
    this.loadColumn();
    this.loadItems(true);
  }

  private async loadColumn(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const c: ZhihuColumnDetail = await getColumn(this.columnId);
      this.column = c;
      this.following = c.is_following ?? false;
      this.followerCount = c.followers ?? 0;
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private async loadItems(reset: boolean): Promise<void> {
    if (this.inFlight) {
      return;
    }
    this.inFlight = true;
    if (reset) {
      this.pageOffset = 0;
      this.isEnd = false;
      this.itemsLoading = true;
    }
    try {
      const resp: ZhihuColumnItemsResponse = await getColumnItems(this.columnId, 20, this.pageOffset);
      const list: ColumnArticleItem[] = [];
      for (const raw of resp.data) {
        list.push(toColumnArticleItem(raw));
      }
      this.articles = reset ? list : this.articles.concat(list);
      this.pageOffset = this.pageOffset + 20;
      this.isEnd = resp.paging.is_end;
    } catch (e) {
      // 翻页失败保留已加载
    } finally {
      this.inFlight = false;
      this.itemsLoading = false;
    }
  }

  private async toggleFollow(): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    const prev: boolean = this.following;
    const prevCount: number = this.followerCount;
    this.following = !prev;
    this.followerCount = prev ? Math.max(0, prevCount - 1) : prevCount + 1;
    try {
      if (prev) {
        await unfollowColumn(this.columnId);
      } else {
        await followColumn(this.columnId);
      }
    } catch (e) {
      this.following = prev;
      this.followerCount = prevCount;
    }
  }

  private openArticle(item: ColumnArticleItem): void {
    router.pushUrl({ url: 'pages/ArticleDetailPage', params: { id: String(item.id) } });
  }

  @Builder
  headerContent() {
    Column({ space: 12 }) {
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(20).height(20).color(ZhihuColors.primary)
          Text('专栏加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(24)
      } else if (this.error.length > 0) {
        Column({ space: 12 }) {
          Text(this.error)
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textSecondary)
          Button('重试').fontSize(13).backgroundColor(ZhihuColors.primary)
            .onClick(() => { this.loadColumn(); })
        }
        .width('100%').padding(20)
      } else if (this.column !== null) {
        // 头像 + 名称/统计 + 关注按钮
        Row({ space: 12 }) {
          Image(this.column.image_url)
            .width(88).height(88).borderRadius(12)
            .objectFit(ImageFit.Cover)
            .backgroundColor(ZhihuColors.backgroundTertiary)
          Column({ space: 6 }) {
            Text(this.column.title)
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ZhihuColors.text)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(formatCount(this.followerCount) + ' 关注者 · ' +
              formatCount(this.column.items_count ?? this.column.articles_count ?? 0) + ' 文章')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13).fontColor(ZhihuColors.textSecondary)
          }
          .alignItems(HorizontalAlign.Start).layoutWeight(1)
          Text(this.following ? '已关注' : '关注')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13).fontWeight(FontWeight.Medium)
            .fontColor(this.following ? ZhihuColors.textSecondary : ZhihuColors.primary)
            .height(34)
            .padding({ left: 16, right: 16 })
            .borderRadius(17)
            .backgroundColor(ZhihuColors.backgroundSecondary)
            .border({ width: 1, color: this.following ? ZhihuColors.border : ZhihuColors.primary })
            .onClick(() => { this.toggleFollow(); })
        }
        .width('100%').alignItems(VerticalAlign.Center)

        // 简介
        if ((this.column.intro ?? '').length > 0) {
          Text(stripHtml(this.column.intro ?? ''))
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14).fontColor(ZhihuColors.textSecondary).lineHeight(21)
            .width('100%').textAlign(TextAlign.Start)
        }

        // 创建人
        if (this.column.author !== undefined && this.column.author.name.length > 0) {
          Row({ space: 8 }) {
            Image(this.column.author.avatar_url)
              .width(20).height(20).borderRadius(10)
              .objectFit(ImageFit.Cover)
              .backgroundColor(ZhihuColors.backgroundTertiary)
            Row({ space: 4 }) {
              Text('创建人:')
                .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
              Text(this.column.author.name)
                .copyOption(CopyOptions.LocalDevice)
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
            }
          }
          .width('100%')
        }
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  articleItem(item: ColumnArticleItem) {
    Column({ space: 8 }) {
      Text(item.title)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ZhihuColors.text)
        .maxLines(2).lineHeight(24)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(item.excerpt)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(14).fontColor(ZhihuColors.textSecondary).lineHeight(21)
        .maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: 16 }) {
        Text(formatCount(item.voteup_count) + ' 赞同')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(12).fontColor(ZhihuColors.textTertiary)
        Text(formatCount(item.comment_count) + ' 评论')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(12).fontColor(ZhihuColors.textTertiary)
        Blank()
        if (item.updated > 0) {
          Text(formatDate(item.updated))
            .copyOption(CopyOptions.LocalDevice).fontSize(12).fontColor(ZhihuColors.textTertiary)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => { this.openArticle(item); })
  }

  @Builder
  footer() {
    Column() {
      if (this.itemsLoading && this.articles.length > 0) {
        Row({ space: 8 }) {
          LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      } else if (this.isEnd && this.articles.length > 0) {
        Text('— 没有更多文章了 —')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13).fontColor(ZhihuColors.textTertiary)
          .width('100%').textAlign(TextAlign.Center).padding(12)
      }
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: this.column ? this.column.title : '专栏' })

      List({ space: 8, scroller: this.scroller }) {
        ListItem() {
          this.headerContent()
        }

        ForEach(this.articles, (item: ColumnArticleItem) => {
          ListItem() {
            this.articleItem(item)
          }
        }, (item: ColumnArticleItem) => String(item.id))

        ListItem() {
          this.footer()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .onReachEnd(() => { this.loadItems(false); })
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
