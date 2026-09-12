/**
 * components/profile/profileMappers —— 关系/活动条目 → FeedItem 纯函数映射。
 * 复用既有 components/FeedCard 渲染，避免重写卡片。
 * 富文本按 spec 降级为纯文本（去标签、解实体）。
 */

import {
  ZhihuMemberRelation,
  ZhihuAnswer,
  ZhihuArticle,
  ZhihuPin,
  ZhihuQuestion,
  ZhihuVideo,
} from '../../model/zhihu';
import { FeedItem, FeedAuthor } from '../../api/feed';
import { ZhihuMemberActivity, ZhihuMemberActivityTarget } from '../../api/member';

/** 剥掉 HTML 标签并解码常见实体（spec 允许的纯文本降级）。 */
export function stripHtml(html?: string): string {
  if (!html) {
    return '';
  }
  return html
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function emptyAuthor(name: string, avatar: string): FeedAuthor {
  const a: FeedAuthor = { id: '', name: name, avatar: avatar };
  return a;
}

function avatarOf(author: object | undefined): string {
  if (!author) {
    return '';
  }
  const v = (author as Record<string, object>)['avatar_url'];
  return v ? String(v) : '';
}

function nameOf(author: object | undefined): string {
  if (!author) {
    return '匿名用户';
  }
  const v = (author as Record<string, object>)['name'];
  return v ? String(v) : '匿名用户';
}

/** ZhihuMemberRelation（回答/文章/想法/问题/视频）→ FeedItem。 */
export function relationToFeedItem(rel: ZhihuMemberRelation): FeedItem {
  const type: string = rel.type;
  const base: FeedItem = {
    id: '',
    type: 'answers',
    title: '',
    excerpt: '',
    author: emptyAuthor('匿名用户', ''),
    image: null,
    voteCount: 0,
    commentCount: 0,
    voted: 0,
  };

  if (type === 'answer') {
    const a = rel as ZhihuAnswer;
    base.id = String(a.id);
    base.type = 'answers';
    base.title = a.question ? a.question.title : '';
    base.questionId = a.question ? String(a.question.id) : '';
    base.excerpt = stripHtml(a.excerpt);
    base.voteCount = a.voteup_count ?? 0;
    base.commentCount = a.comment_count ?? 0;
    base.voted = a.relationship && a.relationship.voting ? a.relationship.voting : 0;
    base.author = emptyAuthor(nameOf(a.author), avatarOf(a.author));
    return base;
  }

  if (type === 'article') {
    const a = rel as ZhihuArticle;
    base.id = String(a.id);
    base.type = 'articles';
    base.title = a.title;
    base.excerpt = stripHtml(a.excerpt || a.content);
    base.voteCount = a.voteup_count ?? 0;
    base.commentCount = a.comment_count ?? 0;
    base.voted = a.relationship && a.relationship.voting ? a.relationship.voting : 0;
    base.author = emptyAuthor(nameOf(a.author), avatarOf(a.author));
    return base;
  }

  if (type === 'pin' || type === 'pins' || type === 'moments_pin') {
    const p = rel as ZhihuPin;
    base.id = String(p.id);
    base.type = 'pins';
    base.title = '发布了想法';
    base.excerpt = stripHtml(p.excerpt || p.content);
    base.voteCount = p.reaction_count ?? 0;
    base.commentCount = p.comment_count ?? 0;
    base.voted = p.relationship && p.relationship.voting ? p.relationship.voting : 0;
    base.author = emptyAuthor(nameOf(p.author), avatarOf(p.author));
    return base;
  }

  if (type === 'question') {
    const q = rel as ZhihuQuestion;
    base.id = String(q.id);
    base.type = 'questions';
    base.title = q.title;
    base.questionId = String(q.id);
    base.excerpt = stripHtml(q.excerpt || q.detail || '');
    base.voteCount = q.follower_count ?? 0;
    base.commentCount = q.answer_count ?? 0;
    base.author = emptyAuthor(nameOf(q.author), avatarOf(q.author));
    return base;
  }

  // zvideo / video / 兜底
  const v = rel as ZhihuVideo;
  base.id = String(v.id);
  base.type = 'video';
  base.title = v.title || '发布了视频';
  base.excerpt = stripHtml(v.excerpt || '');
  base.voteCount = v.voteup_count ?? 0;
  base.commentCount = v.comment_count ?? 0;
  base.author = emptyAuthor(nameOf(v.author), avatarOf(v.author));
  return base;
}

/** 活动（动态流）target → FeedItem。 */
export function activityToFeedItem(
  activity: ZhihuMemberActivity,
  fallbackName: string,
  fallbackAvatar: string,
): FeedItem {
  const t: ZhihuMemberActivityTarget | undefined = activity.target;
  const base: FeedItem = {
    id: '',
    type: 'answers',
    title: '',
    excerpt: '',
    author: emptyAuthor(fallbackName, fallbackAvatar),
    image: null,
    voteCount: 0,
    commentCount: 0,
    voted: 0,
  };
  if (!t) {
    base.id = String(activity.id ?? '');
    return base;
  }

  const rawType: string = t.type ?? '';
  const actionText: string | undefined =
    activity.source && activity.source.action_text ? activity.source.action_text : undefined;

  if (rawType === 'pin' || rawType === 'moments_pin' || rawType === 'pins') {
    base.type = 'pins';
    base.title = actionText ?? '发布了想法';
    const contentText: string = typeof t.content === 'string' ? stripHtml(t.content as string) : '';
    base.excerpt = contentText.substring(0, 150);
    base.image = t.image_url ?? t.thumbnail ?? null;
    base.voteCount = t.reaction_count ?? 0;
  } else if (rawType === 'article') {
    base.type = 'articles';
    base.title = t.title ?? '';
    base.excerpt = stripHtml(t.excerpt ?? '');
    base.image = t.image_url ?? t.thumbnail ?? null;
    base.voteCount = t.voteup_count ?? 0;
  } else if (rawType === 'question') {
    base.type = 'questions';
    base.title = t.title ?? (t.question ? t.question.title ?? '' : '');
    base.questionId = t.question ? String(t.question.id ?? t.id ?? '') : String(t.id ?? '');
    base.voteCount = Number((t as Record<string, object>)['follower_count'] ?? 0);
  } else {
    // answer 或其它
    base.type = 'answers';
    base.title = t.question ? (t.question.title ?? '') : (t.title ?? '');
    base.questionId = t.question ? String(t.question.id ?? '') : '';
    base.excerpt = stripHtml(t.excerpt ?? (typeof t.content === 'string' ? (t.content as string) : ''));
    base.image = t.image_url ?? t.thumbnail ?? null;
    base.voteCount = t.voteup_count ?? 0;
  }

  base.id = String(t.id ?? activity.id ?? t.url ?? '');
  base.commentCount = t.comment_count ?? 0;
  base.favlistsCount = t.favlists_count ?? 0;
  base.voted = t.relationship && t.relationship.voting ? t.relationship.voting : 0;
  if (t.author) {
    base.author = emptyAuthor(nameOf(t.author), avatarOf(t.author));
  }
  return base;
}

/** 点击 FeedItem 跳对应详情页（仅用字符串 url，详情页由别组提供）。 */
export function feedDetailUrl(item: FeedItem): string {
  if (item.type === 'articles') {
    return 'pages/ArticleDetailPage';
  }
  if (item.type === 'pins') {
    return 'pages/PinDetailPage';
  }
  if (item.type === 'questions') {
    return 'pages/QuestionDetailPage';
  }
  if (item.type === 'video' || item.type === 'videos') {
    return 'pages/VideoPage';
  }
  return 'pages/AnswerDetailPage';
}
