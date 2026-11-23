/**
 * utils/contentOpener —— 内容打开的统一入口（宽屏/竖屏自适应）。
 *
 * 宽屏（平板 / PC 窗口 ≥ 840vp）：内容在首页右侧主栏打开（不路由），
 *   通过 AppStorage(splitType/splitId/splitQuestionId/splitVersion) 通知 SplitDetailView。
 *   右栏内维护导航栈（splitStack）：右栏里点"问题→回答"是入栈，
 *   返回（‹ / 右滑）逐层出栈，栈空才关闭整个右栏——"怎么去就怎么返回"。
 * 竖屏（手机，当前行为）：router.pushUrl 到对应详情页。
 *
 * Index 页根节点 onAreaChange 维护 isWideScreen（lg 断点 840vp）。
 */

import { router } from '@kit.ArkUI';
import { FeedItem } from '../api/feed';

export const WIDE_BREAKPOINT_VP: number = 840;

export function isWideScreen(): boolean {
  const v = AppStorage.get<boolean>('isWideScreen');
  return v === true;
}

/** 右栏支持的内容类型 */
function splitSupported(type: string): boolean {
  return type === 'answers' || type === 'articles' ||
    type === 'questions' || type === 'pins' || type === 'daily';
}

/** 右栏导航栈条目 */
interface SplitEntry {
  type: string;
  id: string;
  questionId: string;
}

/** 右栏导航栈（模块级；应用进程存活期间有效） */
let splitStack: SplitEntry[] = [];

/** 当前 Index 是否栈顶（右栏可见，没有全屏路由页盖住） */
function isSplitVisible(): boolean {
  return Number(router.getLength()) <= 1;
}

/** 把栈顶条目写进 AppStorage，驱动 SplitDetailView 切换 */
function applyTop(): void {
  const top: SplitEntry = splitStack[splitStack.length - 1];
  AppStorage.setOrCreate('splitType', top.type);
  AppStorage.setOrCreate('splitId', top.id);
  AppStorage.setOrCreate('splitQuestionId', top.questionId);
  const v: number = AppStorage.get<number>('splitVersion') ?? 0;
  AppStorage.setOrCreate('splitVersion', v + 1);
}

/**
 * 统一打开内容。
 * mode:
 *   - 'reset'（默认）左栏点新内容：清空栈，右栏直接换内容；
 *   - 'push' 右栏内链式跳转（问题页里点回答、回答页点问题）：入栈，可逐层返回。
 * 全屏路由页（个人主页/搜索/最近浏览等）盖在上面时，即使宽屏也走路由——
 * 右栏被盖住不可见，切了也看不见。
 */
export function openContentById(type: string, id: string, questionId: string = '',
  title: string = '', author: string = '', excerpt: string = '',
  mode: string = 'reset'): void {
  if (isWideScreen() && splitSupported(type) && id.length > 0 && isSplitVisible()) {
    const entry: SplitEntry = { type: type, id: id, questionId: questionId };
    if (mode === 'push') {
      splitStack.push(entry);
    } else {
      splitStack = [entry];
    }
    applyTop();
    return;
  }

  // 竖屏 / 全屏路由页：与原 openDetail 分发一致
  if (type === 'questions') {
    router.pushUrl({
      url: 'pages/QuestionDetailPage',
      params: { id: id.length > 0 ? id : questionId },
    });
  } else if (type === 'answers') {
    router.pushUrl({ url: 'pages/AnswerDetailPage', params: { id: id } });
  } else if (type === 'articles') {
    router.pushUrl({ url: 'pages/ArticleDetailPage', params: { id: id } });
  } else if (type === 'pins') {
    router.pushUrl({ url: 'pages/PinDetailPage', params: { id: id } });
  } else if (type === 'daily') {
    router.pushUrl({
      url: 'pages/DailyDetailPage',
      params: { id: id, title: title },
    });
  } else if (type === 'videos') {
    router.pushUrl({
      url: 'pages/VideoPage',
      params: { id: id, title: title, author: author, description: excerpt },
    });
  } else {
    router.pushUrl({
      url: 'pages/DetailPage',
      params: { id: id, type: type, questionId: questionId },
    });
  }
}

/** FeedItem → openContentById */
export function openFeedItem(item: FeedItem): void {
  const t: string = item.type;
  if (t === 'questions') {
    openContentById('questions', item.questionId ?? item.id, item.questionId ?? '');
    return;
  }
  openContentById(t, item.id, item.questionId ?? '');
}

/**
 * 右栏返回（‹ / 右滑）：逐层出栈。
 * 栈里还有上一层 → 右栏切回上一层；栈只剩当前层 → 关闭整个右栏。
 */
export function splitBack(): void {
  if (splitStack.length > 1) {
    splitStack.pop();
    applyTop();
  } else {
    closeSplitDetail();
  }
}

/** 关闭右栏内容（清空栈） */
export function closeSplitDetail(): void {
  splitStack = [];
  AppStorage.setOrCreate('splitType', '');
  AppStorage.setOrCreate('splitId', '');
  const v: number = AppStorage.get<number>('splitVersion') ?? 0;
  AppStorage.setOrCreate('splitVersion', v + 1);
}
