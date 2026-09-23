/**
 * pages/AnswerDetailPage —— 回答详情。
 * 上游：app/answer/[id].tsx。
 * 结构：自绘导航栏 + 所属问题标题 + 作者 + 全文(纯文本降级) + 赞同/反对/收藏/评论。
 * 降级：HTML 正文剥标签后用 Text 渲染，不做 WebView。
 */

import hilog from '@ohos.hilog';
import { router, promptAction } from '@kit.ArkUI';
import { getAnswer, voteAnswer, AnswerDetail } from '../api/answer';
import { readContentCache, writeContentCache } from '../utils/cacheStore';

import { getAnswerCollectionStatus, removeFromCollection } from '../api/collection';
import { ZhihuColors } from '../utils/theme';
import { formatDate } from '../utils/date';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { writeDebugLog } from '../utils/debugLog';
import { DetailNavBar } from '../components/detail/DetailNavBar';
import { StatusView } from '../components/detail/StatusView';
import { formatCount, guardLogin, HtmlBlock, parseContent, readStringParam, blocksToMarkdown } from '../components/detail/detailUtils';
import { NetImage } from '../components/NetImage';
import { RichBody } from '../components/detail/RichBody';
import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { picker } from '@kit.CoreFileKit';

interface CachedAnswer { savedAt: number; data: AnswerDetail; }

@Entry
@Component
struct AnswerDetailPage {
  @State answerId: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State answer: AnswerDetail | null = null;
  @State voting: number = 0;
  @State voteCount: number = 0;
  @State collected: boolean = false;
  @State collectionId: string = '';
  @StorageLink('collectPicked') @Watch('onCollectPicked') collectPicked: string = '';
  @State bodyBlocks: HtmlBlock[] = [];

