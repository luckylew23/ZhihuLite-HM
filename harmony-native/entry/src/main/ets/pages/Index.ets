/**
 * pages/Index —— 主页面（对齐上游 zhihu-- v0.6.0 结构）。
 *
 * 外层底部 TabBar（barHeight≈64，3 个）：
 *   [首页组] / [圆形 + 发布入口] / [个人中心]
 *
 * 「首页」内部顶部 TabBar（height≈50）：
 *   按 settingsStore.getVisibleTabs() 动态渲染可见栏目，key 映射固定：
 *   following → FollowingPage
 *   recommend → FeedListPage({ feedMode: 'recommend' })
 *   hot      → FeedListPage({ feedMode: 'hot' })
 *   daily    → FeedListPage({ feedMode: 'daily' })
 *   publish / profile 不出现在顶栏（profile=底栏第三项，publish=底栏中间 +）。
 * 顶栏右侧搜索图标 → router.pushUrl({ url: 'pages/SearchPage' })
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';
import { settingsStore } from '../store/settingsStore';
import { FeedListPage } from './FeedListPage';
import { FollowingPage } from './FollowingPage';
import { DailyPage } from './DailyPage';
import { ProfilePage } from './ProfilePage';

@Entry
@Component
struct Index {
  // 外层：0=首页组, 1=个人中心（中间「+」不参与选中态）
  @State outerIndex: number = 0;
  // 内层：默认落到 getDefaultTab() 对应的可见项
  @State innerIndex: number = 0;
  // 首页组顶栏可见栏目 key 列表（aboutToAppear 读一次，改配置下次进入生效）
  @State visibleKeys: string[] = [];
  // 内层 Tabs 控制器：保证顶栏点击/底栏首页回默认栏均能强制切换内容
  private tabsCtrl: TabsController = new TabsController();
  // 登录态版本号：登录/登出翻转时 +1 → 下方 Tabs/ProfilePage 的 key 变化 → 强制重建，
  // 各列表页重新 aboutToAppear 用最新 cookie 加载（登录后状态刷新）
  @StorageProp('loginVersion') loginVersion: number = 0;

  /** 顶栏允许出现的栏目（固定顺序；publish/profile 不在其中） */
  private topTabOrder: string[] = ['following', 'recommend', 'hot', 'daily'];

  aboutToAppear(): void {
    const all: string[] = settingsStore.getVisibleTabs();
    const visible: string[] = [];
    for (const k of this.topTabOrder) {
      if (all.indexOf(k) >= 0 && settingsStore.isTabVisible(k)) {
        visible.push(k);
      }
    }
    this.visibleKeys = visible.length > 0 ? visible : this.topTabOrder.slice();
    // 默认 tab：getDefaultTab() 在可见列表中就用它，否则回落第一个可见项
    const def: string = settingsStore.getDefaultTab();
    const idx: number = this.visibleKeys.indexOf(def);
    this.innerIndex = idx >= 0 ? idx : 0;
  }

  private keyToLabel(key: string): string {
    if (key === 'following') {
      return '关注';
    }
    if (key === 'recommend') {
      return '推荐';
    }
    if (key === 'hot') {
      return '热榜';
    }
    if (key === 'daily') {
      return '日报';
    }
    return key;
  }

  /** key → 对应页面组件 */
  @Builder
  pageForKey(key: string) {
    if (key === 'following') {
      FollowingPage()
    } else if (key === 'recommend') {
      FeedListPage({ feedMode: 'recommend' })
    } else if (key === 'hot') {
      FeedListPage({ feedMode: 'hot' })
    } else if (key === 'daily') {
      DailyPage()
    } else {
      FollowingPage()
    }
  }

  /** 内层切换到指定可见栏目（顶栏点击 / 底栏首页重置共用） */
  private switchToTab(index: number): void {
    if (index < 0 || index >= this.visibleKeys.length) {
      return;
    }
    this.innerIndex = index;
    this.tabsCtrl.changeIndex(index);
  }

  /** 内层顶部文字 tab：当前项加粗蓝色 + 下方短指示线，未选灰色 #666 */
  @Builder
  topTab(key: string, index: number) {
    Column({ space: 5 }) {
      Text(this.keyToLabel(key))
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(this.innerIndex === index ? 17 : 15)
        .fontWeight(this.innerIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(
          this.innerIndex === index ? ZhihuColors.tabIconSelected : '#666666',
        )
      if (this.innerIndex === index) {
        Row()
          .width(20)
          .height(3)
          .backgroundColor(ZhihuColors.tabIconSelected)
          .borderRadius(2)
      } else {
        Row().width(20).height(3)
      }
    }
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ left: 6, right: 6 })
    .onClick(() => {
      this.switchToTab(index);
    })
  }

  /** 首页组顶栏：可见文字 tab（左）+ 搜索图标（右），高 50 */
  @Builder
  topNavBar() {
    Row({ space: 4 }) {
      ForEach(
        this.visibleKeys,
        (key: string, i: number) => {
          this.topTab(key, i)
        },
        (key: string) => key,
      )
      Blank()
      Text('🔍')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(20)
        .fontColor(ZhihuColors.text)
        .padding(8)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SearchPage' });
        })
    }
    .width('100%')
    .height(50)
    .padding({ left: 12, right: 8 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  /** 首页组内容：内层可滑动 Tabs（自身 bar 隐藏，由 topNavBar 承担） */
  @Builder
  homeTabs() {
    Tabs({ barPosition: BarPosition.Start, index: this.innerIndex, controller: this.tabsCtrl }) {
      ForEach(
        this.visibleKeys,
        (key: string) => {
          TabContent() {
            this.pageForKey(key)
          }
        },
        (key: string) => key,
      )
    }
    .scrollable(true)
    .barHeight(0)
    .barWidth(0)
    .layoutWeight(1)
    .key('home-' + String(this.loginVersion))
    .onChange((i: number) => {
      this.innerIndex = i;
    })
  }

  /** 外层底部单个图标项（首页 / 个人中心），选中 #0084ff，未选 #ccc */
  @Builder
  bottomItem(icon: string, target: number, onAlreadyActive: () => void = () => {
  }) {
    Column() {
      Text(icon)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(24)
        .fontColor(
          this.outerIndex === target
            ? ZhihuColors.tabIconSelected
            : ZhihuColors.tabIconDefault,
        )
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.outerIndex === target) {
        // 点击当前已选中的底栏项：执行“回默认栏目”等反馈逻辑
        onAlreadyActive();
      } else {
        this.outerIndex = target;
      }
    })
  }

  /** 底栏「首页」：已在首页时回到默认栏目（对齐 Android 点击已选 tab 的反馈） */
  private goHome(): void {
    if (this.outerIndex === 0) {
      const def: string = settingsStore.getDefaultTab();
      const idx: number = this.visibleKeys.indexOf(def);
      this.switchToTab(idx >= 0 ? idx : 0);
    } else {
      this.outerIndex = 0;
    }
  }

  /** 外层底部栏：首页 / 中间圆形 + 发布 / 个人中心，高 64 */
  @Builder
  bottomBar() {
    Row() {
      this.bottomItem('🏠', 0, () => {
        this.goHome();
      })
      Column() {
        Text('+')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.textInverse)
          .width(44)
          .height(44)
          .textAlign(TextAlign.Center)
          .backgroundColor(ZhihuColors.tabIconSelected)
          .borderRadius(22)
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        // v1.3.0：发布入口改为四宫格入口页（写回答/写文章/发想法/提问题）
        router.pushUrl({ url: 'pages/PublishPage' });
      })
      this.bottomItem('👤', 1)
    }
    .width('100%')
    .height(64)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .border({ width: { top: 0.5 }, color: ZhihuColors.border })
  }

  build() {
    Column() {
      // 首页组与个人中心常驻（Visibility 切换），避免条件渲染反复销毁/重建
      // 整个 Tabs 树（4 个列表页重发请求）——这是“切换慢/点击卡”的根因之一。
      Stack() {
        Column() {
          this.topNavBar()
          this.homeTabs()
        }
        .width('100%')
        .height('100%')
        .visibility(this.outerIndex === 0 ? Visibility.Visible : Visibility.None)

        Column() {
          ProfilePage()
        }
          .width('100%')
          .height('100%')
          .key('profile-' + String(this.loginVersion))
          .visibility(this.outerIndex === 1 ? Visibility.Visible : Visibility.None)
      }
      .width('100%')
      .layoutWeight(1)

      this.bottomBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
