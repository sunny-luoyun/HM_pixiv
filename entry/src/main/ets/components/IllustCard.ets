import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { PixivService, IllustBookmark } from '../services/PixivService';

@Component
export struct IllustCard {
  private item!: IllustBookmark;
  @Prop index: number = 0;
  @State localUrl: string = '';
  @State isCaching: boolean = true;
  @State isBookmarked: boolean = false;
  @State isBookmarkLoading: boolean = false;
  @State cardOpacity: number = 0;
  @State cardTranslateY: number = 20;
  @State bookmarkScale: number = 1;
  @State imageOpacity: number = 0;

  async aboutToAppear() {
    setTimeout(() => {
      animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
        this.cardOpacity = 1;
        this.cardTranslateY = 0;
      });
    }, this.index * 60);

    if (!this.item.url) {
      this.isCaching = false;
      return;
    }
    const path = await PixivService.cacheImage(this.item.url, `illust_${this.item.id}.jpg`);
    if (path) {
      this.imageOpacity = 0;
      this.localUrl = path;
    }
    this.isCaching = false;
    this.isBookmarked = !!this.item.bookmarkData;
  }

  async toggleBookmark() {
    if (this.isBookmarkLoading) return;
    this.isBookmarkLoading = true;
    try {
      if (this.isBookmarked) {
        await PixivService.deleteIllustBookmark(this.item.id);
        this.isBookmarked = false;
      } else {
        await PixivService.addIllustBookmark(this.item.id, 'public', []);
        this.isBookmarked = true;
      }
    } catch (err) {
      promptAction.showToast({ message: '操作失败: ' + String(err) });
    }
    this.isBookmarkLoading = false;
    animateTo({ curve: Curve.FastOutSlowIn, duration: 250 }, () => {
      this.bookmarkScale = 1.35;
    });
    setTimeout(() => {
      animateTo({ curve: Curve.Friction, duration: 250 }, () => {
        this.bookmarkScale = 0.9;
      });
      setTimeout(() => {
        animateTo({ curve: Curve.Friction, duration: 200 }, () => {
          this.bookmarkScale = 1;
        });
      }, 250);
    }, 250);
  }

  build() {
    Column() {
      Column() {
        Stack() {
          if (this.localUrl) {
            Image(this.localUrl)
              .width('100%')
              .height(150)
              .objectFit(ImageFit.Cover)
              .borderRadius({ topLeft: 12, topRight: 12 })
              .sharedTransition('illust_' + this.item.id, { duration: 350, curve: Curve.Friction })
              .opacity(this.imageOpacity)
              .onComplete(() => {
                animateTo({ duration: 250, curve: Curve.EaseOut }, () => {
                  this.imageOpacity = 1;
                });
              })
          } else {
            Column()
              .width('100%')
              .height(150)
              .backgroundColor($r('app.color.loading_card'))
              .borderRadius({ topLeft: 12, topRight: 12 })
          }
          if (this.item.pageCount > 1) {
            Text(`${this.item.pageCount}页`)
              .fontSize(11)
              .fontColor(Color.White)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.overlay_dark'))
              .borderRadius(8)
              .position({ top: 6, right: 6 })
          }
        }
        .width('100%')
        .height(150)
        Text(this.item.title)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding({ left: 10, right: 10, top: 8 })
      }
      .width('100%')
      .onClick(() => {
        router.pushUrl({
          url: 'pages/illust/IllustDetailPage',
          params: {
            id: this.item.id,
            thumbnailLocalUrl: this.localUrl
          }
        });
      })

      Row() {
        Text(this.item.userName)
          .fontSize(11)
          .fontColor($r('app.color.tab_selected'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .onClick(() => {
            router.pushUrl({
              url: 'pages/user/UserProfilePage',
              params: {
                userId: this.item.userId,
                userName: this.item.userName
              }
            });
          })

        if (this.isBookmarkLoading) {
          LoadingProgress()
            .width(16).height(16)
            .color($r('app.color.danger'))
            .margin({ right: 10 })
        } else {
          Text(this.isBookmarked ? '❤' : '♡')
            .fontSize(16)
            .fontColor(this.isBookmarked ? $r('app.color.danger') : $r('app.color.text_secondary'))
            .padding({ right: 10 })
            .scale({ x: this.bookmarkScale, y: this.bookmarkScale })
            .onClick(() => this.toggleBookmark())
        }
      }
      .padding({ left: 10, right: 0, top: 2, bottom: 10 })
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
    .opacity(this.cardOpacity)
    .translate({ y: this.cardTranslateY })
  }
}
