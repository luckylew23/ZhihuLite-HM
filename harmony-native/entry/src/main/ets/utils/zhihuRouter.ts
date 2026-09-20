/**
 * zhihuRouter —— 把知乎 URL 解析后路由到 app 内原生详情页（不再跳浏览器）。
 * 移植自上游 zhihu-- 的 deep-link 路由表，映射到 HarmonyOS 原生页面。
 */
import { router } from '@kit.ArkUI';
import { parseZhihuUrl } from './url';

/** 尝试在 app 内打开知乎 URL；成功返回 true，无法识别返回 false。 */
export function openZhihuUrl(url: string): boolean {
  const inner: string | null = parseZhihuUrl(url);
  if (inner === null) {
    return false;
  }
  // inner 形如 /answer/123 /question/456 /article/789 /pin/... /user/...
  const parts: string[] = inner.split('/').filter((x: string) => x.length > 0);
  if (parts.length < 2) {
    return false;
  }
  const kind: string = parts[0];
  const id: string = parts[1];
  try {
    switch (kind) {
      case 'answer':
        router.pushUrl({ url: 'pages/AnswerDetailPage', params: { id: id } });
        return true;
      case 'question':
        router.pushUrl({ url: 'pages/QuestionDetailPage', params: { id: id } });
        return true;
      case 'article':
        router.pushUrl({ url: 'pages/ArticleDetailPage', params: { id: id } });
        return true;
      case 'pin':
        router.pushUrl({ url: 'pages/PinDetailPage', params: { id: id } });
        return true;
      case 'user':
        router.pushUrl({ url: 'pages/PeoplePage', params: { id: id } });
        return true;
      case 'topic':
        router.pushUrl({ url: 'pages/TopicPage', params: { topicId: id } });
        return true;
      case 'column':
        router.pushUrl({ url: 'pages/ColumnPage', params: { columnId: id } });
        return true;
      case 'collections':
        router.pushUrl({ url: 'pages/CollectionDetailPage', params: { collectionId: id } });
        return true;
      case 'video':
        router.pushUrl({ url: 'pages/VideoPage', params: { videoId: id } });
        return true;
      default:
        return false;
    }
  } catch (e) {
    return false;
  }
}
