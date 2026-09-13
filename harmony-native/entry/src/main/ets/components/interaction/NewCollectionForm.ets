/**
 * components/interaction/NewCollectionForm —— 新建收藏夹表单。
 * 标题 + 描述 + 是否公开开关；点击完成时通过 onSubmit 上抛。
 */

import { ZhihuColors } from '../../utils/theme';

interface CreateArgs {
  title: string;
  description: string;
  isPublic: boolean;
}

@Component
export struct NewCollectionForm {
  @State title: string = '';
  @State description: string = '';
  @State isPublic: boolean = true;
  @State pending: boolean = false;

  onSubmit: (args: CreateArgs) => void = (args: CreateArgs): void => {};

  build() {
    Column({ space: 12 }) {
      Text('标题')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
        .width('100%')
      TextInput({ placeholder: '输入标题', text: this.title })
        .width('100%')
        .height(48)
        .backgroundColor(ZhihuColors.backgroundTertiary)
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .fontSize(17)
        .onChange((v: string) => {
          this.title = v;
        })

      Text('描述（可选）')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(ZhihuColors.text)
        .width('100%')
        .margin({ top: 8 })
      TextArea({ placeholder: '输入描述', text: this.description })
        .width('100%')
        .height(96)
        .backgroundColor(ZhihuColors.backgroundTertiary)
        .borderRadius(12)
        .padding(12)
        .fontSize(17)
        .onChange((v: string) => {
          this.description = v;
        })

      Row() {
        Column({ space: 2 }) {
          Text('公开收藏夹')
          Text('公开后其他用户可见')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.isPublic })
          .selectedColor(ZhihuColors.primary)
          .onChange((isOn: boolean) => {
            this.isPublic = isOn;
          })
      }
      .width('100%')
      .margin({ top: 8 })

      Button(this.pending ? '创建中…' : '完成')
        .width('100%')
        .height(50)
        .backgroundColor(ZhihuColors.primary)
        .fontColor(ZhihuColors.textInverse)
        .fontSize(18)
        .margin({ top: 12 })
        .enabled(!this.pending)
        .onClick(() => {
          this.onSubmit({
            title: this.title,
            description: this.description,
            isPublic: this.isPublic,
          });
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
  }
}
