/**
 * pages/ProfilePage —— 我的（对齐 Android v0.6.0 截图 09）。
 * 头部：圆头像 + 昵称 + “点击查看个人主页”（→ PeoplePage，url_token=me.url_token）。
 * 统计 4 列：回答 / 文章 / 关注 / 粉丝（关注/粉丝缺省降级为 0；点“关注”→ FollowManagePage）。
 * 菜单：我的收藏 / 最近浏览 / 主题模式(行内三选) / 外观与定制 / 过滤与推荐 /
 *       消息通知 / 切换账号 / 反馈与建议；底部红色“退出账号”。
 * 未登录保留登录引导。
 */

import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { getMe, ZhihuMeInfo } from '../api/me';
import { authStore } from '../store/authStore';
import { ZhihuColors, applyTheme } from '../utils/theme';
import { settingsStore, ThemeMode } from '../store/settingsStore';

interface MenuItem {
  glyph: string;
  label: string;
  route: string;
  badge: string;
}

@Component
export struct ProfilePage {
  @State me: ZhihuMeInfo | null = null;
  @State loggedIn: boolean = false;
  @State themeMode: ThemeMode = 'auto';
  @State themeTick: number = 0;

  aboutToAppear(): void {
    settingsStore.init(getContext(this) as common.UIAbilityContext);
    applyTheme();
    this.themeMode = settingsStore.getThemeMode();
    this.themeTick = settingsStore.getVersion();
    this.loadMe();
  }

  async loadMe(): Promise<void> {
    this.loggedIn = authStore.isLoggedIn;
    if (!this.loggedIn) {
      this.me = null;
      return;
    }
    try {
      this.me = await getMe();
    } catch (e) {
      // 保持空态，UI 用 0 兜底
    }
  }

  private goPeople(): void {
    const token: string = this.me?.url_token ?? '';
    if (token.length > 0) {
      router.pushUrl({ url: 'pages/PeoplePage', params: { urlToken: token } });
    } else {
      // v1.3.0：url_token 缺失时不再跳无参页（避免“缺少用户标识”），提示后回退
      promptAction.showToast({ message: '个人资料未加载成功，请稍后重试' });
    }
  }

  private chooseTheme(mode: ThemeMode): void {
    this.themeMode = mode;
    settingsStore.setThemeMode(mode);
    applyTheme();
    this.themeTick = settingsStore.getVersion();
  }

  private switchAccount(): void {
    if (authStore.isLoggedIn) {
      authStore.clear();
      this.me = null;
      this.loggedIn = false;
      promptAction.showToast({ message: '已退出当前账号，请重新登录' });
      router.pushUrl({ url: 'pages/LoginPage' });
    } else {
      router.pushUrl({ url: 'pages/LoginPage' });
    }
  }

  private logout(): void {
    authStore.clear();
    this.me = null;
    this.loggedIn = false;
    promptAction.showToast({ message: '已退出账号' });
  }

  @Builder
  iconBadge(glyph: string) {
    Text(glyph)
      .copyOption(CopyOptions.LocalDevice)
      .fontSize(15)
      .fontColor(ZhihuColors.primary)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .backgroundColor(ZhihuColors.primaryTransparent)
      .borderRadius(18)
  }

  @Builder
  statItem(label: string, value: number, clickable: boolean) {
    Column({ space: 4 }) {
      Text(String(value))
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor(ZhihuColors.text)
      Text(label)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(12)
        .fontColor(ZhihuColors.textSecondary)
    }
    .layoutWeight(1)
    .onClick(() => {
      if (clickable) {
        router.pushUrl({ url: 'pages/FollowManagePage' });
      }
    })
  }

