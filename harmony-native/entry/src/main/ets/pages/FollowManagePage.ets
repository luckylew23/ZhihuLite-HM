/**
 * pages/FollowManagePage —— 关注管理（对齐 Android v0.6.0 截图 07）。
 * 顶部标题「关注」+ 五子 tab：关注的人 / 专栏 / 话题 / 问题 / 收藏夹。
 * 条目层级统一：头像 + 名称 + 简介 + 右侧「已关注」+ 关注者数/回答数。
 * 数据：
 *   关注的人 → api/member.getMemberFollowing(meId)
 *   收藏夹   → api/collection.getMyCollections()
 *   专栏/话题/问题 → 直接打 /api/v4/members/{meId}/... 端点（现有 api 文件无对应列表函数，
 *                    缺失/失败时优雅降级为空态「暂无数据」）。
 * 路由注册名固定：pages/FollowManagePage。
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ZhihuColors } from '../utils/theme';
import { settingsStore } from '../store/settingsStore';
import { getMe } from '../api/me';
import { getMemberFollowing, ZhihuMemberListItem } from '../api/member';
import { getMyCollections, ZhihuCollection } from '../api/collection';
import { zhihuClient } from '../api/httpClient';

interface FollowTab {
  label: string;
}

interface FollowTabItem {
  key: string;
  name: string;
  intro: string;
  avatar: string;
  meta: string;
  id?: string;
}

interface ColumnListItem {
  id?: string | number;
  title?: string;
  intro?: string;
  image_url?: string;
  followers?: number;
  articles_count?: number;
}

interface TopicListItem {
  name?: string;
  introduction?: string;
  avatar_url?: string;
  followers_count?: number;
  questions_count?: number;
}

interface QuestionListItem {
  id?: string | number;
  title?: string;
  answer_count?: number;
  follower_count?: number;
}

// ArkTS 禁止把匿名对象字面量当泛型类型参数（arkts-no-obj-literals-as-types），
// 故为 /api/v4 列表响应急需具名包装接口。
interface ColumnListResponse {
  data?: ColumnListItem[];
}

interface TopicListResponse {
  data?: TopicListItem[];
}

interface QuestionListResponse {
  data?: QuestionListItem[];
}

const TABS: FollowTab[] = [
  { label: '关注的人' },
  { label: '专栏' },
  { label: '话题' },
  { label: '问题' },
  { label: '收藏夹' },
];

const API_V4: string = 'https://www.zhihu.com/api/v4';

@Entry
@Component
struct FollowManagePage {
  @State currentTab: number = 0;
  @State items: FollowTabItem[] = [];
  @State loading: boolean = false;
  private loadedTabs: boolean[] = [false, false, false, false, false];
  private meId: string = '';

  aboutToAppear(): void {
    settingsStore.init(getContext(this) as common.UIAbilityContext);
    this.bootstrap();
  }

  async bootstrap(): Promise<void> {
    try {
      const me = await getMe();
      this.meId = me.id;
    } catch (e) {
      this.meId = 'me';
    }
    await this.loadTab(0);
  }

  private switchTab(index: number): void {
    if (index === this.currentTab && this.loadedTabs[index]) {
      return;
    }
    this.currentTab = index;
    if (!this.loadedTabs[index]) {
      this.loadTab(index);
    }
  }

  async loadTab(index: number): Promise<void> {
    this.loading = true;
    try {
      let list: FollowTabItem[] = [];
      if (index === 0) {
        list = await this.loadFollowingPeople();
      } else if (index === 1) {
        list = await this.loadColumns();
      } else if (index === 2) {
        list = await this.loadTopics();
      } else if (index === 3) {
        list = await this.loadQuestions();
      } else {
        list = await this.loadCollections();
      }
      this.items = list;
      this.loadedTabs[index] = true;
    } catch (e) {
      this.items = [];
      this.loadedTabs[index] = true;
    }
    this.loading = false;
  }

  private async loadFollowingPeople(): Promise<FollowTabItem[]> {
    const res = await getMemberFollowing(this.meId, 30, 0);
    const out: FollowTabItem[] = [];
    for (const m of res.data) {
      out.push({
        key: String(m.id),
        name: m.name,
        intro: m.headline ?? '',
        avatar: m.avatar_url ?? '',
        meta: this.metaOf(m.follower_count, m.answer_count),
      });
    }
    return out;
  }

  private async loadColumns(): Promise<FollowTabItem[]> {
    const url = API_V4 + '/members/' + encodeURIComponent(this.meId) +
      '/columns?include=data[*].intro,followers,articles_count,is_following' +
      '&limit=20&offset=0';
    const res = await zhihuClient.get<ColumnListResponse>(url);
    const out: FollowTabItem[] = [];
    const data = res.data.data ?? [];
    for (const c of data) {
      out.push({
        key: 'col_' + String(out.length),
        name: c.title ?? '',
        intro: c.intro ?? '',
        avatar: c.image_url ?? '',
        meta: this.metaOf(c.followers, c.articles_count),
        id: c.id !== undefined ? String(c.id) : '',
      });
    }
    return out;
  }

  private async loadTopics(): Promise<FollowTabItem[]> {
    const url = API_V4 + '/members/' + encodeURIComponent(this.meId) +
      '/topics?include=data[*].introduction,followers_count,questions_count,is_following' +
      '&limit=20&offset=0';
    const res = await zhihuClient.get<TopicListResponse>(url);
    const out: FollowTabItem[] = [];
    const data = res.data.data ?? [];
    for (const t of data) {
      out.push({
        key: 'top_' + String(out.length),
        name: t.name ?? '',
        intro: t.introduction ?? '',
        avatar: t.avatar_url ?? '',
        meta: this.metaOf(t.followers_count, t.questions_count),
      });
    }
    return out;
  }

  private async loadQuestions(): Promise<FollowTabItem[]> {
    const url = API_V4 + '/members/' + encodeURIComponent(this.meId) +
      '/question_follows?include=data[*].answer_count,follower_count,is_following' +
      '&limit=20&offset=0';
    const res = await zhihuClient.get<QuestionListResponse>(url);
    const out: FollowTabItem[] = [];
    const data = res.data.data ?? [];
    for (const q of data) {
      out.push({
        key: 'q_' + String(q.id ?? out.length),
        name: q.title ?? '',
        intro: '',
        avatar: '',
        meta: this.metaOf(q.follower_count, q.answer_count),
      });
    }
    return out;
  }

  private async loadCollections(): Promise<FollowTabItem[]> {
    const res = await getMyCollections(20, 0);
    const out: FollowTabItem[] = [];
    for (const c of res.data) {
      out.push({
        key: 'coll_' + String(c.id),
        name: c.title,
        intro: c.description ?? '',
        avatar: '',
        meta: this.metaOf(c.follower_count, c.answer_count),
      });
    }
    return out;
  }

  private metaOf(followers?: number, count?: number): string {
    const f = followers !== undefined ? String(followers) : '0';
    const c = count !== undefined ? String(count) : '0';
    return f + ' 关注者   ' + c + ' 回答';
  }

  @Builder
  topBar() {
    Row() {
      Text('‹')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(26)
        .fontColor(ZhihuColors.primary)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Text('关注')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.text)
      Blank()
    }
    .width('100%')
    .height(52)
    .padding({ left: 12, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  tabBar() {
    Row() {
      ForEach(TABS, (tab: FollowTab, index: number) => {
        Column({ space: 6 }) {
          Text(tab.label)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(16)
            .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.currentTab === index ? ZhihuColors.primary : ZhihuColors.textSecondary)
          Divider()
            .strokeWidth(2)
            .color(this.currentTab === index ? ZhihuColors.primary : Color.Transparent)
            .width(24)
        }
        .layoutWeight(1)
        .height(46)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.switchTab(index);
        })
      }, (tab: FollowTab) => tab.label)
    }
    .width('100%')
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  itemRow(item: FollowTabItem) {
    Row({ space: 14 }) {
      if (item.avatar.length > 0) {        Image(item.avatar)
          .width(52)
          .height(52)
          .borderRadius(26)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      } else {
        Text(item.name.substring(0, 1))
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(18)
          .fontColor(ZhihuColors.primary)
          .width(52)
          .height(52)
          .textAlign(TextAlign.Center)
          .backgroundColor(ZhihuColors.primaryTransparent)
          .borderRadius(26)
      }
      Column({ space: 4 }) {
        Text(item.name)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (item.intro.length > 0) {
          Text(item.intro)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        Text(item.meta)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('已关注')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(14)
        .fontColor(ZhihuColors.textSecondary)
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .backgroundColor(ZhihuColors.backgroundTertiary)
        .borderRadius(16)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .onClick(() => {
      this.openRow(item);
    })
  }

  /** 条目点击：专栏行 → 专栏详情；其余 tab 暂不跳转。 */
  private openRow(item: FollowTabItem): void {
    if (this.currentTab === 1 && item.id !== undefined && item.id.length > 0) {
      router.pushUrl({
        url: 'pages/ColumnPage',
        params: { id: item.id },
      });
    }
  }

  build() {
    Column() {
      this.topBar()
      this.tabBar()
      if (this.loading) {
        Column() {
          Text('加载中…')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(15)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column() {
          Text('暂无数据')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(15)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.items, (item: FollowTabItem) => {
            ListItem() {
              this.itemRow(item)
              Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 82 })
            }
          }, (item: FollowTabItem) => item.key)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
