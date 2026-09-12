/**
 * pages/CommentsPage —— 评论页（对齐 Android v0.6.0 截图 03，移植自上游 app/comments）。
 * 入参（router params）：
 *   resourceType: 'answers' | 'questions' | 'articles' | 'pins'
 *   resourceId:    string
 *   text?:        string（可选，顶部引用的正文摘要）
 * 结构：顶部栏(返回 + 评论(N) + 排序入口) + 一级评论卡片(头像/名字/正文/时间·地点/▲赞同/回复)
 *       + 二级回复(缩进卡片,「作者: 内容」) + 折叠「查看全部 N 条回复 →」 + 底部固定输入条(发布)。
 * 数据请求/点赞/发表评论逻辑沿用既有函数，仅重排 UI。
 */

import { router } from '@kit.ArkUI';
import {
  CommentItem,
  CommentResourceType,
  ZhihuCommentResponse,
  getAnswerCommentsV5,
  getQuestionCommentsV5,
  getArticleCommentsV5,
  getPinCommentsV5,
  getChildCommentsV5,
  createCommentV5,
  voteComment,
} from '../api/comment';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { formatRelativeTime } from '../utils/date';
import { stripHtml } from '../components/interaction/textUtil';

interface RootChildState {
  rootKey: string;
  children: CommentItem[];
}

@Entry
@Component
struct CommentsPage {
  @State resourceType: string = 'answers';
  @State resourceId: string = '';
  @State quote: string = '';

  @State orderBy: string = 'score';
  @State comments: CommentItem[] = [];
  @State commentTotal: number = 0;
  @State loading: boolean = true;
  @State error: string = '';
  @State loadingMore: boolean = false;
  @State isEnd: boolean = false;

  @State expandedRootKey: string = '';
  @State childList: CommentItem[] = [];
  @State childLoading: boolean = false;

  @State inputText: string = '';
  @State replyToId: string = '';
  @State replyToName: string = '';
  @State submitting: boolean = false;
  @State toast: string = '';

