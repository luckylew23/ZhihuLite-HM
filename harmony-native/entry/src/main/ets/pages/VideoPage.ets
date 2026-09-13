/**
 * pages/VideoPage —— 视频（zvideo）详情。
 * 上游：app/video/[id].tsx（原 WebView 内嵌 zvideo）。
 * 降级：HarmonyOS 本期不内嵌播放器，渲染标题 + 作者/描述占位 + "视频暂不支持内嵌播放"提示。
 * 无对应 getVideo API，数据仅来自路由参数。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../utils/theme';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { readStringParam } from '../components/detail/detailUtils';

@Entry
@Component
struct VideoPage {
  @State videoId: string = '';
  @State title: string = '';
  @State author: string = '';
  @State desc: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.videoId = readStringParam(p, 'id');
    this.title = readStringParam(p, 'title');
    this.author = readStringParam(p, 'author');
    this.desc = readStringParam(p, 'description');
  }

  build() {
    Column() {
      DetailNavBar({ title: this.title.length > 0 ? this.title : '视频' })

      Column({ space: 16 }) {
        // 占位播放器
        Column({ space: 10 }) {
          Text('▶')
            .fontSize(44)
            .fontColor(ZhihuColors.textTertiary)
          Text('视频暂不支持内嵌播放')
            .fontSize(14)
            .fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .height(200)
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .borderRadius(12)
        .justifyContent(FlexAlign.Center)

        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(ZhihuColors.text)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        if (this.author.length > 0) {
          Text('作者：' + this.author)
            .fontSize(14)
            .fontColor(ZhihuColors.textSecondary)
            .width('100%')
        }
        if (this.desc.length > 0) {
          Text(this.desc)
            .fontSize(15)
            .fontColor(ZhihuColors.textSecondary)
            .lineHeight(21)
            .width('100%')
            .textAlign(TextAlign.Start)
        }
        if (this.videoId.length > 0) {
          Text('视频 ID：' + this.videoId)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
