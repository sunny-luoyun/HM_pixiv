import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel, formatTextLength, formatPixivDate } from '../../models/PixivModels';
import { PageContext } from '../../common/utils/PageContext';
import { PageEnum } from '../../common/constants/PageEnum';
import { NovReaderParam, NovSeriesParam } from '../../common/constants/PageParamTypes';

@Component
export struct SeriesDetailPage {
  @State navParams: Record<string, Object> = {};
  private seriesId: string = '';
  private seriesTitle: string = '';
  private authorName: string = '';
  @State novels: PixivNovel[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    // 参数由 onReady 获取
  }

  async loadSeriesNovels() {
    this.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (ctx) {
        await pixivCacheDB.init(ctx);
      }
      this.novels = await pixivCacheDB.getNovelsBySeriesId(this.seriesId);
    } catch (err) {
      console.error('获取系列小说失败:', err);
    }
    this.isLoading = false;
  }

  openReader(novel: PixivNovel) {
    const pageCtx = AppStorage.get<PageContext>('rootPageContext');
    if (pageCtx) {
      const params: NovReaderParam = {
        novelId: novel.id,
        title: novel.title,
        author: novel.author,
        cached: true,
        translatedTitle: novel.titleTranslated || '',
        hasTitleTranslation: !!novel.hasTitleTranslation
      };
      pageCtx.openPage(PageEnum.NOVEL_READER, params as Object);
    }
  }

  build() {
    NavDestination() {
    Column() {
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color($r('app.color.tab_selected'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.novels.length === 0) {
        Column() {
          Text('暂无该系列的缓存小说')
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
            Row() {
              Text('‹')
                .fontSize(28)
                .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
              Text(this.seriesTitle)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.user_name'))
                .margin({ left: 12 })
              Blank()
            }
            .width('100%')
            .padding({ left: 16, right: 24, top: 16 })

            Row() {
              Text('📚')
                .fontSize(28)
                .margin({ right: 12 })
              Column() {
                Text(this.seriesTitle)
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.user_name'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${this.authorName}  ·  共 ${this.novels.length} 话已缓存`)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .margin({ top: 5 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('›')
                .fontSize(22)
                .fontColor($r('app.color.text_secondary'))
                .margin({ left: 8 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('app.color.loading_card'))
            .borderRadius(12)
            .margin({ left: 16, right: 16, top: 8 })
            .onClick(() => {
              const pageCtx = AppStorage.get<PageContext>('rootPageContext');
              if (pageCtx) {
                const params: NovSeriesParam = {
                  seriesId: this.seriesId,
                  seriesTitle: this.seriesTitle
                };
                pageCtx.openPage(PageEnum.NOVEL_SERIES, params as Object);
              }
            })

            Column({ space: 8 }) {
              ForEach(this.novels, (novel: PixivNovel) => {
                this.SeriesNovelCard(novel)
              }, (novel: PixivNovel): string => novel.id)
            }
            .width('100%')
          }
          .width('100%')
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        }
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
    }
    .onReady((ctx: NavDestinationContext) => {
      this.navParams = ctx.pathInfo.param as Record<string, Object> ?? {};
      this.seriesId = (this.navParams['seriesId'] as string) || '';
      this.seriesTitle = (this.navParams['seriesTitle'] as string) || '';
      this.authorName = (this.navParams['authorName'] as string) || '';
      this.loadSeriesNovels();
    })
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  SeriesNovelCard(novel: PixivNovel) {
    Row() {
      Column() {
        Text(`${novel.series?.order ?? '?'}`)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.tab_selected'))
      }
      .width(40).height(40)
      .borderRadius(8)
      .backgroundColor($r('app.color.info_bg'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(
          (novel.hasTitleTranslation && novel.titleTranslated)
            ? novel.titleTranslated : novel.title
        )
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(
            (novel.hasTitleTranslation && novel.titleTranslated)
              ? $r('app.color.tab_selected') : $r('app.color.user_name')
          )
          .width('100%')

        Row() {
          Text(formatTextLength(novel.textLength))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          if (novel.cachedAt) {
            Text(' · 缓存于 ' + formatPixivDate(novel.cachedAt))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .margin({ top: 5 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('阅读')
        .fontSize(12)
        .height(30)
        .padding({ left: 14, right: 14 })
        .backgroundColor($r('app.color.tab_selected'))
        .fontColor(Color.White)
        .borderRadius(15)
        .margin({ left: 10 })
        .onClick(() => { this.openReader(novel) })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .onClick(() => { this.openReader(novel) })
  }
}

@Builder
export function SeriesDetailBuilder(): void {
  SeriesDetailPage()
}
