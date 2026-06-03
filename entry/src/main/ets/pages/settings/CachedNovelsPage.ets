import router from '@ohos.router';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel } from '../../models/PixivModels';

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
export struct CachedNovelsPage {
  @State cachedNovels: PixivNovel[] = [];
  @State authorGroups: AuthorGroup[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadCachedNovels();
  }

  async loadCachedNovels() {
    this.isLoading = true;
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const novels = await pixivCacheDB.getAllCachedNovels();
      this.cachedNovels = novels;
      this.authorGroups = groupNovels(novels);
    } catch (err) {
      console.error('获取缓存小说列表失败:', err);
    }
    this.isLoading = false;
  }

  async deleteAuthorCache(ag: AuthorGroup) {
    AlertDialog.show({
      title: '删除作者缓存',
      message: `确定删除「${ag.authorName}」的全部 ${ag.totalCount} 本缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: async () => {
          const all: PixivNovel[] = [
            ...ag.standaloneNovels,
            ...Array.from(ag.seriesMap.values()).flatMap(sg => sg.novels),
          ];
          for (const n of all) {
            await pixivCacheDB.deleteCachedText(n.id);
          }
          promptAction.showToast({ message: `已删除「${ag.authorName}」的全部缓存` });
          await this.loadCachedNovels();
        }
      }
    });
  }

  openAuthorDetail(ag: AuthorGroup) {
    router.pushUrl({
      url: 'pages/settings/AuthorDetailPage',
      params: {
        authorId: ag.authorId,
        authorName: ag.authorName
      }
    });
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(28)
          .onClick(() => router.back())
        Text('我的缓存小说')
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

      if (!this.isLoading && this.authorGroups.length > 0) {
        Row() {
          Text(`${this.authorGroups.length} 位作者 · ${this.cachedNovels.length} 本缓存`)
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
      } else if (this.authorGroups.length === 0) {
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
        List({ space: 10 }) {
          ForEach(this.authorGroups, (ag: AuthorGroup) => {
            ListItem() {
              this.AuthorCard(ag)
            }
          }, (ag: AuthorGroup): string => ag.authorId)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  AuthorCard(ag: AuthorGroup) {
    Row() {
      Column() {
        Text(ag.authorName.charAt(0).toUpperCase())
          .fontSize(18)
          .fontColor(Color.White)
          .fontWeight(FontWeight.Bold)
      }
      .width(46).height(46)
      .borderRadius(23)
      .backgroundColor($r('app.color.tab_selected'))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ right: 12 })

      Column() {
        Text(ag.authorName)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 6 }) {
          if (ag.seriesMap.size > 0) {
            Text(`📚 ${ag.seriesMap.size} 系列`)
              .fontSize(11)
              .fontColor($r('app.color.success'))
              .backgroundColor($r('app.color.success_bg'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          if (ag.standaloneNovels.length > 0) {
            Text(`📄 ${ag.standaloneNovels.length} 独立`)
              .fontSize(11)
              .fontColor($r('app.color.tab_selected'))
              .backgroundColor($r('app.color.info_bg'))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          }
          Text(`共 ${ag.totalCount} 本`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Row({ space: 8 }) {
        Button() {
          Text('🗑').fontSize(15)
        }
        .width(34).height(34)
        .backgroundColor($r('app.color.danger_bg'))
        .borderRadius(17)
        .onClick(() => { this.deleteAuthorCache(ag) })

        Text('›')
          .fontSize(24)
          .fontColor($r('app.color.text_secondary'))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .onClick(() => {
      this.openAuthorDetail(ag);
    })
  }
}
