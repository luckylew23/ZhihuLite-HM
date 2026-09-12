/**
 * components/profile/MemberRow —— 用户行（赞同者/关注者/关注列表通用）。
 * 点击跳转 PeoplePage，入参 { urlToken }。
 */

import { router } from '@kit.ArkUI';
import { ZhihuColors } from '../../utils/theme';

@Component
export struct MemberRow {
  name: string = '';
  avatar: string = '';
  headline: string = '';
  urlToken: string = '';

  build() {
    Row({ space: 12 }) {
      if (this.avatar.length > 0) {
        Image(this.avatar)
          .width(44)
          .height(44)
          .borderRadius(22)
          .objectFit(ImageFit.Cover)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      } else {
        Row()
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor(ZhihuColors.backgroundTertiary)
      }
      Column({ space: 2 }) {
        Text(this.name)
          .copyOption(CopyOptions.LocalDevice)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(ZhihuColors.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.headline.length > 0) {
          Text(this.headline)
            .copyOption(CopyOptions.LocalDevice)
            .fontSize(13)
            .fontColor(ZhihuColors.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick(() => {
      if (this.urlToken.length > 0) {
        router.pushUrl({
          url: 'pages/PeoplePage',
          params: { urlToken: this.urlToken },
        });
      }
    })
  }
}
