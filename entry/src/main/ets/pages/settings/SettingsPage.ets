import { AppState, appState } from '../../store/AppState';
import common from '@ohos.app.ability.common';
import { PixivService } from '../../services/PixivService';
import { pixivCacheDB } from '../../database/PixivCacheDB';

function formatFileSize(bytes: number): string {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

@Entry
@Component
export struct SettingsPage {
  @StorageLink('appState') appState: AppState = appState;

  @State illustCacheSize: number = 0;
  @State illustCacheCount: number = 0;
  @State novelCoverCacheSize: number = 0;
  @State novelCoverCacheCount: number = 0;
  @State avatarCacheSize: number = 0;
  @State avatarCacheCount: number = 0;
  @State cachedNovelCount: number = 0;
  @State isLoadingCache: boolean = true;

  aboutToAppear() {
    this.initCache();
  }

  async initCache() {
    const ctx = globalThis.appContext as common.UIAbilityContext;
    if (ctx) {
      await pixivCacheDB.init(ctx);
    }
    await this.refreshCacheInfo();
  }

  async refreshCacheInfo() {
    this.isLoadingCache = true;
    try {
      const results = await Promise.all([
        PixivService.getCategoryCacheInfo('illust_'),
        PixivService.getCategoryCacheInfo('novel_'),
        PixivService.getCategoryCacheInfo('user_'),
        PixivService.getCategoryCacheInfo('avatar_'),
        pixivCacheDB.getCachedNovelCount()
      ]);
      const illust = results[0];
      const novelCover = results[1];
      const user = results[2];
      const avatar = results[3];
      const novelCount = results[4];
      this.illustCacheSize = illust.size;
      this.illustCacheCount = illust.count;
      this.novelCoverCacheSize = novelCover.size;
      this.novelCoverCacheCount = novelCover.count;
      this.avatarCacheSize = user.size + avatar.size;
      this.avatarCacheCount = user.count + avatar.count;
      this.cachedNovelCount = novelCount;
    } catch (err) {
      console.error('获取缓存信息失败:', err);
    }
    this.isLoadingCache = false;
  }

  async clearImageCache(category: string) {
    AlertDialog.show({
      title: '确认清除',
      message: `确定要清除${this.getCategoryLabel(category)}缓存吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清除',
        fontColor: '#FF4D4F',
        action: async () => {
          try {
            if (category === 'illust') {
              await PixivService.clearCategoryCache('illust_');
            } else if (category === 'novel') {
              await PixivService.clearCategoryCache('novel_');
            } else if (category === 'avatar') {
              await PixivService.clearCategoryCache('user_');
              await PixivService.clearCategoryCache('avatar_');
            } else if (category === 'all') {
              await PixivService.clearAllImageCache();
            }
            await this.refreshCacheInfo();
          } catch (err) {
            console.error('清除缓存失败:', err);
          }
        }
      }
    });
  }

  getCategoryLabel(category: string): string {
    switch (category) {
      case 'illust': return '插画';
      case 'novel': return '小说封面';
      case 'avatar': return '头像';
      case 'all': return '图片';
      default: return '';
    }
  }

  async clearNovelCache() {
    AlertDialog.show({
      title: '确认清除',
      message: `确定要清除全部 ${this.cachedNovelCount} 篇已缓存的小说吗？`,
      autoCancel: true,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '清除',
        fontColor: '#FF4D4F',
        action: async () => {
          try {
            await pixivCacheDB.deleteAllCachedNovels();
            await this.refreshCacheInfo();
          } catch (err) {
            console.error('清除小说缓存失败:', err);
          }
        }
      }
    });
  }

  get totalImageCacheSize(): number {
    return this.illustCacheSize + this.novelCoverCacheSize + this.avatarCacheSize;
  }

  build() {
    Column() {
      Row() {
        Text('设置')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.user_name'))
        Blank()
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 16 })

      this.CacheSection()
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  CacheSection() {
    Column() {
      Text('缓存管理')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.user_name'))
        .width('100%')
        .margin({ bottom: 12 })

      Column() {
        Text('图片缓存')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.user_name'))
          .width('100%')
          .margin({ bottom: 8 })

        if (this.isLoadingCache) {
          Text('正在加载...')
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 8, bottom: 8 })
        } else {
          this.CacheRow('插画缓存', this.illustCacheSize, this.illustCacheCount, () => { this.clearImageCache('illust') })
          this.CacheRow('小说封面', this.novelCoverCacheSize, this.novelCoverCacheCount, () => { this.clearImageCache('novel') })
          this.CacheRow('头像缓存', this.avatarCacheSize, this.avatarCacheCount, () => { this.clearImageCache('avatar') })
          Divider()
            .height(1)
            .color('#333333')
            .margin({ top: 8, bottom: 8 })
          this.CacheRow('总计', this.totalImageCacheSize, this.illustCacheCount + this.novelCoverCacheCount + this.avatarCacheCount, () => { this.clearImageCache('all') })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.loading_card'))
      .borderRadius(12)
      .margin({ bottom: 10 })

      Column() {
        Row() {
          Column() {
            Text('小说缓存')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))
            if (!this.isLoadingCache) {
              Text(`已缓存 ${this.cachedNovelCount} 篇小说`)
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Button('清除全部')
            .fontSize(13)
            .fontColor('#FF4D4F')
            .backgroundColor('#33FF4D4F')
            .borderRadius(16)
            .height(32)
            .padding({ left: 16, right: 16 })
            .onClick(() => { this.clearNovelCache() })
        }
        .width('100%')
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.loading_card'))
      .borderRadius(12)
      .margin({ bottom: 10 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
    .margin({ top: 20 })
  }

  @Builder
  CacheRow(label: string, size: number, count: number, action: () => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.user_name'))
      Blank()
      Text(`${formatFileSize(size)} (${count} 个文件)`)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ right: 12 })
      Text('清除')
        .fontSize(13)
        .fontColor('#FF4D4F')
        .onClick(action)
    }
    .width('100%')
    .height(36)
  }
}
