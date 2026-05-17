import { NovelBookmark, PixivService } from '../services/PixivService';

@Component
export struct NovelCard {
  private item!: NovelBookmark;
  @State localCoverPath: string = '';

  async aboutToAppear() {
    if (!this.item.url) return;
    const path = await PixivService.cacheImage(this.item.url, `novel_${this.item.id}.jpg`);
    if (path) {
      this.localCoverPath = path;
    }
  }

  build() {
    Column() {
      Row() {
        this.CoverImage()
        this.InfoSection()
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      this.CacheButton()
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
  }

  @Builder
  CoverImage() {
    if (this.localCoverPath || this.item.url) {
      Image(this.localCoverPath || this.item.url)
        .width(80)
        .height(110)
        .objectFit(ImageFit.Cover)
        .borderRadius(6)
        .margin({ right: 12 })
    } else {
      Column() {
        Text('📄')
          .fontSize(28)
      }
      .width(80)
      .height(110)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor('#FFE0E0E0')
      .borderRadius(6)
      .margin({ right: 12 })
    }
  }

  @Builder
  InfoSection() {
    Column() {
      Text(this.item.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      if (this.item.seriesTitle) {
        Text(this.item.seriesTitle)
          .fontSize(12)
          .fontColor('#FF8A8A8A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }

      Text(this.item.userName)
        .fontSize(12)
        .fontColor($r('app.color.tab_selected'))
        .maxLines(1)
        .margin({ top: 4 })
        .width('100%')

      if (this.item.tags && this.item.tags.length > 0) {
        Text(this.item.tags.slice(0, 3).join(' · '))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
          .width('100%')
      }

      Row() {
        Text(this.formatDate(this.item.createDate))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))

        Blank()

        Text(`${this.item.wordCount}字`)
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
      }
      .width('100%')
      .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  CacheButton() {
    Button('📥 缓存小说')
      .fontSize(13)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.tab_selected'))
      .borderRadius(18)
      .height(36)
      .width('100%')
      .margin({ top: 10 })
      .onClick(() => {
        console.info(`缓存小说: ${this.item.id} - ${this.item.title}`);
      })
  }

  formatDate(dateStr: string): string {
    if (!dateStr) return '';
    try {
      const d = new Date(dateStr);
      const y = d.getFullYear();
      const m = ('0' + (d.getMonth() + 1)).slice(-2);
      const day = ('0' + d.getDate()).slice(-2);
      return `${y}-${m}-${day}`;
    } catch {
      return dateStr;
    }
  }
}