  onCollectPicked(): void {
    if (this.collectPicked === this.answerId) {
      this.collected = true;
      this.collectPicked = '';
    }
  }

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    this.answerId = readStringParam(p, 'id');
    this.load();
  }

  // 从写操作/评论返回时刷新（首次由 aboutToAppear 加载）
  onPageShow(): void {
    if (this.shownOnce) {
      this.load();
    }
    this.shownOnce = true;
  }
  private shownOnce: boolean = false;

  private async load(): Promise<void> {
    this.loading = true;
    hilog.info(0x3100, 'ZhihuLiteDBG', 'ANSWER load START id=%{public}s', this.answerId);
    this.error = '';
    this.refreshCollectionStatus();
    // 先读缓存即时渲染
    let hadCache: boolean = false;
    const cached = readContentCache<CachedAnswer>('answer', this.answerId);
    if (cached) {
      const a = cached.data;
      this.answer = a;
      this.voting = a.relationship?.voting ?? 0;
      this.voteCount = a.voteup_count ?? 0;
      this.bodyBlocks = parseContent(a.content);
      this.loading = false;
      hadCache = true;
    }
    try {
      const a: AnswerDetail = await getAnswer(this.answerId);
      this.answer = a;
      this.voting = a.relationship?.voting ?? 0;
      this.voteCount = a.voteup_count ?? 0;
      this.bodyBlocks = parseContent(a.content);
      writeContentCache('answer', this.answerId, a as object);
      const actx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      writeDebugLog(actx, 'ANSWER', 'id=' + this.answerId + ' len=' + a.content.length + ' preview=' + a.content.substring(0, 400));
      writeDebugLog(actx, 'ANSWER', 'blocks=' + JSON.stringify(this.bodyBlocks.map((b: HtmlBlock) => b.type)));
    } catch (e) {
      hilog.error(0x3100, 'ZhihuLiteDBG', 'ANSWER load FAIL id=%{public}s err=%{public}s', this.answerId, JSON.stringify(e as object));
      if (!hadCache) {
        this.error = getZhihuErrorMessage(e as object);
      }
    } finally {
      this.loading = false;
    }
  }

  private async onVote(target: number): Promise<void> {
    if (!guardLogin()) {
      return;
    }
    const prev: number = this.voting;
    const prevCount: number = this.voteCount;
    // 再点一次取消；赞同 ↔ 反对互切。
    const next: number = prev === target ? 0 : target;
    this.voting = next;
    if (next === 1) {
      this.voteCount = prev === 1 ? prevCount : prevCount + 1;
    } else if (next === 0 && prev === 1) {
      this.voteCount = Math.max(0, prevCount - 1);
    }
    const type: 'up' | 'down' | 'neutral' = next === 1 ? 'up' : (next === -1 ? 'down' : 'neutral');
    try {
      await voteAnswer(this.answerId, type);
    } catch (e) {
      this.voting = prev;
      this.voteCount = prevCount;
    }
  }

  /** 赞同者列表（对齐上游 app/answer/[id].tsx 赞同数入口）。 */
  private openVoters(): void {
    router.pushUrl({
      url: 'pages/VotersPage',
      params: {
        contentType: 'answer',
        contentId: this.answerId,
        count: String(this.voteCount),
      },
    });
  }

  private onComment(): void {
    router.pushUrl({
      url: 'pages/CommentsPage',      params: { resourceType: 'answers', resourceId: this.answerId },
    });
  }

  /** 查询该回答是否已被收藏 */
  private async refreshCollectionStatus(): Promise<void> {
    if (this.answerId.length === 0) {
      return;
    }
    try {
      const st = await getAnswerCollectionStatus(this.answerId, 1);
      if (st.collected === true) {
        this.collected = true;
        const list = st.data ?? [];
        if (list.length > 0) {
          const first = list[0] as Record<string, object>;
          this.collectionId = String(first['id'] ?? '');
        }
      }
    } catch (e) {
      // 状态查询失败不阻塞页面
    }
  }

  private onCollect(): void {
    if (!guardLogin()) {
      return;
    }
    router.pushUrl({
      url: 'pages/CollectionPickerPage',
      params: { resourceType: 'answer', resourceId: this.answerId },
    });
  }

  private async saveContent(): Promise<void> {
    if (this.bodyBlocks.length === 0) {
      promptAction.showToast({ message: '内容为空，无法保存' });
      return;
    }
    try {
      const title: string = (this.answer?.question?.title ?? '').length > 0 ? this.answer!.question!.title : '回答_' + this.answerId;
      const author: string = this.answer?.author?.name ?? '';
      const md: string = blocksToMarkdown(this.bodyBlocks, title, author);
      const safeTitle: string = title.replace(/[^\u4e00-\u9fa5a-zA-Z0-9]/g, '_').substring(0, 50);
      const fileName: string = safeTitle + '.md';
      // 先存沙箱临时文件，再通过系统选择器让用户保存到公共位置
      const actx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
      const tmpPath: string = actx.filesDir + '/tmp_save.md';
      const f = fileIo.openSync(tmpPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      fileIo.writeSync(f.fd, md);
      fileIo.closeSync(f);
      // 用 DocumentViewPicker 让用户选保存位置
      const docPicker = new picker.DocumentViewPicker();
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [safeTitle];
      
      const uris: string[] = await docPicker.save(saveOptions);
      if (uris.length > 0) {
        // 用户选了位置，把内容写进去
        const destUri: string = uris[0];
        const destFile = fileIo.openSync(destUri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
        fileIo.writeSync(destFile.fd, md);
        fileIo.closeSync(destFile);
        promptAction.showToast({ message: '已保存到文件管理器' });
      }
    } catch (e) {
      const errMsg: string = e instanceof Error ? e.message : JSON.stringify(e);
      promptAction.showToast({ message: '保存失败: ' + errMsg.substring(0, 50) });
    }
  }

  private metaText(): string {
    const a = this.answer;
    if (a === null) {
      return '';
    }
    const parts: string[] = [];
    if (a.created_time && a.created_time > 0) {
      parts.push('发布于 ' + formatDate(a.created_time));
    }
    if (a.updated_time && a.updated_time > 0) {
      parts.push('编辑于 ' + formatDate(a.updated_time));
    }
    if (a.ip_info !== undefined && a.ip_info.length > 0) {
      parts.push(a.ip_info);
    }
    return parts.join(' · ');
  }

  build() {
    Column() {
      DetailNavBar({ title: '回答' })

      if (this.loading) {
        StatusView({ loading: true })
      } else if (this.error.length > 0) {
        StatusView({ error: this.error, onRetry: () => { this.load(); } })
      } else if (this.answer !== null) {
        Scroll() {
          Column({ space: 12 }) {
            // 所属问题
            if (this.answer.question !== undefined && this.answer.question.title.length > 0) {
              Text(this.answer.question.title)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(ZhihuColors.text)
                .width('100%')
                .textAlign(TextAlign.Start)
            }

            // 作者行
            Row({ space: 10 }) {
              Image(this.answer.author.avatar_url)
                .width(40).height(40).borderRadius(20)
                .objectFit(ImageFit.Cover)
                .backgroundColor(ZhihuColors.backgroundTertiary)
              Column({ space: 2 }) {
                Text(this.answer.author.name)
                  .fontSize(17).fontWeight(FontWeight.Medium).fontColor(ZhihuColors.text)
                if (this.answer.author.headline && this.answer.author.headline.length > 0) {
                  Text(this.answer.author.headline)
                    .fontSize(14).fontColor(ZhihuColors.textTertiary)
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)

            RichBody({ blocks: this.bodyBlocks })

            if (this.metaText().length > 0) {
              Text(this.metaText())
                .fontSize(14)
                .fontColor(ZhihuColors.textTertiary)
                .width('100%')
            }
          }
          .width('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .backgroundColor(ZhihuColors.backgroundSecondary)

        // 操作条
        Row({ space: 4 }) {
          Row({ space: 4 }) {
            Text(this.voting === 1 ? '▲' : '△')
              .fontSize(16)
              .fontColor(this.voting === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
            Text(formatCount(this.voteCount))
              .fontSize(16)
              .fontColor(this.voting === 1 ? ZhihuColors.primary : ZhihuColors.textSecondary)
              .onClick(() => {
                this.openVoters();
              })
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onVote(1);
          })

          Row({ space: 4 }) {
            Text(this.voting === -1 ? '▼' : '▽')
              .fontSize(16)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
            Text('反对')
              .fontSize(16)
              .fontColor(this.voting === -1 ? ZhihuColors.danger : ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onVote(-1);
          })

          Row({ space: 4 }) {
            Text('○')
              .fontSize(16)
              .fontColor(ZhihuColors.textTertiary)
            Text(formatCount(this.answer.comment_count))
              .fontSize(15)
              .fontColor(ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onComment();
          })

          Row({ space: 4 }) {
            Text(this.collected ? '★' : '☆')
              .fontSize(17)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
            Text(this.collected ? '已收藏' : '收藏')
              .fontSize(16)
              .fontColor(this.collected ? ZhihuColors.warning : ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.onCollect();
          })

          Row({ space: 4 }) {
            Text('💾')
              .fontSize(16)
              .fontColor(ZhihuColors.textSecondary)
            Text('保存')
              .fontSize(16)
              .fontColor(ZhihuColors.textSecondary)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .onClick(() => {
            this.saveContent();
          })
        }
        .width('100%')
        .backgroundColor(ZhihuColors.backgroundSecondary)
        .border({ width: { top: 0.5 }, color: ZhihuColors.border })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
