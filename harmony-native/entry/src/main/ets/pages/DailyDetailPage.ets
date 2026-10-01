/**
 * pages/DailyDetailPage —— 日报文章详情。
 * 上游：app/article/[id].tsx（source=daily 分支，用 getDailyDetail）。
 * 结构：DetailNavBar + 头图 + 标题 + hint + 正文（HTML 剥标签纯文本降级）。
 */

import { router, promptAction } from '@kit.ArkUI';
import { common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DailyDetailResponse,
  getDailyDetail,

} from '../api/daily';
import { readContentCache, writeContentCache } from '../utils/cacheStore';
import { ZhihuColors } from '../utils/theme';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { HtmlBlock, parseContent, readStringParam, parseInline, InlinePart, blocksToMarkdown, saveMarkdownToFile } from '../components/detail/detailUtils';
import { DetailActionBar } from '../components/detail/DetailActionBar';
import { RichBody } from '../components/detail/RichBody';
import { NetImage } from '../components/NetImage';
import { openZhihuUrl } from '../utils/zhihuRouter';
import { getArticleCollectionStatus, getAnswerCollectionStatus } from '../api/collection';
import { guardLogin } from '../components/detail/detailUtils';

interface CachedDaily { savedAt: number; data: DailyDetailResponse; }

@Entry
@Component
struct DailyDetailPage {
  @State storyId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State detail: DailyDetailResponse | null = null;
  @State bodyBlocks: HtmlBlock[] = [];
  @State bodyBlocksMain: HtmlBlock[] = [];
  @State originUrl: string = '';
  @State discussionUrl: string = '';
  @State collected: boolean = false;
  @State collectType: string = '';
  @State collectResourceId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';
  private fallbackTitle: string = '';

  onCollectPicked(): void {
    if (this.collectPicked === this.collectResourceId) {
      this.collected = true;
      this.collectPicked = '';
    }
  }

  private async refreshCollectionStatus(): Promise<void> {
    if (this.collectResourceId.length === 0) {
      this.collected = false;
      return;
    }
    try {
      const st = this.collectType === 'answer'
        ? await getAnswerCollectionStatus(this.collectResourceId, 1)
        : await getArticleCollectionStatus(this.collectResourceId, 1);
      this.collected = st.collected === true;
    } catch (e) {
      this.collected = false;
    }
  }

  /** 从「查看知乎原文」链接解析知乎站内条目（专栏文章/回答），供收藏夹使用。 */
  private parseZhihuTarget(): void {
    const u: string = this.originUrl;
    if (u.length === 0) {
      this.collectType = '';
      this.collectResourceId = '';
      return;
    }
    // 优先级：回答（含 question/{qid}/answer/{aid} 组合链接）→ 专栏文章 → 问题
    const a: RegExpExecArray | null = /\/answer\/(\d+)/.exec(u);
    if (a !== null) {
      this.collectType = 'answer';
      this.collectResourceId = a[1];
      return;
    }
    const m: RegExpExecArray | null = /zhuanlan\.zhihu\.com\/p\/(\d+)/.exec(u);
    if (m !== null) {
      this.collectType = 'article';
      this.collectResourceId = m[1];
      return;
    }
    const q: RegExpExecArray | null = /\/question\/(\d+)/.exec(u);
    if (q !== null) {
      this.collectType = 'question';
      this.collectResourceId = q[1];
      return;
    }
    this.collectType = '';
    this.collectResourceId = '';
  }

