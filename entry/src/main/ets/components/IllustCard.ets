import router from '@ohos.router';
import { PixivService, IllustBookmark } from '../services/PixivService';

@Component
export struct IllustCard {
  private item!: IllustBookmark;
  @State localUrl: string = '';
  @State isCaching: boolean = true;

  async aboutToAppear() {
    if (!this.item.url) {
      this.isCaching = false;
      return;
    }
    const path = await PixivService.cacheImage(this.item.url, `illust_${this.item.id}.jpg`);
    if (path) {
      this.localUrl = path;
    }
    this.isCaching = false;
  }

  build() {
    Column() {
      if (this.localUrl) {
        Image(this.localUrl)
          .width('100%')
          .height(140)
          .objectFit(ImageFit.Cover)
          .borderRadius({ topLeft: 8, topRight: 8 })
      } else {
        Column()
          .width('100%')
          .height(140)
          .backgroundColor('#FFE8E8E8')
          .borderRadius({ topLeft: 8, topRight: 8 })
      }
      Column() {
        Text(this.item.title)
          .fontSize(12)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.userName)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 2 })
      }
      .width('100%')
      .padding({ left: 6, right: 6, top: 4, bottom: 6 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(8)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/illust/IllustDetailPage',
        params: { id: this.item.id }
      });
    })
  }
}
