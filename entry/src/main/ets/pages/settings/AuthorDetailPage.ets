import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel, formatTextLength, formatPixivDate } from '../../models/PixivModels';

interface SeriesGroup {
  seriesId: string;
  seriesTitle: string;
  novels: PixivNovel[];
}

interface AuthorGroup {
  authorId: string;
  authorName: string;
  standaloneNovels: PixivNovel[];
  seriesMap: Map<string, SeriesGroup>;
  totalCount: number;
}

function groupNovels(novels: PixivNovel[]): AuthorGroup[] {
  const authorMap = new Map<string, AuthorGroup>();
  for (const novel of novels) {
    let group = authorMap.get(novel.authorId);
    if (!group) {
      group = {
        authorId: novel.authorId,
        authorName: novel.author,
        standaloneNovels: [],
        seriesMap: new Map(),
        totalCount: 0,
      };
      authorMap.set(novel.authorId, group);
    }
    if (novel.series) {
      const sid = novel.series.id;
      let sg = group.seriesMap.get(sid);
      if (!sg) {
        sg = { seriesId: sid, seriesTitle: novel.series.title, novels: [] };
        group.seriesMap.set(sid, sg);
      }
      sg.novels.push(novel);
    } else {
      group.standaloneNovels.push(novel);
    }
    group.totalCount++;
  }
  for (const ag of authorMap.values()) {
    for (const sg of ag.seriesMap.values()) {
      sg.novels.sort((a, b) => (a.series?.order ?? 0) - (b.series?.order ?? 0));
    }
  }
  return Array.from(authorMap.values()).sort((a, b) =>
    a.authorName.localeCompare(b.authorName)
  );
}

@Entry
@Component
export struct AuthorDetailPage {
  private authorId: string = '';
  private authorName: string = '';
  @State authorGroup: AuthorGroup | null = null;
  @State isLoading: boolean = true;

  aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    this.authorId = params['authorId'] as string;
    this.authorName = params['authorName'] as string;
    this.loadAuthorNovels();
  }

  async loadAuthorNovels() {
    this.isLoading = true;
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const novels = await pixivCacheDB.getAllCachedNovels();
      const filtered = novels.filter(n => n.authorId === this.authorId && n.cacheStatus === 'cached');
      const groups = groupNovels(filtered);
      this.authorGroup = groups.length > 0 ? groups[0] : null;
    } catch (err) {
      console.error('获取作者缓存失败:', err);
    }
    this.isLoading = false;
  }

  openReader(novel: PixivNovel) {
    router.pushUrl({
      url: 'pages/novel/NovelReaderPage',
      params: {
        novelId: novel.id,
        title: novel.title,
        author: novel.author,
        cached: true,
        translatedTitle: novel.titleTranslated || '',
        hasTitleTranslation: !!novel.hasTitleTranslation
      }
    });
  }

  openSeries(sg: SeriesGroup) {
    router.pushUrl({
      url: 'pages/settings/SeriesDetailPage',
      params: {
        seriesId: sg.seriesId,
        seriesTitle: sg.seriesTitle,
        authorName: this.authorName
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
      Row() {
        Text('‹')
          .fontSize(28)
          .onClick(() => router.back())
        Text(this.authorName)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
          .margin({ left: 12 })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 24, top: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40).height(40)
            .color($r('app.color.tab_selected'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.authorGroup) {
        Column() {
          Text('未找到该作者的缓存小说')
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
            // Author info header
        Row() {
          Column() {
            Text(this.authorName.charAt(0).toUpperCase())
              .fontSize(22)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
          }
          .width(52).height(52)
          .borderRadius(26)
          .backgroundColor($r('app.color.tab_selected'))
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 14 })

          Column() {
            Text(this.authorName)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${this.authorGroup.totalCount} 本缓存  ·  ${this.authorGroup.seriesMap.size} 个系列`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
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
        .margin({ bottom: 8 })
        .onClick(() => {
          router.pushUrl({
            url: 'pages/user/UserProfilePage',
            params: {
              userId: this.authorId,
              userName: this.authorName
            }
          });
        })

            // Series section
            if (this.authorGroup.seriesMap.size > 0) {
              Text('📚 系列')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 4, bottom: 8 })
                .width('100%')
                .margin({ top: 4 })

              Column({ space: 8 }) {
                ForEach(
                  Array.from(this.authorGroup.seriesMap.values()),
                  (sg: SeriesGroup) => {
                    this.SeriesCard(sg)
                  },
                  (sg: SeriesGroup): string => sg.seriesId
                )
              }
              .width('100%')
            }

            // Standalone novels section
            if (this.authorGroup.standaloneNovels.length > 0) {
              Text('📄 独立小说')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .fontWeight(FontWeight.Medium)
                .padding({ left: 4, bottom: 8, top: this.authorGroup.seriesMap.size > 0 ? 12 : 4 })
                .width('100%')

              Column({ space: 8 }) {
                ForEach(
                  this.authorGroup.standaloneNovels,
                  (novel: PixivNovel) => {
                    this.NovelCard(novel)
                  },
                  (novel: PixivNovel): string => novel.id
                )
              }
              .width('100%')
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 120 })
        }
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  SeriesCard(sg: SeriesGroup) {
    Row() {
      Column() {
        Row() {
          Text('系列')
            .fontSize(10)
            .fontColor($r('app.color.success'))
            .backgroundColor($r('app.color.success_bg'))
            .borderRadius(4)
            .padding({ left: 5, right: 5, top: 2, bottom: 2 })
            .margin({ right: 8 })

          Text(sg.seriesTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.user_name'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
        }
        .width('100%')

        Text(`共 ${sg.novels.length} 话已缓存`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 })

        if (sg.novels.length > 0) {
          Column() {
            ForEach(
              sg.novels.slice(0, 2),
              (n: PixivNovel) => {
                Text(`第${n.series?.order ?? '-'}话  ${(n.hasTitleTranslation && n.titleTranslated) ? n.titleTranslated : n.title}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ top: 3 })
              },
              (n: PixivNovel): string => n.id
            )
            if (sg.novels.length > 2) {
              Text(`…还有 ${sg.novels.length - 2} 话`)
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 3 })
            }
          }
          .width('100%')
          .margin({ top: 6 })
          .padding({ left: 8, top: 6, bottom: 6, right: 8 })
          .backgroundColor($r('app.color.surface_secondary'))
          .borderRadius(6)
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(22)
        .fontColor($r('app.color.text_secondary'))
        .margin({ left: 8 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .onClick(() => { this.openSeries(sg) })
  }

  @Builder
  NovelCard(novel: PixivNovel) {
    Row() {
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