  private onCollect(): void {
    if (!guardLogin()) {
      return;
    }
    if (this.collectType === 'article' || this.collectType === 'answer') {
      router.pushUrl({
        url: 'pages/CollectionPickerPage',
        params: { resourceType: this.collectType, resourceId: this.collectResourceId },
      });
    } else if (this.collectType === 'question') {
      promptAction.showToast({ message: '知乎问题暂不支持收藏到收藏夹' });
    } else {
      promptAction.showToast({ message: '该日报内容暂无对应知乎条目，无法收藏' });
    }
  }

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.storyId = readStringParam(p, 'id');
    this.fallbackTitle = readStringParam(p, 'title');
    this.load();
  }

  private async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    // 先读缓存即时渲染
    let hadCache: boolean = false;
    const cached = readContentCache<CachedDaily>('daily', this.storyId);
    if (cached) {
      this.applyDailyDetail(cached.data as DailyDetailResponse);
      this.loading = false;
      hadCache = true;
    }
    try {
      const d: DailyDetailResponse = await getDailyDetail(this.storyId);
      this.detail = d;
      writeContentCache('daily', this.storyId, d as object);
      this.applyDailyDetail(d);
      this.error = '';
    } catch (e) {
      // 已有缓存时不显示错误，保留缓存内容
      if (!hadCache) {
        this.error = '日报内容加载失败，请稍后重试';
      }
    } finally {
      this.loading = false;
    }
  }

  private applyDailyDetail(d: DailyDetailResponse): void {
    this.detail = d;
    const bodyImgs: string[] = (d.images !== undefined && d.images.length > 1) ? d.images.slice(1) : [];
    let cleanedBody: string = d.body;
    cleanedBody = cleanedBody.replace(/<a[^>]*class="[^"]*originUrl[^"]*"[^>]*>[\s\S]*?<\/a>/gi, '');
    cleanedBody = cleanedBody.replace(/<a[^>]*href="[^"]*"[^>]*class="[^"]*originUrl[^"]*"[^>]*>[\s\S]*?<\/a>/gi, '');
    cleanedBody = cleanedBody.replace(/<div[^>]*class="[^"]*view-more[^"]*"[^>]*>[\s\S]*?<\/div>/gi, '');
    let blocks: HtmlBlock[] = this.fillPlaceholders(parseContent(cleanedBody), bodyImgs);
    for (let k = 0; k < blocks.length; k++) {
      if (blocks[k].type === 'image') {
        blocks[k] = { type: 'image', text: '__avatar__', url: blocks[k].url };
        break;
      }
    }
    const ou: RegExpExecArray | null = /<a[^>]*href="([^"]+)"[^>]*class="[^"]*originUrl[^"]*"[^>]*>/i.exec(d.body) || /<a[^>]*class="[^"]*originUrl[^"]*"[^>]*href="([^"]+)"/i.exec(d.body);
    if (ou !== null) {
      this.originUrl = ou[1];
    }
    this.parseZhihuTarget();
    const vm: RegExpExecArray | null = /<div[^>]*class="[^"]*view-more[^"]*"[^>]*>\s*<a[^>]*href="([^"]+)"/i.exec(d.body);
    if (vm !== null) {
      this.discussionUrl = vm[1];
    }
    this.bodyBlocks = blocks;
    // 剔除作者头像块与作者介绍文本块，正文统一走公共 RichBody 渲染
    const main: HtmlBlock[] = [];
    for (let i = 0; i < blocks.length; i++) {
      const b: HtmlBlock = blocks[i];
      if (b.type === 'image' && b.text === '__avatar__') {
        continue;
      }
      if (i > 0 && blocks[i - 1].type === 'image' && blocks[i - 1].text === '__avatar__') {
        continue;
      }
      main.push(b);
    }
    this.bodyBlocksMain = main;
  }

  /** 把正文文本里的 [图片] 字面占位，按顺序替换为正文图片块（对应 images[1..]）。
   *  第一个 [图片] 实际是答主头像（紧邻作者介绍文字），打 '__avatar__' 标记渲染成小圆形头像。 */
  private fillPlaceholders(blocks: HtmlBlock[], imgs: string[]): HtmlBlock[] {
    const out: HtmlBlock[] = [];
    let pi = 0;
    for (let i = 0; i < blocks.length; i++) {
      const b: HtmlBlock = blocks[i];
      if (b.type === 'text') {
        const parts: string[] = b.text.split('[图片]');
        for (let j = 0; j < parts.length; j++) {
          if (parts[j].length > 0) {
            out.push({ type: 'text', text: parts[j], url: '' });
          }
          if (j < parts.length - 1 && pi < imgs.length) {
            const tag: string = pi === 0 ? '__avatar__' : '';
            out.push({ type: 'image', text: tag, url: imgs[pi] });
            pi++;
          }
        }
      } else {
        out.push(b);
      }
    }
    return out;
  }

  private coverUrl(): string {
    const d = this.detail;
    if (!d) {
      return '';
    }
    if (d.image && d.image.length > 0) {
      return d.image;
    }
    if (d.images && d.images.length > 0 && d.images[0].length > 0) {
      return d.images[0];
    }
    return '';
  }

  /** app 内打开知乎原文/讨论页（解析 URL 路由到原生详情页；识别不了才回退浏览器） */
  private getAuthorText(idx: number): string {
    if (idx + 1 < this.bodyBlocks.length && this.bodyBlocks[idx + 1].type === 'text') {
      return this.bodyBlocks[idx + 1].text;
    }
    return '';
  }

  private avatarUrl(): string {
    for (let i = 0; i < this.bodyBlocks.length; i++) {
      const b: HtmlBlock = this.bodyBlocks[i];
      if (b.type === 'image' && b.text === '__avatar__') {
        return b.url;
      }
    }
    return '';
  }

  private authorText(): string {
    for (let i = 0; i < this.bodyBlocks.length - 1; i++) {
      const b: HtmlBlock = this.bodyBlocks[i];
      if (b.type === 'image' && b.text === '__avatar__' && this.bodyBlocks[i + 1].type === 'text') {
        return this.bodyBlocks[i + 1].text;
      }
    }
    return '';
  }

  private isAuthorText(idx: number): boolean {
    return idx > 0 && this.bodyBlocks[idx - 1].type === 'image' && this.bodyBlocks[idx - 1].text === '__avatar__';
  }

  private openOriginArticle(): void {
    if (this.originUrl.length === 0) return;
    if (openZhihuUrl(this.originUrl)) return;
    const ctx = getContext(this) as common.UIAbilityContext;
    const w: Want = { action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: this.originUrl };
    ctx.startAbility(w);
  }

  private openLink(url: string): void {
    if (url.length === 0) return;
    if (openZhihuUrl(url)) return;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const w: Want = { action: 'ohos.want.action.viewData', entities: ['entity.system.browsable'], uri: url };
      ctx.startAbility(w);
    } catch (e) {
    }
  }

  private openZhihuDiscussion(): void {
    // 查看知乎讨论 → 打开 question 详情页（app 内）
    const url: string = this.discussionUrl.length > 0 ? this.discussionUrl : (this.originUrl.length > 0 ? this.originUrl : (this.detail?.share_url ?? ''));
    if (url.length === 0) {
      return;
    }
    if (openZhihuUrl(url)) {
      return;
    }
    const ctx = getContext(this) as common.UIAbilityContext;
    const w: Want = {
      action: 'ohos.want.action.viewData',
      entities: ['entity.system.browsable'],
      uri: url,
    };
    ctx.startAbility(w);
  }

  private toastUnsupported(): void {
    promptAction.showToast({ message: '日报文章暂不支持点赞' });
  }

  private async saveContent(): Promise<void> {
    if (this.bodyBlocks.length === 0) {
      return;
    }
    try {
      const title: string = this.detail?.title ?? ('日报_' + this.storyId);
      const md: string = blocksToMarkdown(this.bodyBlocks, title, '');
      await saveMarkdownToFile(getContext(this), title, md);
    } catch (e) {
    }
  }

  build() {
    Column() {
      DetailNavBar({ title: this.detail ? this.detail.title : (this.fallbackTitle.length > 0 ? this.fallbackTitle : '日报') })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ loading: false, error: this.error, onRetry: () => this.load() })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            // 头图
            if (this.coverUrl().length > 0) {
              Image(this.coverUrl())
                .width('100%')
                .height(220)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
            }
            Column({ space: 10 }) {
              Text(this.detail?.title ?? '')
                .fontSize(21)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
                .width('100%')
              if (this.detail?.hint && this.detail.hint.length > 0) {
                Text(this.detail.hint)
                  .fontSize(15)
                  .fontColor(ZhihuColors.textSecondary)
                  .width('100%')
              }
              if (this.bodyBlocks.length > 0) {
                Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ top: 4, bottom: 4 })
                // 作者行：头像 + 介绍 + 查看知乎原文（头像块已从正文剔除）
                if (this.avatarUrl().length > 0) {
                  Row({ space: 10 }) {
                    NetImage({ url: this.avatarUrl(), w: 48, h: 48, r: 24 })
                    Column() {
                      Text(this.authorText())
                        .fontSize(15)
                        .fontColor(ZhihuColors.textSecondary)
                        .maxLines(2)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .layoutWeight(1)
                    if (this.originUrl.length > 0) {
                      Text('查看知乎原文 ›')
                        .fontSize(14)
                        .fontColor(ZhihuColors.primary)
                        .onClick(() => this.openOriginArticle())
                    }
                  }
                  .width('100%')
                }
                // 正文（公共富文本组件）
                RichBody({ blocks: this.bodyBlocksMain })
              } else {
                Text('正文暂无法展示')
                  .fontSize(16)
                  .fontColor(ZhihuColors.textTertiary)
                  .width('100%')
                  .padding({ top: 20 })
              }
            }
            .padding({ left: 16, right: 16, top: 12, bottom: 24 })
            if (this.detail?.share_url && this.detail.share_url.length > 0) {
              Divider().strokeWidth(0.5).color(ZhihuColors.divider).margin({ top: 8, bottom: 12 })
                .padding({ left: 16, right: 16 })
              Text('查看知乎讨论 ›')
                .fontSize(15)
                .fontColor(ZhihuColors.primary)
                .width('100%')
                .onClick(() => this.openZhihuDiscussion())
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 12 })
            }
            DetailActionBar({
              upvoteCount: 0,
              commentCount: 0,
              collected: this.collected,
              showDownvote: false,
              onUpvote: () => this.toastUnsupported(),
              onDownvote: () => {},
              onComment: () => this.openZhihuDiscussion(),
              onCollect: () => this.onCollect(),
              onSave: () => this.saveContent(),
            })
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .backgroundColor(ZhihuColors.backgroundSecondary)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
