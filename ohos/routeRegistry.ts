// ohos/routeRegistry.ts
// ----------------------------------------------------------------------------
// 把 expo-router 的「文件路径路由」映射到 React Navigation 的 (screenName, component)。
// name 使用 URL 路径形态（去掉 /index），例如 app/question/[id]/index.tsx -> 'question/[id]'。
// 新增页面时，仿照下面追加一行即可；ROUTE_TABLE 用于 useRouter().push('/question/123') 解析。
//
// 注意：'(tabs)' 直接映射到 HomeScreen（app/(tabs)/index）。原项目的底部 Tab 与关注/推荐/
// 发布/我的横向切换都由 HomeScreen 内部的 PagerView + 自定义底部栏实现，因此这里
// 不要再拆成独立导航路由，否则会与原生 Tab 栏重复。
// ----------------------------------------------------------------------------
import * as React from 'react';

import HomeTab from '../app/(tabs)/index';
import IndexRedirect from '../app/index';
import NotFound from '../app/+not-found';

import Login from '../app/login/index';
import Article from '../app/article/[id]';
import Question from '../app/question/[id]/index';
import Answer from '../app/answer/[id]';
import GuestDetail from '../app/guest/detail';
import Feedback from '../app/feedback/index';
import Search from '../app/search';
import Notifications from '../app/notifications/index';
import Inbox from '../app/inbox';
import History from '../app/history';
import Collections from '../app/collections/index';
import CollectionDetail from '../app/collections/[id]';
import Comments from '../app/comments/[id]';
import Topic from '../app/topic/[id]';
import People from '../app/people/[id]';
import ShortPost from '../app/p/[id]';
import Column from '../app/column/[id]';
import Pin from '../app/pin/[id]';
import Questions from '../app/questions/[id]';
import UserIndex from '../app/user/[id]/index';
import UserFollowing from '../app/user/[id]/following';
import UserFollowers from '../app/user/[id]/followers';
import UserMutual from '../app/user/[id]/mutual';
import UserStream from '../app/user/[id]/stream';
import UserLikes from '../app/user/likes';
import Chat from '../app/chat/[id]';
import PublishAnswer from '../app/publish/answer';
import PublishArticle from '../app/publish/article';
import PublishPin from '../app/publish/pin';
import PublishQuestion from '../app/publish/question';
import SettingsAppearance from '../app/settings/appearance';
import SettingsFilter from '../app/settings/filter';
import AnswerDetail from '../app/question/[id]/answer/[answerId]';
import QuestionWrite from '../app/question/write/[id]';
import Reply from '../app/comments/replies/[id]';
import Modal from '../app/modal';

export type RouteComponent = React.ComponentType<any>;

interface RouteDef {
  name: string;
  component: RouteComponent;
}

// 主路由（不含底部 Tab 容器，Tab 在 App.tsx 中直接以 '(tabs)' -> HomeTab 承载）。
export const ROUTES: [string, RouteComponent][] = [
  ['index', IndexRedirect],
  ['not-found', NotFound],
  ['login', Login],
  ['article/[id]', Article],
  ['question/[id]', Question],
  ['answer/[id]', Answer],
  ['guest/detail', GuestDetail],
  ['feedback', Feedback],
  ['search', Search],
  ['notifications', Notifications],
  ['inbox', Inbox],
  ['history', History],
  ['collections', Collections],
  ['collections/[id]', CollectionDetail],
  ['comments/[id]', Comments],
  ['topic/[id]', Topic],
  ['people/[id]', People],
  ['p/[id]', ShortPost],
  ['column/[id]', Column],
  ['pin/[id]', Pin],
  ['questions/[id]', Questions],
  ['user/[id]', UserIndex],
  ['user/[id]/following', UserFollowing],
  ['user/[id]/followers', UserFollowers],
  ['user/[id]/mutual', UserMutual],
  ['user/[id]/stream', UserStream],
  ['user/likes', UserLikes],
  ['chat/[id]', Chat],
  ['publish/answer', PublishAnswer],
  ['publish/article', PublishArticle],
  ['publish/pin', PublishPin],
  ['publish/question', PublishQuestion],
  ['settings/appearance', SettingsAppearance],
  ['settings/filter', SettingsFilter],
  ['question/[id]/answer/[answerId]', AnswerDetail],
  ['question/write/[id]', QuestionWrite],
  ['comments/replies/[id]', Reply],
  ['modal', Modal],
];

// 底部 Tab 容器：路由名 '(tabs)' 与 '(tabs)/index' 都指向 HomeScreen（内部自管横向 Tab）。
export const TAB_ROUTES: [string, RouteComponent][] = [
  ['(tabs)', HomeTab],
  ['(tabs)/index', HomeTab],
];

function toPattern(name: string): { pattern: RegExp; name: string; keys: string[] } {
  const keys: string[] = [];
  const segs = name.split('/').map((seg) => {
    const m = seg.match(/^\[(.+)\]$/);
    if (m) {
      keys.push(m[1]);
      return '([^/]+)';
    }
    return seg.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  });
  return { pattern: new RegExp('^' + segs.join('/') + '$'), name, keys };
}

const ALL: RouteDef[] = [
  ...ROUTES.map(([name, component]) => ({ name, component })),
  ...TAB_ROUTES.map(([name, component]) => ({ name, component })),
];

export const ROUTE_TABLE = ALL.map((r) => toPattern(r.name));

// 供 App.tsx 渲染 Tab 导航器使用
export { HomeTab };