  private cursor: string = '';
  private inFlight: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      this.resourceType = String(p['resourceType'] ?? 'answers');
      this.resourceId = String(p['resourceId'] ?? '');
      this.quote = stripHtml(String(p['text'] ?? ''));
    }
    this.loadFirst();
  }

  private typedResourceType(): CommentResourceType {
    if (this.resourceType === 'questions') {
      return 'questions';
    }
    if (this.resourceType === 'articles') {
      return 'articles';
    }
    if (this.resourceType === 'pins') {
      return 'pins';
    }
    return 'answers';
  }

  private fetchRoot(limit: number, offset: string): Promise<ZhihuCommentResponse> {
    const rt: CommentResourceType = this.typedResourceType();
    const id: string = this.resourceId;
    if (rt === 'questions') {
      return getQuestionCommentsV5(id, limit, offset, this.orderBy);
    }
    if (rt === 'articles') {
      return getArticleCommentsV5(id, limit, offset, this.orderBy);
    }
    if (rt === 'pins') {
      return getPinCommentsV5(id, limit, offset, this.orderBy);
    }
    return getAnswerCommentsV5(id, limit, offset, this.orderBy);
  }

  async loadFirst(): Promise<void> {
    this.loading = true;
    this.error = '';
    this.inFlight = true;
    this.cursor = '';
    this.expandedRootKey = '';
    this.childList = [];
    try {
      const resp = await this.fetchRoot(20, '');
      this.comments = resp.data;
      this.commentTotal = resp.paging.totals;
      this.applyPaging(resp);
    } catch (e) {
      this.error = '评论加载失败，请稍后重试';
    } finally {
      this.loading = false;
      this.inFlight = false;
    }
  }

  async loadMore(): Promise<void> {
    if (this.inFlight || this.isEnd || this.cursor.length === 0) {
      return;
    }
    this.inFlight = true;
    this.loadingMore = true;
    try {
      const resp = await this.fetchRoot(20, this.cursor);
      this.comments = this.comments.concat(resp.data);
      this.applyPaging(resp);
    } catch (e) {
      // 翻页失败保留已加载
    } finally {
      this.inFlight = false;
      this.loadingMore = false;
    }
  }

  private applyPaging(resp: ZhihuCommentResponse): void {
    this.isEnd = resp.paging.is_end;
    const next: string = resp.paging.next;
    this.cursor = '';
    if (next.length > 0) {
      const m = next.match(/offset=([^&]*)/);
      if (m !== null && m.length > 1) {
        this.cursor = m[1];
      }
    }
  }

  private rootKey(item: CommentItem): string {
    return String(item.id);
  }

  private memberName(item: CommentItem): string {
    const m = item.author === undefined ? undefined : item.author.member;
    if (m === undefined || m === null) {
      return '匿名用户';
    }
    return m.name.length > 0 ? m.name : '匿名用户';
  }

  private avatarUrl(item: CommentItem): string {
    const m = item.author === undefined ? undefined : item.author.member;
    if (m === undefined || m === null) {
      return '';
    }
    return m.avatar_url;
  }

  private liked(item: CommentItem): boolean {
    const rel = item.relationship;
    return rel !== undefined && rel !== null && rel.voting === 1;
  }

  private voteCount(item: CommentItem): number {
    const vc = item.vote_count;
    return vc === undefined ? 0 : vc;
  }

  private metaText(item: CommentItem): string {
    const parts: string[] = [];
    if (item.created_time > 0) {
      parts.push(formatRelativeTime(item.created_time));
    }
    const addr = item.address_text;
    if (addr !== undefined && addr !== null && addr.length > 0) {
      parts.push(addr);
    }
    return parts.join(' · ');
  }

  // ---------------- 点赞 ----------------
  async handleLike(item: CommentItem): Promise<void> {
    if (!authStore.isLoggedIn) {
      this.gotoLogin();
      return;
    }
    const currentlyLiked: boolean = this.liked(item);
    const action: string = currentlyLiked ? 'neutral' : 'up';
    try {
      await voteComment(item.id, action);
      // 本地更新点赞态
      const next: CommentItem[] = [];
      for (const c of this.comments) {
        if (String(c.id) === String(item.id)) {
          const cloned: CommentItem = {
            id: c.id,
            type: c.type,
            content: c.content,
            created_time: c.created_time,
            child_comment_count: c.child_comment_count,
            child_comments: c.child_comments,
            author: c.author,
          };
          cloned.relationship = { voting: currentlyLiked ? 0 : 1 };
          const base = c.vote_count === undefined ? 0 : c.vote_count;
          cloned.vote_count = currentlyLiked ? Math.max(0, base - 1) : base + 1;
          next.push(cloned);
        } else {
          next.push(c);
        }
      }
      this.comments = next;
    } catch (e) {
      this.showToast('操作失败');
    }
  }

  // ---------------- 回复 ----------------
  handleReply(item: CommentItem): void {
    if (!authStore.isLoggedIn) {
      this.gotoLogin();
      return;
    }
    this.replyToId = String(item.id);
    const m = item.author === undefined ? undefined : item.author.member;
    this.replyToName = m === undefined ? '' : m.name;
  }

  cancelReply(): void {
    this.replyToId = '';
    this.replyToName = '';
  }

  // ---------------- 展开二级回复 ----------------
  async handleExpand(item: CommentItem): Promise<void> {
    const key: string = this.rootKey(item);
    if (this.expandedRootKey === key) {
      this.expandedRootKey = '';
      this.childList = [];
      return;
    }
    this.expandedRootKey = key;
    this.childLoading = true;
    try {
      const resp = await getChildCommentsV5(item.id, 30, '');
      this.childList = resp.data;
    } catch (e) {
      this.showToast('回复加载失败');
    } finally {
      this.childLoading = false;
    }
  }

  // ---------------- 发送 ----------------
  async sendComment(): Promise<void> {
    if (!authStore.isLoggedIn) {
      this.gotoLogin();
      return;
    }
    const text: string = this.inputText.trim();
    if (text.length === 0) {
      this.showToast('请输入评论内容');
      return;
    }
    this.submitting = true;
    try {
      if (this.replyToId.length > 0) {
        await createCommentV5(this.typedResourceType(), this.resourceId, text, this.replyToId);
      } else {
        await createCommentV5(this.typedResourceType(), this.resourceId, text);
      }
      this.showToast('发布成功');
      this.inputText = '';
      this.cancelReply();
      await this.loadFirst();
    } catch (e) {
      this.showToast('发布失败，请稍后重试');
    } finally {
      this.submitting = false;
    }
  }

  gotoLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' });
  }

  private showToast(msg: string): void {
    this.toast = msg;
  }

  toggleOrder(): void {
    this.orderBy = this.orderBy === 'score' ? 'ts' : 'score';
    this.loadFirst();
  }

  @Builder
  childRow(child: CommentItem) {
    // 二级回复：小头像 +「作者: 内容」
    Row({ space: 6 }) {
      Image(this.avatarUrl(child))
        .width(20)
        .height(20)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
        .backgroundColor(ZhihuColors.backgroundTertiary)
      Column({ space: 2 }) {
        Text(this.memberName(child) + '：' + stripHtml(child.content))
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(14)
          .fontColor(ZhihuColors.text)
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(19)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  childBlock(item: CommentItem) {
    Column({ space: 8 }) {
      if (this.expandedRootKey === this.rootKey(item)) {
        if (this.childLoading) {
          Row({ space: 6 }) {
            LoadingProgress().width(14).height(14).color(ZhihuColors.textTertiary)
            Text('回复加载中…')
              .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
          }
          .width('100%')
        } else if (this.childList.length === 0) {
          Text('暂无回复')
            .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary).width('100%')
        } else {
          ForEach(this.childList, (child: CommentItem) => {
            this.childRow(child)
          }, (child: CommentItem) => String(child.id))
          Text('收起回复')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.primary)
            .width('100%')
            .onClick(() => {
              this.handleExpand(item);
            })
        }
      } else if (item.child_comments.length > 0) {
        // 未展开：预览预置前两条二级回复
        ForEach(item.child_comments, (child: CommentItem, index: number) => {
          if (index < 2) {
            this.childRow(child)
          }
        }, (child: CommentItem, index: number) => String(child.id) + '-' + String(index))
        Text('查看全部 ' + item.child_comment_count + ' 条回复 →')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontColor(ZhihuColors.primary)
          .width('100%')
          .onClick(() => {
            this.handleExpand(item);
          })
      }
    }
    .width('100%')
    .padding(10)
    .margin({ left: 40 })
    .backgroundColor(ZhihuColors.backgroundTertiary)
    .borderRadius(8)
  }

  @Builder
  rootComment(item: CommentItem) {
    Column({ space: 8 }) {
      // 作者行：头像 + 名字
      Row({ space: 10 }) {
        Image(this.avatarUrl(item))
          .width(36)
          .height(36)
          .borderRadius(18)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
        Text(this.memberName(item))
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .layoutWeight(1)
      }
      .width('100%')

      // 正文
      Text(stripHtml(item.content))
        .copyOption(CopyOptions.LocalDevice)
        .fontSize(16)
        .fontColor(ZhihuColors.text)
        .width('100%')
        .textAlign(TextAlign.Start)
        .lineHeight(22)

      // 元信息行：时间·地点（左） + ▲赞同 + 回复（右）
      Row() {
        if (this.metaText(item).length > 0) {
          Text(this.metaText(item))
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
            .layoutWeight(1)
        } else {
          Blank().layoutWeight(1)
        }

        Row({ space: 4 }) {
          Text('▲')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(this.liked(item) ? ZhihuColors.primary : ZhihuColors.textTertiary)
          Text(String(this.voteCount(item)))
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.textTertiary)
        }
        .padding({ left: 8, right: 8 })
        .onClick(() => {
          this.handleLike(item);
        })

        Text('回复')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontColor(ZhihuColors.textTertiary)
          .padding({ left: 8, right: 4 })
          .onClick(() => {
            this.handleReply(item);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  @Builder
  inputBar() {
    Column() {
      if (!authStore.isLoggedIn) {
        Row() {
          Text('登录后即可参与评论')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(15)
            .fontColor(ZhihuColors.textTertiary)
            .layoutWeight(1)
          Button('去登录')
            .fontSize(14)
            .height(34)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.gotoLogin();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor(ZhihuColors.backgroundSecondary)
      } else {
        if (this.replyToId.length > 0) {
          Row({ space: 8 }) {
            Text('回复 ' + this.replyToName)
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13)
              .fontColor(ZhihuColors.primary)
              .layoutWeight(1)
            Text('取消')
              .copyOption(CopyOptions.LocalDevice)
              .fontSize(13)
              .fontColor(ZhihuColors.textTertiary)
              .onClick(() => {
                this.cancelReply();
              })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 6 })
        }
        Row({ space: 10 }) {
          TextInput({ placeholder: '既然来了，就留下点什么吧...', text: this.inputText })
            .layoutWeight(1)
            .height(40)
            .backgroundColor(ZhihuColors.backgroundTertiary)
            .borderRadius(20)
            .padding({ left: 14, right: 14 })
            .fontSize(15)
            .onChange((v: string) => {
              this.inputText = v;
            })
          Text(this.submitting ? '…' : '发布')
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(ZhihuColors.primary)
            .padding({ left: 6, right: 6 })
            .onClick(() => {
              this.sendComment();
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        .backgroundColor(ZhihuColors.backgroundSecondary)
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      // 顶部栏：返回 + 标题「评论 (N)」 + 右侧排序入口
      Row() {
        Text('‹')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(26)
          .fontColor(ZhihuColors.primary)
          .padding({ left: 4, right: 8 })
          .onClick(() => {
            router.back();
          })
        Text('评论 (' + this.commentTotal + ')')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ZhihuColors.text)
          .layoutWeight(1)
        Text(this.orderBy === 'score' ? '默认' : '最新')
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(15)
          .fontColor(ZhihuColors.primary)
          .padding(8)
          .onClick(() => {
            this.toggleOrder();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(ZhihuColors.backgroundSecondary)

      if (this.loading && this.comments.length === 0) {
        Column({ space: 8 }) {
          LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
          Text('评论加载中…')
            .copyOption(CopyOptions.LocalDevice).fontSize(14).fontColor(ZhihuColors.textTertiary)
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.comments.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
            .copyOption(CopyOptions.LocalDevice).fontSize(15).fontColor(ZhihuColors.textSecondary)
          Button('重试')
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadFirst();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ scroller: this.scroller }) {
          if (this.quote.length > 0) {
            ListItem() {
              Column({ space: 4 }) {
                Text('正在讨论')
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(13)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ZhihuColors.primary)
                Text(this.quote)
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(14)
                  .fontColor(ZhihuColors.textSecondary)
                  .maxLines(3)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .textAlign(TextAlign.Start)
              }
              .width('100%')
              .padding(12)
              .backgroundColor(ZhihuColors.backgroundTertiary)
              .borderRadius(10)
              .alignItems(HorizontalAlign.Start)
            }
          }

          ForEach(this.comments, (item: CommentItem) => {
            ListItem() {
              Column() {
                this.rootComment(item)
                if (item.child_comment_count > 0) {
                  this.childBlock(item)
                }
                Divider().strokeWidth(0.5).color(ZhihuColors.border)
              }
              .width('100%')
            }
          }, (item: CommentItem) => this.rootKey(item))

          ListItem() {
            Column({ space: 6 }) {
              if (this.loadingMore) {
                Row({ space: 8 }) {
                  LoadingProgress().width(16).height(16).color(ZhihuColors.textTertiary)
                  Text('加载中…')
                    .copyOption(CopyOptions.LocalDevice).fontSize(13).fontColor(ZhihuColors.textTertiary)
                }
              } else if (this.isEnd && this.comments.length > 0) {
                Text('— 没有更多评论了 —')
                  .copyOption(CopyOptions.LocalDevice)
                  .fontSize(13)
                  .fontColor(ZhihuColors.textTertiary)
              }
            }
            .width('100%')
            .padding(14)
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .onReachEnd(() => {
          this.loadMore();
        })
        .padding({ left: 14, right: 14 })
      }

      if (this.toast.length > 0) {
        Text(this.toast)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(13)
          .fontColor(ZhihuColors.textInverse)
          .backgroundColor('#b3000000')
          .borderRadius(6)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      }

      this.inputBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
