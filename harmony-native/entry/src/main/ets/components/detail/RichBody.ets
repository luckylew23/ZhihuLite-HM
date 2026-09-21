/**
 * components/detail/RichBody —— 正文富文本渲染组件（关注/推荐/热榜/文章/想法详情共用）。
 * 渲染 HTML 解析出的结构化块：标题/引用/代码块/列表/普通段落（行内支持粗体/斜体/等宽代码）+ 图片。
 * 样式与日报详情一致（v0.3.51）。
 */

import { HtmlBlock, parseInline, InlinePart } from './detailUtils';
import { ZhihuColors } from '../../utils/theme';
import { NetImage } from '../NetImage';

@Component
export struct RichBody {
  blocks: HtmlBlock[] = [];

  build() {
    Column() {
      ForEach(this.blocks, (b: HtmlBlock, idx: number) => {
        if (b.type === 'image') {
          NetImage({ url: b.url, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
        } else if (b.type === 'heading') {
          Text() {
            ForEach(parseInline(b.text), (p: InlinePart) => {
              Span(p.text)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
            })
          }
          .copyOption(CopyOptions.LocalDevice)
          .width('100%')
          .margin({ top: 8, bottom: 4 })
        } else if (b.type === 'quote') {
          Text() {
            ForEach(parseInline(b.text), (p: InlinePart) => {
              Span(p.text)
                .fontSize(18)
                .fontStyle(FontStyle.Italic)
                .fontColor(ZhihuColors.textSecondary)
            })
          }
          .copyOption(CopyOptions.LocalDevice)
          .lineHeight(26)
          .width('100%')
          .padding({ left: 12, top: 4, bottom: 4 })
          .borderWidth({ left: 3 })
          .borderColor({ left: ZhihuColors.primary })
        } else if (b.type === 'code') {
          Text(b.text)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(16)
            .lineHeight(24)
            .fontColor(ZhihuColors.text)
            .width('100%')
            .padding(10)
            .backgroundColor(ZhihuColors.backgroundSecondary)
        } else if (b.type === 'list') {
          Text() {
            ForEach(parseInline(b.text), (p: InlinePart, pi: number) => {
              Span((pi === 0 ? '· ' : '') + p.text)
                .fontSize(19)
                .fontWeight(p.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(p.italic ? FontStyle.Italic : FontStyle.Normal)
                .decoration({ type: p.strike ? TextDecorationType.LineThrough : TextDecorationType.None })
                .fontColor(p.code || p.link ? ZhihuColors.primary : ZhihuColors.text)
            })
          }
          .copyOption(CopyOptions.LocalDevice)
          .lineHeight(28)
          .width('100%')
        } else {
          Text() {
            ForEach(parseInline(b.text), (p: InlinePart) => {
              Span(p.text)
                .fontSize(19)
                .lineHeight(28)
                .fontWeight(p.bold ? FontWeight.Bold : FontWeight.Normal)
                .fontStyle(p.italic ? FontStyle.Italic : FontStyle.Normal)
                .decoration({ type: p.strike ? TextDecorationType.LineThrough : TextDecorationType.None })
                .fontColor(p.code || p.link ? ZhihuColors.primary : ZhihuColors.text)
            })
          }
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(19)
          .lineHeight(28)
          .width('100%')
        }
      }, (b: HtmlBlock, i: number) => i.toString() + b.url + b.text.substring(0, 8))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
