/**
 * pages/ChatPage —— 与某用户的私信会话。
 * 上游: ~/workbuddy/zhihu--/app/chat/[id].tsx
 * 入参: { threadId?: string, userId?: string, name?: string }
 * API: getMessages(otherId)、sendMessage(otherId, text)
 * 降级: 无 WebSocket/长连接，进入拉一次历史，手动发送后把返回消息追加到列表；
 *       上游的 5 秒轮询已省略；图片消息只显示“[图片消息]”。
 * 说明: 知乎 GET 返回里 info.user_type === 'receiver' 表示“是我发的”（与字面相反）。
 */

import { router } from '@kit.ArkUI';
import { getMessages, sendMessage, ChatMessage } from '../api/chat';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { getZhihuErrorMessage } from '../utils/zhihuError';
import { readStringParam } from '../components/detail/detailUtils';

@Entry
@Component
struct ChatPage {
  @State messages: ChatMessage[] = [];
  @State input: string = '';
  @State loading: boolean = true;
  @State error: string = '';
  @State sending: boolean = false;
  @State peerName: string = '聊天';
  private otherId: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    const uid = readStringParam(p, 'userId');
    const tid = readStringParam(p, 'threadId');
    const nm = readStringParam(p, 'name');
    this.otherId = uid.length > 0
      ? uid
      : tid;
    if (nm.length > 0) {
      this.peerName = nm;
    }
    this.loadHistory();
  }

  private async loadHistory(): Promise<void> {
    if (this.otherId.length === 0) {
      this.loading = false;
      this.error = '缺少会话参数';
      return;
    }
    this.loading = true;
    this.error = '';
    try {
      const result = await getMessages(this.otherId);
      this.messages = result.data;
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.loading = false;
    }
  }

  private async doSend(): Promise<void> {
    const text: string = this.input.trim();
    if (text.length === 0 || this.sending || this.otherId.length === 0) {
      return;
    }
    this.sending = true;
    try {
      const msg = await sendMessage(this.otherId, text);
      this.messages.push(msg);
      this.input = '';
    } catch (e) {
      this.error = getZhihuErrorMessage(e as object);
    } finally {
      this.sending = false;
    }
  }

  private isMe(msg: ChatMessage): boolean {
    return msg.info.user_type === 'receiver';
  }

  private bubbleText(msg: ChatMessage): string {
    if (msg.info.content_type === 0) {
      return msg.info.text;
    }
    if (msg.info.content_type === 1) {
      return '[图片消息]';
    }
    return '[未知消息类型]';
  }

  @Builder
  topBar() {
    Row() {
      Text('←')
        .fontSize(22)
        .fontColor(ZhihuColors.text)
        .width(40)
        .onClick(() => {
          router.back();
        })
      Blank()
      Text(this.peerName)
        .fontSize(19)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
        .maxLines(1)
      Blank()
      Text('   ')
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  messageList() {
    List({ space: 10, scroller: this.scroller }) {
      ForEach(this.messages, (msg: ChatMessage, index: number) => {
        ListItem() {
          Row() {
            Column() {
              Text(this.bubbleText(msg))
                .fontSize(17)
                .fontColor(this.isMe(msg) ? ZhihuColors.textInverse : ZhihuColors.text)
                .padding({ left: 14, right: 14, top: 9, bottom: 9 })
                .backgroundColor(this.isMe(msg) ? ZhihuColors.primary : ZhihuColors.backgroundSecondary)
                .borderRadius(16)
                .constraintSize({ maxWidth: '72%' })
            }
            .width('100%')
            .alignItems(this.isMe(msg) ? HorizontalAlign.End : HorizontalAlign.Start)
          }
          .width('100%')
        }
      }, (msg: ChatMessage, index: number) => msg.info.id + '_' + String(index))
    }
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .scrollBar(BarState.Off)
  }

  @Builder
  inputBar() {
    Row({ space: 10 }) {
      TextInput({ text: $$this.input, placeholder: '发送私信…' })
        .layoutWeight(1)
        .height(42)
        .backgroundColor(ZhihuColors.backgroundTertiary)
        .borderRadius(21)
        .placeholderColor(ZhihuColors.textTertiary)
        .padding({ left: 16, right: 16 })
      if (this.sending) {
        LoadingProgress().width(38).height(38).color(ZhihuColors.primary)
      } else {
        Button('发送')
          .width(64)
          .height(38)
          .fontSize(16)
          .backgroundColor(this.input.trim().length > 0
            ? ZhihuColors.primary
            : ZhihuColors.backgroundTertiary)
          .fontColor(this.input.trim().length > 0
            ? ZhihuColors.textInverse
            : ZhihuColors.textTertiary)
          .onClick(() => {
            this.doSend();
          })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 10 })
    .backgroundColor(ZhihuColors.backgroundSecondary)
  }

  @Builder
  loginPrompt() {
    Column({ space: 16 }) {
      Blank()
      Text('发私信前请先登录知乎账号')
        .fontSize(16)
        .fontColor(ZhihuColors.textSecondary)
      Button('去登录')
        .width(200)
        .height(42)
        .fontSize(17)
        .backgroundColor(ZhihuColors.primary)
        .onClick(() => {
          router.pushUrl({ url: 'pages/LoginPage' });
        })
      Blank()
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      this.topBar()
      if (!authStore.isLoggedIn) {
        this.loginPrompt()
      } else if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
          Text('加载中…')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0 && this.messages.length === 0) {
        Column({ space: 16 }) {
          Text(this.error)
          Button('重试')
            .fontSize(16)
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.loadHistory();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        this.messageList()
        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(14)
            .fontColor(ZhihuColors.danger)
            .width('100%')
            .padding({ left: 16, bottom: 4 })
        }
        this.inputBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
