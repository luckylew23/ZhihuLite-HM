/**
 * pages/CollectionDetailPage —— 单个收藏夹下内容（回答/文章/想法）列表。
 * 上游：app/collections/[id].tsx。
 * 入参：{ id: string }。
 */

import { router } from '@kit.ArkUI';
import { getCollection, getCollectionDetail } from '../api/collection';
import { ZhihuMemberRelation } from '../model/zhihu';
import { FeedItem } from '../api/feed';
import { ZhihuColors } from '../utils/theme';
import { FeedCard } from '../components/FeedCard';
import { ProfileTopBar } from '../components/profile/ProfileTopBar';
import { relationToFeedItem, feedDetailUrl } from '../components/profile/profileMappers';

@Entry
@Component
export struct CollectionDetailPage {
  @State collectionId: string = '';
  @State title: string = '';
  @State description: string = '';

  @State items: FeedItem[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;

  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p && p['id']) {
      this.collectionId = String(p['id']);
    }
    if (this.collectionId.length === 0) {
      this.loading = false;
      this.error = '缺少收藏夹标识';
      return;
    }
    this.loadAll();
  }

  async loadAll(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.items = [];
    this.pageOffset = 0;
    this.isEnd = false;
    // 头部信息（失败不阻断列表）
    try {
      const c = await getCollection(this.collectionId);
      const rec = c as Record<string, object>;
      this.title = rec['title'] ? String(rec['title']) : '收藏夹';
      this.description = rec['description'] ? String(rec['description']) : '';
    } catch (e) {
      this.title = '收藏夹';
    }
    await this.fetchPage(true);
    this.loading = false;
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd) {
      return;
    }
    this.loadingMore = true;
    await this.fetchPage(false);
    this.loadingMore = false;
  }

  async fetchPage(reset: boolean): Promise<void> {
    this.inFlight = true;
    try {
      const resp = await getCollectionDetail(this.collectionId, 20, this.pageOffset);
      const list: FeedItem[] = [];
      for (const raw of resp.data) {
        const rec = raw as Record<string, object>;
        // 上游 item.content 为回答/文章/想法对象；个别接口直接返回 content 本身
        const contentObj = rec['content'] ? rec['content'] : raw;
        const rel = contentObj as ZhihuMemberRelation;
        if (rel && rel.id !== undefined) {
          list.push(relationToFeedItem(rel));
        }
      }
      this.items = reset ? list : this.items.concat(list);
      this.isEnd = resp.paging.is_end;
      this.pageOffset = this.pageOffset + 20;
    } catch (e) {
      this.error = '收藏内容加载失败';
    } finally {
      this.inFlight = false;
    }
  }

  private openDetail(item: FeedItem): void {
    router.pushUrl({
      url: feedDetailUrl(item),
      params: { id: item.id, questionId: item.questionId ?? '' },
    });
  }

  @Builder
  headerBlock() {
    Column({ space: 6 }) {
      Text(this.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.text)
        .width('100%')
      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(14)
          .fontColor(ZhihuColors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…')
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      }
    }
  }

  build() {
    Column() {
      ProfileTopBar({ title: this.title.length > 0 ? this.title : '收藏夹' })
      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…')
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.items.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
          Button('重试')
            .fontSize(15).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadAll();
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        this.headerBlock()
        if (this.items.length === 0) {
          Column() {
            Text('这个收藏夹空空如也')
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          List({ scroller: this.scroller }) {
            ForEach(this.items, (item: FeedItem, idx: number) => {
              ListItem() {
                FeedCard({ item: item })
              }
              .onClick(() => {
                this.openDetail(item);
              })
            }, (item: FeedItem, idx: number) => String(idx) + '-' + item.id)
            ListItem() {
              this.footer()
            }
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onReachEnd(() => {
            this.loadMore();
          })
          .scrollBar(BarState.Off)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
