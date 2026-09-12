/**
 * pages/SettingsAppearancePage —— 外观与定制 / 主题模式三选（系统 | 浅色 | 深色）。
 * 选择持久化到 settingsStore（preferences），并立即 applyTheme() 写回 ZhihuColors。
 * 当前项右侧打勾。
 */

import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ZhihuColors, applyTheme } from '../utils/theme';
import { settingsStore, ThemeMode } from '../store/settingsStore';

interface ThemeOption {
  label: string;
  value: ThemeMode;
}

interface TabOption {
  label: string;
  key: string;
}

const THEME_OPTIONS: ThemeOption[] = [
  { label: '系统', value: 'auto' },
  { label: '浅色', value: 'light' },
  { label: '深色', value: 'dark' },
];

const TAB_OPTIONS: TabOption[] = [
  { label: '关注', key: 'following' },
  { label: '推荐', key: 'recommend' },
  { label: '热榜', key: 'hot' },
  { label: '日报', key: 'daily' },
];

@Entry
@Component
struct SettingsAppearancePage {
  @State mode: ThemeMode = 'auto';
  @State tick: number = 0;
  @State visibleTabs: string[] = [];

  aboutToAppear(): void {
    settingsStore.init(getContext(this) as common.UIAbilityContext);
    this.mode = settingsStore.getThemeMode();
    applyTheme();
    this.tick = settingsStore.getVersion();
    this.visibleTabs = settingsStore.getVisibleTabs();
  }

  private isTabOn(key: string): boolean {
    return this.visibleTabs.indexOf(key) >= 0;
  }

  private onToggleTab(key: string): void {
    this.visibleTabs = settingsStore.toggleTab(key);
    this.tick = settingsStore.getVersion();
  }

  private choose(value: ThemeMode): void {
    this.mode = value;
    settingsStore.setThemeMode(value);
    applyTheme();
    this.tick = settingsStore.getVersion();
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
      Text('外观与定制')
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
  themeRow(option: ThemeOption, index: number, total: number) {
    Row() {
      Text(option.label)
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(17)
        .fontColor(ZhihuColors.text)
        .layoutWeight(1)
      if (this.mode === option.value) {
        Text('✓')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.primary)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.choose(option.value);
    })
    if (index < total - 1) {
      Divider().strokeWidth(0.5).color(ZhihuColors.divider)
        .margin({ left: 16 })
    }
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: 0 }) {
          Text('主题模式')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .width('100%')
            .padding({ left: 4, top: 4, bottom: 8 })

          Column() {
            ForEach(THEME_OPTIONS, (opt: ThemeOption, index: number) => {
              this.themeRow(opt, index, THEME_OPTIONS.length);
            }, (opt: ThemeOption) => opt.value)
          }
          .width('100%')
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)

          Text('选择后立即生效；“系统”跟随系统深浅色模式。')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
            .padding({ left: 4, top: 16, bottom: 4 })

          Text('栏目展示')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .width('100%')
            .padding({ left: 4, top: 12, bottom: 8 })

          Column() {
            ForEach(TAB_OPTIONS, (opt: TabOption, index: number) => {
              Row({ space: 12 }) {
                Text(opt.label)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(17)
                  .fontColor(ZhihuColors.text)
                  .layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.isTabOn(opt.key) })
                  .selectedColor(ZhihuColors.primary)
                  .onChange(() => {
                    this.onToggleTab(opt.key);
                  })
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
              if (index < TAB_OPTIONS.length - 1) {
                Divider().strokeWidth(0.5).color(ZhihuColors.divider)
                  .margin({ left: 16 })
              }
            }, (opt: TabOption) => opt.key)
          }
          .width('100%')
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)

          Text('控制首页底栏可见栏目；个人中心与发布固定显示。')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
            .padding({ left: 4, top: 12 })
        }
        .width('100%')
        .padding(16)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
