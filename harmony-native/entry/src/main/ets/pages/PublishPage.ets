/**
 * pages/PublishPage —— 发布内容入口（对齐上游 app/(tabs)/publish.tsx 四宫格）。
 * 四个入口：写回答 / 写文章 / 发想法 / 提问题，点击进入对应发布表单页。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';

interface PublishOption {
  id: string;
  title: string;
  subtitle: string;
  glyph: string;
  color: string;
  route: string;
}

const PUBLISH_OPTIONS: PublishOption[] = [
  {
    id: 'answer',
    title: '写回答',
    subtitle: '分享你的见解',
    glyph: '✍️',
    color: '#0084ff',
    route: 'pages/PublishAnswerPage',
  },
  {
    id: 'article',
    title: '写文章',
    subtitle: '记录生活点滴',
    glyph: '📄',
    color: '#ff9900',
    route: 'pages/PublishArticlePage',
  },
  {
    id: 'pin',
    title: '发想法',
    subtitle: '随时捕捉灵感',
    glyph: '💡',
    color: '#00b96b',
    route: 'pages/PublishPinPage',
  },
  {
    id: 'question',
    title: '提问题',
    subtitle: '向世界发问',
    glyph: '❓',
    color: '#ff4d4f',
    route: 'pages/PublishQuestionPage',
  },
];

@Entry
@Component
struct PublishPage {
  @Builder
  optionRow(item: PublishOption) {
    Row({ space: 14 }) {
      Text(item.glyph)
        .fontSize(26)
        .width(56)
        .height(56)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.hexAlpha(item.color, 0.12))
        .borderRadius(14)
      Column({ space: 3 }) {
        Text(item.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
        Text(item.subtitle)
          .fontSize(13)
          .fontColor(ZhihuColors.textSecondary)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text('›')
        .fontSize(20)
        .fontColor(ZhihuColors.textTertiary)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(ZhihuColors.backgroundSecondary)
    .borderRadius(18)
    .margin({ bottom: 12 })
    .onClick(() => {
      router.pushUrl({ url: item.route });
    })
  }

  /** '#rrggbb' + 透明度 → 'rgba(r,g,b,a)' */
  private hexAlpha(hex: string, alpha: number): string {
    let h: string = hex.replace('#', '');
    if (h.length !== 6) {
      return 'rgba(0,132,255,0.12)';
    }
    const r: number = parseInt(h.substring(0, 2), 16);
    const g: number = parseInt(h.substring(2, 4), 16);
    const b: number = parseInt(h.substring(4, 6), 16);
    return 'rgba(' + String(r) + ',' + String(g) + ',' + String(b) + ',' + String(alpha) + ')';
  }

  build() {
    Column() {
      // 顶部导航：返回 + 标题
      Row() {
        Text('‹')
          .fontSize(30)
          .fontColor(ZhihuColors.text)
          .padding({ left: 6, right: 10 })
          .onClick(() => {
            router.back();
          })
        Text('发布内容')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .layoutWeight(1)
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 12 })
      .backgroundColor(ZhihuColors.backgroundSecondary)

      // 顶部
      Column({ space: 4 }) {
        Text('发布内容')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
        Text('让世界看到你的思考')
          .fontSize(14)
          .fontColor(ZhihuColors.textSecondary)
      }
      .width('100%')
      .padding({ top: 36, bottom: 36 })

      // 四宫格
      Column() {
        ForEach(PUBLISH_OPTIONS, (item: PublishOption) => {
          this.optionRow(item)
        }, (item: PublishOption) => item.id)
      }
      .width('100%')
      .padding({ left: 20, right: 20 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
