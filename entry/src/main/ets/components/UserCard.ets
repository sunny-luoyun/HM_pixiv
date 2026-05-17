import { PixivService, UserSearchResult } from '../services/PixivService';

@Component
export struct UserCard {
  private item!: UserSearchResult;
  @State localAvatar: string = '';

  async aboutToAppear() {
    if (!this.item.profileImageUrl) return;
    const path = await PixivService.cacheImage(this.item.profileImageUrl, `user_${this.item.userId}.jpg`);
    if (path) {
      this.localAvatar = path;
    }
  }

  build() {
    Row() {
      this.AvatarSection()
      this.InfoSection()
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  AvatarSection() {
    if (this.localAvatar) {
      Image(this.localAvatar)
        .width(56)
        .height(56)
        .objectFit(ImageFit.Cover)
        .borderRadius(28)
        .margin({ right: 12 })
    } else {
      Column() {
        Text('👤')
          .fontSize(28)
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFE0E0E0')
      .borderRadius(28)
      .margin({ right: 12 })
    }
  }

  @Builder
  InfoSection() {
    Column() {
      Text(this.item.userName)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.item.comment) {
        Text(this.item.comment)
          .fontSize(11)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }

      Row() {
        Text(`插画 ${this.item.illustCount}`)
          .fontSize(11)
          .fontColor('#999')
        Text(`  ·  `)
          .fontSize(11)
          .fontColor('#999')
        Text(`粉丝 ${this.item.followerCount}`)
          .fontSize(11)
          .fontColor('#999')
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }
}
