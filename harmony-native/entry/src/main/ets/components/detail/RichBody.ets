/**
 * components/detail/RichBody —— 正文富文本渲染组件。
 * 连续文本块合并为单个 Text，支持跨段选择；图片单独渲染。
 */

import { HtmlBlock, parseInline, InlinePart } from './detailUtils';
import { ZhihuColors } from '../../utils/theme';
import { NetImage } from '../NetImage';
import { common, Want } from '@kit.AbilityKit';
import { openZhihuUrl } from '../../utils/zhihuRouter';

/** 预计算渲染项：文本组（含扁平 spans）、链接组或图片 */
interface RenderItem {
  isImage: boolean;
  imageUrl: string;
  spans: FlattenedSpan[];
  linkUrl: string;
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
    // 知乎站内链接优先在 app 内打开
    if (openZhihuUrl(url)) {
      return;
    }
    // 外部链接用系统浏览器
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

  /** 把 blocks 分成文本组/链接组/图片组；链接 span 拆为独立可点击项 */
  private getItems(): RenderItem[] {
    const items: RenderItem[] = [];
    let curSpans: FlattenedSpan[] | null = null;
    const flush = (): void => {
      if (curSpans !== null && curSpans.length > 0) {
        items.push({ isImage: false, imageUrl: '', spans: curSpans, linkUrl: '' });
        curSpans = null;
      }
    };
    for (let i = 0; i < this.blocks.length; i++) {
      const b: HtmlBlock = this.blocks[i];
      if (b.type === 'image') {
        flush();
        items.push({ isImage: true, imageUrl: b.url, spans: [], linkUrl: '' });
        continue;
      }
      let fs: number = 19;
      let fw: FontWeight = FontWeight.Normal;
      let fc: ResourceColor = ZhihuColors.text;
      let fst: FontStyle = FontStyle.Normal;
      if (b.type === 'heading') { fs = 22; fw = FontWeight.Bold; }
      else if (b.type === 'quote') { fs = 18; fst = FontStyle.Italic; fc = ZhihuColors.textSecondary; }
      else if (b.type === 'code') { fs = 16; fc = ZhihuColors.text; }
      const parts = parseInline(b.text);
      for (let j = 0; j < parts.length; j++) {
        const p = parts[j];
        // 段间换行（进入新块或链接前先补一个换行）
        const needBr = j === 0 && curSpans !== null && curSpans.length > 0;
        if (needBr) {
          curSpans!.push({ text: '\n', fontSize: 19, fontWeight: FontWeight.Normal,
            fontStyle: FontStyle.Normal, fontColor: ZhihuColors.text, lineHeight: 28, strike: false });
        }
        if (p.link && p.url !== undefined) {
          // 链接单独成项
          if (curSpans !== null && curSpans.length > 0) {
            items.push({ isImage: false, imageUrl: '', spans: curSpans, linkUrl: '' });
            curSpans = null;
          }
          const linkSpans: FlattenedSpan[] = [{
            text: p.text, fontSize: fs, fontWeight: p.bold ? FontWeight.Bold : fw,
            fontStyle: p.italic ? FontStyle.Italic : fst,
            fontColor: ZhihuColors.primary, lineHeight: 28, strike: p.strike,
          }];
          items.push({ isImage: false, imageUrl: '', spans: linkSpans, linkUrl: p.url });
        } else {
          if (curSpans === null) {
            curSpans = [];
          }
          curSpans.push({
            text: p.text, fontSize: fs, fontWeight: p.bold ? FontWeight.Bold : fw,
            fontStyle: p.italic ? FontStyle.Italic : fst,
            fontColor: p.code ? ZhihuColors.primary : fc, lineHeight: 28, strike: p.strike,
          });
        }
      }
    }
    flush();
    return items;
  }

  build() {
    Column() {
      ForEach(this.getItems(), (item: RenderItem, idx: number) => {
        if (item.isImage) {
          NetImage({ url: item.imageUrl, w: 0, h: 260, r: 8, fit: ImageFit.Contain, mt: 4, tapView: true })
        } else if (item.linkUrl.length > 0) {
          Text() {
            ForEach(item.spans, (s: FlattenedSpan, si: number) => {
              Span(s.text)
                .fontSize(s.fontSize)
                .lineHeight(s.lineHeight)
                .fontWeight(s.fontWeight)
                .fontStyle(s.fontStyle)
                .decoration({ type: TextDecorationType.Underline })
                .fontColor(ZhihuColors.primary)
            }, (s: FlattenedSpan, si: number) => si.toString() + s.text.substring(0, 4))
          }
          .fontSize(19)
          .lineHeight(28)
          .width('100%')
          .margin({ bottom: 4 })
          .onClick(() => {
            this.openLink(item.linkUrl);
          })
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
