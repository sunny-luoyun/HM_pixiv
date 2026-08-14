import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel, formatTextLength, formatPixivDate } from '../../models/PixivModels';
import { PageContext } from '../../common/utils/PageContext';

@Component
export struct CachedNovelsSimplePage {
  @State cachedNovels: PixivNovel[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadCachedNovels();
  }

  async loadCachedNovels() {
    this.isLoading = true;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (ctx) {
        await pixivCacheDB.init(ctx);
      }
      const novels = await pixivCacheDB.getAllCachedNovels();
      this.cachedNovels = novels;
    } catch (err) {
      console.error('获取缓存小说列表失败:', err);
    }
    this.isLoading = false;
  }

  async deleteNovel(novel: PixivNovel) {
    AlertDialog.show({
      title: '删除缓存',
      message: `确定删除「${novel.title}」的缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: async () => {
          await pixivCacheDB.deleteCachedText(novel.id);
          promptAction.showToast({ message: `已删除「${novel.title}」的缓存` });
          this.cachedNovels = this.cachedNovels.filter(n => n.id !== novel.id);
        }
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
    NavDestination() {
      Column() {
        Row() {
          Text('‹')
            .fontSize(28)
            .onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
          Text('查看缓存')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
            .margin({ left: 12 })
          Blank()
          Text(`${this.cachedNovels.length}`)
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .padding({ left: 16, right: 24, top: 16 })

        if (!this.isLoading) {
          Row() {
            Text(`共 ${this.cachedNovels.length} 本缓存小说`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 8, bottom: 4 })
        }

        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(40).height(40)
              .color($r('app.color.tab_selected'))
            Text('加载中...')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.cachedNovels.length === 0) {
          Column() {
            Text('暂无已缓存的小说')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 60 })
          }
          .width('100%')
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        } else {
          List({ space: 8 }) {
            ForEach(this.cachedNovels, (novel: PixivNovel) => {
              ListItem() {
                this.NovelCard(novel)
              }
            }, (novel: PixivNovel): string => novel.id)
          }
          .width('100%')
          .layoutWeight(1)
          .edgeEffect(EdgeEffect.Spring)
          .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_background'))
    }
    .onBackPressed(() => {
      const pageCtx = AppStorage.get<PageContext>('rootPageContext');
      if (pageCtx) { pageCtx.popPage(); }
      return true;
    })
    .hideTitleBar(true)
  }

  @Builder
  NovelCard(novel: PixivNovel) {
    Row() {
      Column() {
        Text(novel.title.charAt(0))
          .fontSize(16)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(42).height(42)
      .borderRadius(8)
      .backgroundColor($r('app.color.tab_selected'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 10 })

      Column() {
        Text(novel.hasTitleTranslation && novel.titleTranslated ? novel.titleTranslated : novel.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(novel.hasTitleTranslation && novel.titleTranslated ? $r('app.color.tab_selected') : $r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 8 }) {
          Text(novel.author)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          Text(formatTextLength(novel.textLength))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
          if (novel.cachedAt) {
            Text(formatPixivDate(novel.cachedAt))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
          }
        }
        .width('100%')
        .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button() {
        Text('🗑').fontSize(15)
      }
      .width(34).height(34)
      .backgroundColor($r('app.color.danger_bg'))
      .borderRadius(17)
      .onClick(() => { this.deleteNovel(novel) })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
  }
}

@Builder
export function CachedNovelsSimpleBuilder(): void {
  CachedNovelsSimplePage()
}
