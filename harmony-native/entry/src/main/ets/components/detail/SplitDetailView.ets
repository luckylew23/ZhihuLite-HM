/**
 * components/detail/SplitDetailView —— 宽屏两栏模式的右栏内容容器。
 *
 * 框架统一：右栏直接复用全屏详情页的视图组件（AnswerDetailView 等），
 * 与单栏全屏路由同一套顶栏/正文/操作条，仅返回行为不同
 * （inSplit=true 时返回 = 关闭内容栏回列表）。
 */

import { ZhihuColors } from '../../utils/theme';
import { closeSplitDetail } from '../../utils/contentOpener';
import { AnswerDetailView } from '../../pages/AnswerDetailPage';
import { ArticleDetailView } from '../../pages/ArticleDetailPage';
import { QuestionDetailView } from '../../pages/QuestionDetailPage';
import { PinDetailView } from '../../pages/PinDetailPage';
import { DailyDetailView } from '../../pages/DailyDetailPage';

@Component
export struct SplitDetailView {
  @StorageProp('splitType') splitType: string = '';
  @StorageProp('splitId') splitId: string = '';
  @StorageProp('splitVersion') splitVersion: number = 0;

  private typeLabel(): string {
    if (this.splitType === 'answers') {
      return '回答';
    }
    if (this.splitType === 'articles') {
      return '文章';
    }
    if (this.splitType === 'questions') {
      return '问题';
    }
    if (this.splitType === 'pins') {
      return '想法';
    }
    if (this.splitType === 'daily') {
      return '日报';
    }
    return '浏览';
  }

  build() {
    Column() {
      if (this.splitType === 'answers') {
        AnswerDetailView({ answerId: this.splitId, inSplit: true })
      } else if (this.splitType === 'articles') {
        ArticleDetailView({ articleId: this.splitId, inSplit: true })
      } else if (this.splitType === 'questions') {
        QuestionDetailView({ qId: this.splitId, inSplit: true })
      } else if (this.splitType === 'pins') {
        PinDetailView({ pinId: this.splitId, inSplit: true })
      } else if (this.splitType === 'daily') {
        DailyDetailView({ storyId: this.splitId, inSplit: true })
      } else {
        // 空态：提示从左栏选择内容
        Column({ space: 14 }) {
          Text('☰')
            .fontSize(44)
            .fontColor(ZhihuColors.textTertiary)
          Text('点击左侧任意内容')
            .fontSize(16)
            .fontColor(ZhihuColors.textTertiary)
          Text('内容将在此处打开，列表保持不动')
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
    .border({ width: { left: 0.5 }, color: ZhihuColors.border })

  }
}
