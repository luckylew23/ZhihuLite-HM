/**
 * pages/VotersPage —— 赞同用户列表（独立页面）。
 * 上游：components/VoterListModal.tsx（原为 BottomSheet，此处作为全屏页）。
 * 入参：{ contentType: 'answer'|'pin', contentId: string, count?: number }。
 */

import { router } from '@kit.ArkUI';
import {
  ZhihuVoter,
  getAnswerVoters,
  getPinVoters,
} from '../api/voters';
import { ZhihuColors } from '../utils/theme';
import { ProfileTopBar } from '../components/profile/ProfileTopBar';
import { MemberRow } from '../components/profile/MemberRow';

@Entry
@Component
export struct VotersPage {
  @State contentType: string = 'answer';
  @State contentId: string = '';
  @State count: string = '';
  @State items: ZhihuVoter[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;

  pageOffset: number = 0;
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      this.contentType = p['contentType'] ? String(p['contentType']) : 'answer';
      this.contentId = p['contentId'] ? String(p['contentId']) : '';
      this.count = p['count'] ? String(p['count']) : '';
    }
    if (this.contentId.length === 0) {
      this.loading = false;
      this.error = '缺少内容标识';
      return;
    }
    this.loadFirst();
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.items = [];
    this.pageOffset = 0;
    this.isEnd = false;
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

  private async fetchPage(reset: boolean): Promise<void> {
    this.inFlight = true;
    try {
      const resp = this.contentType === 'pin'
        ? await getPinVoters(this.contentId, 20, this.pageOffset)
        : await getAnswerVoters(this.contentId, 20, this.pageOffset);
      const merged = reset ? resp.data.slice() : this.items.concat(resp.data);
      this.items = this.dedup(merged);
      this.isEnd = resp.paging ? (resp.paging.is_end ?? false) : true;
      this.pageOffset = this.pageOffset + resp.data.length;
    } catch (e) {
      this.error = '赞同者加载失败';
    } finally {
      this.inFlight = false;
    }
  }

  private dedup(list: ZhihuVoter[]): ZhihuVoter[] {
    const seen: string[] = [];
    const out: ZhihuVoter[] = [];
    for (const v of list) {
      const key = String(v.id);
      if (seen.indexOf(key) < 0) {
        seen.push(key);
        out.push(v);
      }
    }
    return out;
  }

  private titleText(): string {
    if (this.count.length > 0) {
      return this.count + ' 人赞同';
    }
    return '赞同者';
  }

  @Builder
  footer() {
    Column() {
      if (this.loadingMore) {
        Row({ space: 8 }) {
          LoadingProgress().width(18).height(18).color(ZhihuColors.textTertiary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .justifyContent(FlexAlign.Center).width('100%').padding(12)
      }
    }
  }

  build() {
    Column() {
      ProfileTopBar({ title: this.titleText() })
      if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(48).height(48).color(ZhihuColors.primary)
          Text('加载中…').fontSize(13).fontColor(ZhihuColors.textTertiary)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.items.length === 0) {
        Column({ space: 16 }) {
          Text(this.error).fontSize(14).fontColor(ZhihuColors.textSecondary)
          Button('重试')
            .fontSize(14).backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadFirst();
            })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          Text('还没有公开的赞同者').fontSize(14).fontColor(ZhihuColors.textTertiary)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller }) {
          ForEach(this.items, (v: ZhihuVoter, idx: number) => {
            ListItem() {
              MemberRow({
                name: v.name,
                avatar: v.avatar_url ?? '',
                headline: v.headline ?? '',
                urlToken: v.url_token ?? v.id,
              })
            }
          }, (v: ZhihuVoter, idx: number) => String(v.id))
          ListItem() {
            this.footer()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .onReachEnd(() => {
          this.loadMore();
        })
        .scrollBar(BarState.Off)
        Text('赞同者列表由知乎接口返回，可能受隐私设置影响')
          .fontSize(12)
          .fontColor(ZhihuColors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding(8)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
