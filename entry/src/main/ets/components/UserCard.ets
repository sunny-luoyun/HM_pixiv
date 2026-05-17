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
    Column() {
      this.CoverSection()
      this.InfoSection()
    }
    .width('100%')
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  CoverSection() {
    if (this.localAvatar) {
      Image(this.localAvatar)
        .width('100%')
        .height(120)
        .objectFit(ImageFit.Cover)
        .borderRadius({ topLeft: 12, topRight: 12 })
    } else {
      Column() {
        Text('👤')
          .fontSize(48)
      }
      .width('100%')
      .height(120)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFE8E8E8')
      .borderRadius({ topLeft: 12, topRight: 12 })
    }
  }

  @Builder
  InfoSection() {
    Column() {
      Text(this.item.name)
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
        this.StatItem('👥', this.item.following)
      }
      .width('100%')
      .margin({ top: 8 })
      .justifyContent(FlexAlign.SpaceAround)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 10, right: 10, top: 8, bottom: 10 })
  }

  @Builder
  StatItem(icon: string, count: number) {
    Row() {
      Text(icon)
        .fontSize(12)
      Text(` ${count}`)
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
    }
  }
}
