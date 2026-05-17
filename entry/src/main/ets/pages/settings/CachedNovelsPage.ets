import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PixivNovel } from '../../models/PixivModels';

@Entry
@Component
export struct CachedNovelsPage {
  @State cachedNovels: PixivNovel[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadCachedNovels();
  }

  async loadCachedNovels() {
    this.isLoading = true;
    try {
      const ctx = globalThis.appContext as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      this.cachedNovels = await pixivCacheDB.getAllCachedNovels();
    } catch (err) {
      console.error('获取缓存小说列表失败:', err);
    }
    this.isLoading = false;
  }

  async deleteNovelCache(novelId: string) {
    try {
      await pixivCacheDB.deleteNovelById(novelId);
      this.cachedNovels = this.cachedNovels.filter(n => n.id !== novelId);
    } catch (err) {
      console.error('删除小说缓存失败:', err);
    }
  }

  handleDelete(novel: PixivNovel) {
    AlertDialog.show({
      title: '删除缓存',
      message: `确定要删除「${novel.title}」的本地缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: () => {
          this.deleteNovelCache(novel.id);
        }
      }
    });
  }

  build() {
    Column() {
      Row() {
        Text('已缓存的小说')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
        Blank()
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16 })

      if (this.isLoading) {
        Text('正在加载...')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 40 })
      } else if (this.cachedNovels.length === 0) {
        Column() {
          Text('暂无已缓存的小说')
            .fontSize(16)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 60 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      } else {
        List() {
          ForEach(this.cachedNovels, (novel: PixivNovel) => {
            ListItem() {
              this.NovelItem(novel)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  NovelItem(novel: PixivNovel) {
    Row() {
      Column() {
        Text(novel.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        if (novel.author) {
          Text(novel.author)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .margin({ top: 4 })
            .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('删除')
        .fontSize(13)
        .fontColor('#FF4D4F')
        .padding({ left: 12, right: 12 })
        .onClick(() => { this.handleDelete(novel) })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.loading_card'))
    .borderRadius(12)
    .margin({ bottom: 8 })
  }
}
