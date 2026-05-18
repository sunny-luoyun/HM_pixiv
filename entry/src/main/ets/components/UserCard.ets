import { PixivService, UserSearchResult } from '../services/PixivService';

@Component
export struct UserCard {
  private item!: UserSearchResult;
  @State localAvatar: string = '';
  @State isCaching: boolean = true;

  async aboutToAppear() {
    const avatarUrl = this.item.imageBig || this.item.image;
    if (!avatarUrl) {
      this.isCaching = false;
      return;
    }
    const path = await PixivService.cacheImage(avatarUrl, `user_${this.item.userId}.jpg`);
    if (path) {
      this.localAvatar = path;
    }
    this.isCaching = false;
  }

  build() {
    Row() {
      if (this.localAvatar) {
        Image(this.localAvatar)
          .width(44)
          .height(44)
          .objectFit(ImageFit.Cover)
          .borderRadius(22)
      } else {
        Text('👤')
          .fontSize(24)
          .width(44)
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FFE8E8E8')
          .textAlign(TextAlign.Center)
      }

      Text(this.item.name)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 12 })
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }
}
