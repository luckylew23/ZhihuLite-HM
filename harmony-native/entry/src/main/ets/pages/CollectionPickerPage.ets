/**
 * pages/CollectionPickerPage —— 收藏夹选择页（独立页面，移植自
 * 上游 components/CollectionSelectorModal.tsx + CollectionEditorForm.tsx）。
 * 入参（router params）：
 *   resourceType: 'answer' | 'article'
 *   resourceId:    string
 * 列出我的收藏夹、勾选/取消勾选、可新建收藏夹；操作成功后 router.back()。
 * 未登录引导跳 LoginPage。
 */

import { router } from '@kit.ArkUI';
import {
  getAnswerCollectionStatus,
  getArticleCollectionStatus,
  addToCollection,
  removeFromCollection,
  addArticleToCollection,
  removeArticleFromCollection,
  createCollection,
  CreateCollectionInput,
} from '../api/collection';
import { authStore } from '../store/authStore';
import { ZhihuColors } from '../utils/theme';
import { CollectionRow } from '../components/interaction/CollectionRow';
import { NewCollectionForm } from '../components/interaction/NewCollectionForm';

interface CollectionSel {
  id: string;
  title: string;
  description: string;
  isPublic: boolean;
  isFavorited: boolean;
}

interface NewCollectionFormArgs {
  title: string;
  description: string;
  isPublic: boolean;
}

@Entry
@Component
struct CollectionPickerPage {
  @State resourceType: string = 'answer';
  @State resourceId: string = '';
  @State collections: CollectionSel[] = [];
  @State loading: boolean = true;
  @State error: string = '';
  @State creating: boolean = false;
  @State pendingId: string = '';
  @State toast: string = '';

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, object>;
    if (p) {
      this.resourceType = String(p['resourceType'] ?? 'answer');
      this.resourceId = String(p['resourceId'] ?? '');
    }
    this.load();
  }

  private isArticle(): boolean {
    return this.resourceType === 'article';
  }

  async load(): Promise<void> {
    this.loading = true;
    this.error = '';
    try {
      const resp = this.isArticle()
        ? await getArticleCollectionStatus(this.resourceId)
        : await getAnswerCollectionStatus(this.resourceId);
      const raw: object[] = resp.data === undefined ? [] : resp.data;
      const list: CollectionSel[] = [];
      for (const r of raw) {
        const rec = r as Record<string, object>;
        list.push({
          id: String(rec['id'] ?? ''),
          title: String(rec['title'] ?? ''),
          description: String(rec['description'] ?? ''),
          isPublic: Boolean(rec['is_public']),
          isFavorited: Boolean(rec['is_favorited']),
        });
      }
      this.collections = list;
    } catch (e) {
      this.error = '收藏夹加载失败';
    } finally {
      this.loading = false;
    }
  }

  async toggle(row: CollectionSel): Promise<void> {
    if (!authStore.isLoggedIn) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (this.pendingId.length > 0) {
      return;
    }
    this.pendingId = row.id;
    try {
      if (this.isArticle()) {
        if (row.isFavorited) {
          await removeArticleFromCollection(row.id, this.resourceId);
        } else {
          await addArticleToCollection(row.id, this.resourceId);
        }
      } else {
        if (row.isFavorited) {
          await removeFromCollection(row.id, this.resourceId);
        } else {
          await addToCollection(row.id, this.resourceId);
        }
      }
      // 本地翻转
      const next: CollectionSel[] = [];
      for (const c of this.collections) {
        if (c.id === row.id) {
          const cloned: CollectionSel = {
            id: c.id,
            title: c.title,
            description: c.description,
            isPublic: c.isPublic,
            isFavorited: !c.isFavorited,
          };
          next.push(cloned);
        } else {
          next.push(c);
        }
      }
      this.collections = next;
    } catch (e) {
      this.showToast('操作失败');
    } finally {
      this.pendingId = '';
    }
  }

  async handleCreate(title: string, description: string, isPublic: boolean): Promise<void> {
    if (!authStore.isLoggedIn) {
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    if (title.trim().length === 0) {
      this.showToast('请输入标题');
      return;
    }
    try {
      const input: CreateCollectionInput = {
        title: title.trim(),
        description: description.trim(),
        is_public: isPublic,
      };
      await createCollection(input);
      this.showToast('新建成功');
      this.creating = false;
      await this.load();
    } catch (e) {
      this.showToast('创建失败');
    }
  }

  private showToast(msg: string): void {
    this.toast = msg;
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        if (this.creating) {
          Text('‹')
            .fontSize(24)
            .fontColor(ZhihuColors.text)
            .padding({ left: 4, right: 8 })
            .onClick(() => {
              this.creating = false;
            })
        } else {
          Text('‹')
            .fontSize(24)
            .fontColor(ZhihuColors.text)
            .padding({ left: 4, right: 8 })
            .onClick(() => {
              router.back();
            })
        }
        Text(this.creating ? '新建收藏夹' : '收藏至收藏夹')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
        Blank()
        if (!this.creating) {
          Row({ space: 3 }) {
            Text('+')
            Text('新建')
          }
          .padding(8)
          .onClick(() => {
            this.creating = true;
          })
        }
      }
      .width('100%')
      .height(52)
      .padding({ left: 12, right: 12 })
      .backgroundColor(ZhihuColors.backgroundSecondary)

      if (this.creating) {
        Scroll() {
          NewCollectionForm({
            onSubmit: (args: NewCollectionFormArgs): void => {
              this.handleCreate(args.title, args.description, args.isPublic);
            },
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      } else if (!authStore.isLoggedIn) {
        Column({ space: 16 }) {
          Text('登录后可查看并管理收藏夹')
          Button('去登录')
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              router.pushUrl({ url: 'pages/LoginPage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loading) {
        Column({ space: 8 }) {
          LoadingProgress().width(40).height(40).color(ZhihuColors.primary)
          Text('加载中…')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.error.length > 0) {
        Column({ space: 16 }) {
          Text(this.error)
          Button('重试')
            .backgroundColor(ZhihuColors.primary)
            .onClick(() => {
              this.load();
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.collections, (c: CollectionSel) => {
            ListItem() {
              Column() {
                CollectionRow({
                  title: c.title,
                  description: c.description,
                  isPublic: c.isPublic,
                  isFavorited: c.isFavorited,
                  pending: this.pendingId === c.id,
                  onToggle: (t: string): void => {
                    this.toggle(c);
                  },
                })
                Divider().strokeWidth(0.5).color(ZhihuColors.border)
              }
              .width('100%')
            }
          }, (c: CollectionSel) => c.id)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .padding({ left: 16, right: 16 })

        Button('完成')
          .width('92%')
          .height(50)
          .backgroundColor(ZhihuColors.primary)
          .fontColor(ZhihuColors.textInverse)
          .fontSize(18)
          .margin({ bottom: 16, top: 8 })
          .onClick(() => {
            router.back();
          })
      }

      if (this.toast.length > 0) {
        Text(this.toast)
          .fontSize(14)
          .fontColor(ZhihuColors.textInverse)
          .backgroundColor('#b3000000')
          .borderRadius(6)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ZhihuColors.background)
  }
}
