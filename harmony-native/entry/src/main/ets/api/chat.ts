/**
 * 私信 API —— 移植自上游 zhihu--/api/zhihu/chat.ts。
 * ----------------------------------------------------------------------------
 * 说明：上游 chat.ts 本身就是纯 HTTP（getInbox / getMessages / sendMessage），
 * 不依赖 WebSocket，因此无需降级，三个函数照原样移植。
 * 改动：
 *   · axios → zhihuClient；POST body 为 JSON raw string。
 *   · 去掉 ApiRequestOptions.signal（v1.0 无 AbortSignal）。
 *   · 上游 any → 显式类型（RawChatEnvelope）。
 */

import { zhihuClient } from './httpClient';

const INBOX_URL: string = 'https://www.zhihu.com/api/v4/inbox';
const CHAT_URL: string = 'https://www.zhihu.com/api/v4/chat';

export interface ChatParticipant {
  type: string;
  message_user_type: string;
  id: string;
  url: string;
  name: string;
  url_token: string;
  user_type: string;
  headline: string;
  avatar_url: string;
}

export interface InboxThread {
  id: string;
  type: string;
  snippet: string;
  url: string;
  participant: ChatParticipant;
  updated_time: number;
  unread_count: number;
}

export interface InboxPaging {
  is_end: boolean;
  next: string;
  previous: string;
}

export interface InboxResponse {
  data: InboxThread[];
  paging: InboxPaging;
  new_count: number;
}

export interface ChatMessageInfo {
  id: string;
  type: string;
  url: string;
  text: string;
  created_time: number;
  content_type: number;
  user_type: string;
}

export interface ChatMessage {
  info: ChatMessageInfo;
  receiver: ChatParticipant;
  sender: ChatParticipant;
}

export interface ChatMessagesResult {
  data: ChatMessage[];
  paging: InboxPaging;
}

/** GET /chat 原始信封：data.messages / data.sender / data.receiver */
interface RawChatEnvelope {
  data?: {
    messages?: object[];
    sender?: object;
    receiver?: object;
  };
  paging?: InboxPaging;
}

export const getInbox = async (nextUrl?: string): Promise<InboxResponse> => {
  const url = nextUrl !== undefined && nextUrl.length > 0 ? nextUrl : INBOX_URL;
  const res = await zhihuClient.get<InboxResponse>(url);
  return res.data;
};

/**
 * 拉取某会话消息列表；把 GET 返回的 data.messages + data.sender/receiver
 * 归一为与 POST 单条消息一致的 { info, sender, receiver } 结构。
 */
export const getMessages = async (
  senderId: string,
  nextUrl?: string,
): Promise<ChatMessagesResult> => {
  const url =
    nextUrl !== undefined && nextUrl.length > 0
      ? nextUrl
      : CHAT_URL + '?sender_id=' + encodeURIComponent(senderId) + '&limit=20';
  const res = await zhihuClient.get<RawChatEnvelope>(url);

  const env = res.data;
  const rawMessages =
    env.data === undefined || env.data.messages === undefined ? [] : env.data.messages;
  const sender =
    env.data === undefined || env.data.sender === undefined
      ? ({} as ChatParticipant)
      : (env.data.sender as ChatParticipant);
  const receiver =
    env.data === undefined || env.data.receiver === undefined
      ? ({} as ChatParticipant)
      : (env.data.receiver as ChatParticipant);

  const data: ChatMessage[] = [];
  for (const msg of rawMessages) {
    data.push({ info: msg as ChatMessageInfo, sender: sender, receiver: receiver });
  }
  const paging: InboxPaging =
    env.paging === undefined
      ? { is_end: true, next: '', previous: '' }
      : env.paging;
  return { data: data, paging: paging };
};

export const sendMessage = async (
  receiverId: string,
  text: string,
): Promise<ChatMessage> => {
  const body = JSON.stringify({
    content_type: 0,
    receiver_id: receiverId,
    text: text,
  });
  const res = await zhihuClient.post<ChatMessage>(CHAT_URL, {
    data: body,
    headers: { 'Content-Type': 'application/json' },
  });
  return res.data;
};