  @Builder
  menuRow(item: MenuItem) {
    Row({ space: 14 }) {
      this.iconBadge(item.glyph)
      Text(item.label)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(16)
        .fontColor(ZhihuColors.text)
        .layoutWeight(1)
      if (item.badge.length > 0) {
        Text(item.badge)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
      }
      Text('›')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(20)
        .fontColor(ZhihuColors.textTertiary)
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
    .onClick(() => {
      if (item.route.length > 0) {
        router.pushUrl({ url: item.route });
      }
    })
  }

  @Builder
  themeModeRow() {
    Row({ space: 14 }) {
      this.iconBadge('昼')
      Text('主题模式')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(16)
        .fontColor(ZhihuColors.text)
        .layoutWeight(1)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsAppearancePage' });
        })
      Row({ space: 6 }) {
        this.themePill('系统', 'auto')
        this.themePill('浅色', 'light')
        this.themePill('深色', 'dark')
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 14, right: 14 })
  }

  @Builder
  themePill(label: string, value: ThemeMode) {
    Text(label)
      .copyOption(CopyOptions.LocalDevice)
      .fontSize(12)
      .fontColor(this.themeMode === value ? ZhihuColors.textInverse : ZhihuColors.text)
      .fontWeight(this.themeMode === value ? FontWeight.Bold : FontWeight.Normal)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.themeMode === value ? ZhihuColors.primary : ZhihuColors.backgroundTertiary)
      .borderRadius(14)
      .onClick(() => {
        this.chooseTheme(value);
      })
  }

  @Builder
  guestView() {
    Column({ space: 16 }) {
      Blank()
      Text('登录后同步你的关注、收藏与创作')
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(14)
        .fontColor(ZhihuColors.textSecondary)
      Button('登录知乎')
        .width(220)
        .height(44)
        .fontSize(16)
        .backgroundColor(ZhihuColors.primary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      Blank()
      Blank()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  userView() {
    Scroll() {
      Column({ space: 12 }) {
        // 头部
        Row({ space: 14 }) {
          Image(this.me?.avatar_url ?? '')
            .width(64)
            .height(64)
            .borderRadius(32)
            .objectFit(ImageFit.Cover)
            .backgroundColor(ZhihuColors.backgroundTertiary)
          Column({ space: 4 }) {
            Text(this.me?.name ?? '')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(ZhihuColors.text)
            Text('点击查看个人主页')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13)
              .fontColor(ZhihuColors.textSecondary)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('›')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(22)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          this.goPeople();
        })

        // 统计 4 列
        Row() {
          this.statItem('回答', this.me?.answer_count ?? 0, false)
          this.statItem('文章', this.me?.articles_count ?? 0, false)
          this.statItem('关注', this.me?.following_count ?? 0, true)
          this.statItem('粉丝', this.me?.followers_count ?? 0, false)
        }
        .width('100%')
        .padding({ top: 16, bottom: 16 })
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .borderRadius(12)

        // 菜单组 1
        Column() {
          this.menuRow({ glyph: '藏', label: '我的收藏', route: 'pages/CollectionsListPage', badge: '' })
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          this.menuRow({ glyph: '历', label: '最近浏览', route: 'pages/HistoryPage', badge: '' })
        }
        .width('100%')
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .borderRadius(12)

        // 菜单组 2
        Column() {
          this.themeModeRow()
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          this.menuRow({ glyph: '貌', label: '外观与定制', route: 'pages/SettingsAppearancePage', badge: '' })
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          this.menuRow({ glyph: '滤', label: '过滤与推荐', route: 'pages/SettingsFilterPage', badge: '' })
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          this.menuRow({ glyph: '讯', label: '消息通知', route: 'pages/NotificationsPage', badge: '' })
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          Row({ space: 14 }) {
            this.iconBadge('号')
            Text('切换账号')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(16)
              .fontColor(ZhihuColors.text)
              .layoutWeight(1)
            Text('1 个账号')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13)
              .fontColor(ZhihuColors.textTertiary)
            Text('›')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(20)
              .fontColor(ZhihuColors.textTertiary)
          }
          .width('100%')
          .height(56)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.switchAccount();
          })
          Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ left: 64 })
          this.menuRow({ glyph: '馈', label: '反馈与建议', route: 'pages/FeedbackPage', badge: '' })
        }
        .width('100%')
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .borderRadius(12)

        // 退出账号
        Text('退出账号')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontColor(ZhihuColors.danger)
          .width('100%')
          .height(52)
          .textAlign(TextAlign.Center)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)
          .margin({ top: 4 })
          .onClick(() => {
            this.logout();
          })
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }

  build() {
    Stack() {
      if (this.loggedIn) {
        this.userView()
      } else {
        this.guestView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
