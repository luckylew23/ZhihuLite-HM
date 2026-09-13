/**
 * pages/SettingsFilterPage —— 过滤与推荐（截图 04，浅色）。
 * 三组开关，全部真接线到 store/settingsStore.ts 并持久化：
 *   (a) 本地后处理·内容过滤：启用内容过滤
 *   (b) 本地后处理·去重与缓存：本地 Feed 去重 / 启动时保留推荐流 / 清除本地去重记录
 *   (c) 服务端请求参数：发送 desktop=true（默认开）/ 发送 ad_interval（默认开）
 * desktop / ad_interval 由 api/feed.ts 在拼推荐流 URL 时读取；去重由 feed.ts 后处理。
 */

import { router, promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { ZhihuColors } from '../utils/theme';
import { settingsStore } from '../store/settingsStore';

@Entry
@Component
struct SettingsFilterPage {
  @State contentFilter: boolean = false;
  @State feedDedup: boolean = false;
  @State keepRecommend: boolean = false;
  @State sendDesktop: boolean = true;
  @State sendAdInterval: boolean = true;

  aboutToAppear(): void {
    settingsStore.init(getContext(this) as common.UIAbilityContext);
    this.contentFilter = settingsStore.getContentFilterEnabled();
    this.feedDedup = settingsStore.isDedupEnabled();
    this.keepRecommend = settingsStore.isKeepRecommendOnLaunch();
    this.sendDesktop = settingsStore.isSendDesktop();
    this.sendAdInterval = settingsStore.isSendAdInterval();
  }

  @Builder
  topBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor(ZhihuColors.primary)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Text('过滤与推荐')
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
  sectionLabel(title: string) {
    Text(title)
      .fontSize(14)
      .fontColor(ZhihuColors.textSecondary)
      .width('100%')
      .padding({ left: 16, top: 20, bottom: 8 })
  }

  @Builder
  iconBadge(glyph: string) {
    Text(glyph)
      .fontSize(17)
      .fontColor(ZhihuColors.primary)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .backgroundColor(ZhihuColors.primaryTransparent)
      .borderRadius(10)
  }

  @Builder
  switchRow(glyph: string, label: string, desc: string | null,
    value: boolean, onChange: (v: boolean) => void) {
    Row({ space: 12 }) {
      this.iconBadge(glyph)
      Column({ space: 2 }) {
        Text(label)
          .fontSize(16)
          .fontColor(ZhihuColors.text)
        if (desc !== null) {
          Text(desc)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .selectedColor(ZhihuColors.primary)
        .onChange((val: boolean) => {
          onChange(val);
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
  }

  @Builder
  clearRow() {
    Row({ space: 12 }) {
      this.iconBadge('删')
      Text('清除本地去重记录')
        .fontSize(16)
        .fontColor(ZhihuColors.text)
        .layoutWeight(1)
      Text('清除')
        .fontSize(16)
        .fontColor(ZhihuColors.danger)
        .onClick(() => {
          settingsStore.clearDedupRecords();
          promptAction.showToast({ message: '已清除本地去重记录' });
        })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
  }

  build() {
    Column() {
      this.topBar()
      Scroll() {
        Column({ space: 0 }) {
          // 介绍卡
          Column({ space: 8 }) {
            Text('推荐流设置分为两类')
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(ZhihuColors.text)
              .width('100%')
            Text('服务端请求参数会影响知乎返回的推荐内容；本地后处理只在应用收到内容后执行，包含内容过滤、去重与启动缓存。')
              .fontSize(14)
              .fontColor(ZhihuColors.textSecondary)
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)
          .margin({ bottom: 4 })

          // (a) 本地后处理·内容过滤
          this.sectionLabel('本地后处理 · 内容过滤')
          Column() {
            this.switchRow('滤', '启用内容过滤', null, this.contentFilter, (v: boolean) => {
              this.contentFilter = v;
              settingsStore.setContentFilterEnabled(v);
            })
          }
          .width('100%')
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)

          // (b) 本地后处理·去重与缓存
          this.sectionLabel('本地后处理 · 去重与缓存')
          Column() {
            this.switchRow('重', '本地 Feed 去重', null, this.feedDedup, (v: boolean) => {
              this.feedDedup = v;
              settingsStore.setDedupEnabled(v);
            })
            Divider().strokeWidth(0.5).color(ZhihuColors.divider)
              .margin({ left: 62 })
            this.switchRow('留', '启动时保留推荐流', null, this.keepRecommend, (v: boolean) => {
              this.keepRecommend = v;
              settingsStore.setKeepRecommendOnLaunch(v);
            })
            Divider().strokeWidth(0.5).color(ZhihuColors.divider)
              .margin({ left: 62 })
            this.clearRow()
          }
          .width('100%')
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)

          // (c) 服务端请求参数
          this.sectionLabel('服务端请求参数')
          Column() {
            this.switchRow('端', '发送 desktop=true', null, this.sendDesktop, (v: boolean) => {
              this.sendDesktop = v;
              settingsStore.setSendDesktop(v);
            })
            Divider().strokeWidth(0.5).color(ZhihuColors.divider)
              .margin({ left: 62 })
            this.switchRow('广', '发送 ad_interval', null, this.sendAdInterval, (v: boolean) => {
              this.sendAdInterval = v;
              settingsStore.setSendAdInterval(v);
            })
          }
          .width('100%')
          .backgroundColor(ZhihuColors.backgroundSecondary)
          .borderRadius(12)
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
