/**
 * 发布草稿本地自动保存/恢复（对齐上游 features/publishing/usePublishingDraft 的核心能力）
 * - 按 kind（answer/article/pin/question）分别存储标题与内容
 * - 输入变化即时保存；进入页面时恢复；发布成功后清除
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const PREF_NAME: string = 'zhihu_lite_publish';
const TAG: string = 'PublishDraft';

export interface PublishDraftValue {
  title: string;
  content: string;
}

export function savePublishDraft(ctx: common.Context, kind: string, title: string, content: string): void {
  try {
    const pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
    pref.putSync('draft_' + kind + '_title', title);
    pref.putSync('draft_' + kind + '_content', content);
    pref.flush();
  } catch (e) {
    hilog.info(0x3100, TAG, 'save fail %{public}s', String(e));
  }
}

export function loadPublishDraft(ctx: common.Context, kind: string): PublishDraftValue {
  const empty: PublishDraftValue = { title: '', content: '' };
  try {
    const pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
    const t: string = pref.getSync('draft_' + kind + '_title', '') as string;
    const c: string = pref.getSync('draft_' + kind + '_content', '') as string;
    if (t.length === 0 && c.length === 0) {
      return empty;
    }
    return { title: t, content: c };
  } catch (e) {
    return empty;
  }
}

export function clearPublishDraft(ctx: common.Context, kind: string): void {
  try {
    const pref = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
    pref.putSync('draft_' + kind + '_title', '');
    pref.putSync('draft_' + kind + '_content', '');
    pref.flush();
  } catch (e) {
  }
}
