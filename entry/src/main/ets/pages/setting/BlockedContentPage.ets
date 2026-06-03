import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { BlockedAuthor, BlockedSeries, BlockedSeriesTitle } from '../../models/PixivModels';

@Entry
@Component
struct BlockedContentPage {
  @State blockedAuthors: BlockedAuthor[] = [];
  @State blockedSeries: BlockedSeries[] = [];
  @State blockedSeriesTitles: BlockedSeriesTitle[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadBlockedContent();
  }

  async loadBlockedContent() {
    this.isLoading = true;
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const results = await Promise.all([
        pixivCacheDB.getAllBlockedAuthors(),
        pixivCacheDB.getAllBlockedSeries(),
        pixivCacheDB.getAllBlockedSeriesTitles()
      ]);
      const authors = results[0];
      const series = results[1];
      const titles = results[2];
      this.blockedAuthors = authors;
      this.blockedSeries = series;
      this.blockedSeriesTitles = titles;
    } catch (err) {
      console.error('加载屏蔽内容失败:', err);
    }
    this.isLoading = false;
  }

  async unblockAuthor(authorId: string) {
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedAuthor(authorId);
      this.blockedAuthors = this.blockedAuthors.filter(a => a.authorId !== authorId);
    } catch (err) {
      console.error('取消屏蔽作者失败:', err);
    }
  }

  async unblockSeries(seriesId: string) {
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedSeries(seriesId);
      this.blockedSeries = this.blockedSeries.filter(s => s.seriesId !== seriesId);
    } catch (err) {
      console.error('取消屏蔽系列失败:', err);
    }
  }

  confirmUnblockAuthor(author: BlockedAuthor) {
    promptAction.showDialog({
      title: '取消屏蔽',
      message: `确定要取消屏蔽作者「${author.authorName}」吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '确定', color: '#FF4D4F' }
      ]
    }).then((data) => {
      if (data.index === 1) {
        this.unblockAuthor(author.authorId);
      }
    });
  }

  confirmUnblockSeries(series: BlockedSeries) {
    promptAction.showDialog({
      title: '取消屏蔽',
      message: `确定要取消屏蔽系列「${series.seriesTitle}」吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '确定', color: '#FF4D4F' }
      ]
    }).then((data) => {
      if (data.index === 1) {
        this.unblockSeries(series.seriesId);
      }
    });
  }

  async unblockSeriesTitle(title: string) {
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.removeBlockedSeriesTitle(title);
      this.blockedSeriesTitles = this.blockedSeriesTitles.filter(t => t.title !== title);
    } catch (err) {
      console.error('取消屏蔽系列名称失败:', err);
    }
  }

  confirmUnblockSeriesTitle(item: BlockedSeriesTitle) {
    promptAction.showDialog({
      title: '取消屏蔽',
      message: `确定要取消屏蔽系列名称「${item.title}」吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '确定', color: '#FF4D4F' }
      ]
    }).then((data) => {
      if (data.index === 1) {
        this.unblockSeriesTitle(item.title);
      }
    });
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
  }

  build() {
    Column() {
      // Top bar
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor($r('app.color.tab_selected'))
          .onClick(() => { router.back(); })
        Text('屏蔽内容')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .height(52)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('app.color.glass_bg'))

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color($r('app.color.tab_selected'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.blockedAuthors.length === 0 && this.blockedSeries.length === 0 && this.blockedSeriesTitles.length === 0) {
        Column() {
          Text('暂无屏蔽内容')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 60 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      } else {
        Scroll() {
          Column() {
            // Blocked authors section
            if (this.blockedAuthors.length > 0) {
              Text(`🚫 已屏蔽的作者（${this.blockedAuthors.length}）`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 4, bottom: 8 })
                .margin({ top: 12 })

              Column({ space: 8 }) {
                ForEach(this.blockedAuthors, (author: BlockedAuthor) => {
                  this.AuthorItem(author)
                }, (author: BlockedAuthor) => author.authorId)
              }
              .width('100%')
            }

            // Blocked series section
            if (this.blockedSeries.length > 0) {
              Text(`🚫 已屏蔽的系列（${this.blockedSeries.length}）`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 4, bottom: 8 })
                .margin({ top: 20 })

              Column({ space: 8 }) {
                ForEach(this.blockedSeries, (series: BlockedSeries) => {
                  this.SeriesItem(series)
                }, (series: BlockedSeries) => series.seriesId)
              }
              .width('100%')
            }

            // Blocked series titles section
            if (this.blockedSeriesTitles.length > 0) {
              Text(`🚫 已屏蔽的系列名称（${this.blockedSeriesTitles.length}）`)
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.user_name'))
                .width('100%')
                .padding({ left: 4, bottom: 8 })
                .margin({ top: 20 })

              Column({ space: 8 }) {
                ForEach(this.blockedSeriesTitles, (item: BlockedSeriesTitle) => {
                  this.SeriesTitleItem(item)
                }, (item: BlockedSeriesTitle) => item.title)
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  AuthorItem(author: BlockedAuthor) {
    Row() {
      Column() {
        Text(author.authorName.charAt(0).toUpperCase())
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(44).height(44)
      .borderRadius(22)
      .backgroundColor($r('app.color.tab_selected'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(author.authorName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('取消屏蔽')
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.danger'))
        .borderRadius(16)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick(() => { this.confirmUnblockAuthor(author); })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/user/UserProfilePage',
        params: {
          userId: author.authorId,
          userName: author.authorName
        }
      });
    })
  }

  @Builder
  SeriesItem(series: BlockedSeries) {
    Row() {
      Column() {
        Text('S')
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(44).height(44)
      .borderRadius(22)
      .backgroundColor($r('app.color.success'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(series.seriesTitle)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(series.authorName)
          .fontSize(12)
          .fontColor($r('app.color.tab_selected'))
          .margin({ top: 2 })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('取消屏蔽')
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.danger'))
        .borderRadius(16)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick(() => { this.confirmUnblockSeries(series); })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
    .onClick(() => {
      router.pushUrl({
        url: 'pages/user/UserProfilePage',
        params: {
          userId: series.authorId,
          userName: series.authorName
        }
      });
    })
  }

  @Builder
  SeriesTitleItem(item: BlockedSeriesTitle) {
    Row() {
      Column() {
        Text('T')
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(44).height(44)
      .borderRadius(22)
      .backgroundColor($r('app.color.orange'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Button('取消屏蔽')
        .fontSize(12)
        .fontColor(Color.White)
        .backgroundColor($r('app.color.danger'))
        .borderRadius(16)
        .height(32)
        .padding({ left: 14, right: 14 })
        .onClick(() => { this.confirmUnblockSeriesTitle(item); })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(12)
  }
}
