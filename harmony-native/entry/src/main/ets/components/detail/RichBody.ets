/**
 * components/detail/RichBody —— 正文富文本渲染组件。
 * 连续文本块合并为单个 Text，支持跨段选择；图片单独渲染。
 */

import { HtmlBlock, parseInline, InlinePart } from './detailUtils';
import { ZhihuColors } from '../../utils/theme';
import { NetImage } from '../NetImage';
import { common, Want } from '@kit.AbilityKit';

/** 预计算渲染项：文本组（含扁平 spans）或图片 */
interface RenderItem {
  isImage: boolean;
  imageUrl: string;
  spans: FlattenedSpan[];
}

interface FlattenedSpan {
  text: string;
  fontSize: number;
  fontWeight: FontWeight;
  fontStyle: FontStyle;
  fontColor: ResourceColor;
  lineHeight: number;
  strike: boolean;
}

@Component
export struct RichBody {
  blocks: HtmlBlock[] = [];

  private openLink(url: string): void {
    if (url.length === 0) return;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const w: Want = {
        action: 'ohos.want.action.viewData',
        entities: ['entity.system.browsable'],
        uri: url,
      };
      ctx.startAbility(w);
    } catch (e) {
    }
  }

  /** 把 blocks 分成文本组和图片组，文本组预计算扁平 spans */
  private getItems(): RenderItem[] {
    const items: RenderItem[] = [];
    let curSpans: FlattenedSpan[] | null = null;
    for (let i = 0; i < this.blocks.length; i++) {
      const b: HtmlBlock = this.blocks[i];
      if (b.type === 'image') {
        curSpans = null;
        const item: RenderItem = { isImage: true, imageUrl: b.url, spans: [] };
        items.push(item);
      } else {
        if (curSpans === null) {
          curSpans = [];
          const item: RenderItem = { isImage: false, imageUrl: '', spans: curSpans };
          items.push(item);
        }
        // 段间换行
        if (curSpans.length > 0) {
          curSpans.push({ text: '\n', fontSize: 19, fontWeight: FontWeight.Normal,
            fontStyle: FontStyle.Normal, fontColor: ZhihuColors.text, lineHeight: 28, strike: false });
        }
        const parts = parseInline(b.text);
        let fs: number = 19;
        let fw: FontWeight = FontWeight.Normal;
        let fc: ResourceColor = ZhihuColors.text;
        let fst: FontStyle = FontStyle.Normal;
        if (b.type === 'heading') { fs = 22; fw = FontWeight.Bold; }
        else if (b.type === 'quote') { fs = 18; fst = FontStyle.Italic; fc = ZhihuColors.textSecondary; }
        else if (b.type === 'code') { fs = 16; fc = ZhihuColors.text; }
        for (let j = 0; j < parts.length; j++) {
          const p = parts[j];
          curSpans.push({
            text: p.text,
            fontSize: fs,
            fontWeight: p.bold ? FontWeight.Bold : fw,
            fontStyle: p.italic ? FontStyle.Italic : fst,
            fontColor: p.code || p.link ? ZhihuColors.primary : fc,
            lineHeight: 28,
            strike: p.strike,
          });
        }
      }
    }
    return items;
  }

  build() {
    Column() {
      ForEach(this.getItems(), (item: RenderItem, idx: number) => {
        if (item.isImage) {
          NetImage({ url: item.imageUrl, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
        } else {
          Text() {
            ForEach(item.spans, (s: FlattenedSpan, si: number) => {
              Span(s.text)
                .fontSize(s.fontSize)
                .lineHeight(s.lineHeight)
                .fontWeight(s.fontWeight)
                .fontStyle(s.fontStyle)
                .decoration({ type: s.strike ? TextDecorationType.LineThrough : TextDecorationType.None })
                .fontColor(s.fontColor)
            }, (s: FlattenedSpan, si: number) => si.toString() + s.text.substring(0, 4))
          }
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(19)
          .lineHeight(28)
          .width('100%')
          .margin({ bottom: 4 })
        }
      }, (item: RenderItem, idx: number) => idx.toString())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
