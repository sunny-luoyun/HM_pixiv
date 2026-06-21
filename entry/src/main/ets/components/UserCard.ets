import router from '@ohos.router';
import { curves } from '@kit.ArkUI';
import { PixivService } from '../services/PixivService';
import { UserSearchResult } from '../models/PixivModels';
import { ShimmerLoading } from './ShimmerLoading';

@Component
export struct UserCard {
  private item!: UserSearchResult;
  @Prop index: number = 0;
  @State cardOpacity: number = 0;
  @State cardTranslateY: number = 20;
  @State avatarOpacity: number = 0;
  @State localAvatar: string = '';
  @State isCaching: boolean = true;

  async aboutToAppear() {
    setTimeout(() => {
      animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
        this.cardOpacity = 1;
        this.cardTranslateY = 0;
      });
    }, this.index * 60);

    const avatarUrl = this.item.imageBig || this.item.image;
    if (!avatarUrl) {
      this.isCaching = false;
      return;
    }
    const path = await PixivService.cacheImage(avatarUrl, `user_${this.item.userId}.jpg`);
    if (path) {
      this.avatarOpacity = 0;
      this.localAvatar = path;
    }
    this.isCaching = false;
  }

  build() {
    Row() {
      if (this.localAvatar) {
        Image(this.localAvatar)
          .width(48)
          .height(48)
          .objectFit(ImageFit.Cover)
          .borderRadius(24)
          .opacity(this.avatarOpacity)
          .onComplete(() => {
            animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
              this.avatarOpacity = 1;
            });
          })
      } else {
        ShimmerLoading()
          .width(48)
          .height(48)
          .borderRadius(24)
      }

      Column() {
        Text(this.item.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.item.comment) {
          Text(this.item.comment)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 14 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
    .opacity(this.cardOpacity)
    .translate({ y: this.cardTranslateY })
    .onClick(() => {
      router.pushUrl({
        url: 'pages/user/UserProfilePage',
        params: {
          userId: this.item.userId,
          userName: this.item.name,
          userAvatar: this.item.imageBig || this.item.image
        }
      });
    })
  }
}
