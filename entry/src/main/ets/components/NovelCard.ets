import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { NovelBookmark, PixivService } from '../services/PixivService';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { CacheStatus, getCacheStatusDisplay, PixivTag } from '../models/PixivModels';
import { getDeepSeekService } from '../services/DeepSeekService';

@Component
export struct NovelCard {
  private item!: NovelBookmark;
  @State localCoverPath: string = '';
  @State cacheStatus: CacheStatus = CacheStatus.NOT_CACHED;
  @State cacheLabel: string = '缓存';
  @State cacheColor: string = '#666666';
  @State translatingTitle: boolean = false;
  @State translatedTitle: string = '';
  @State hasTitleTranslation: boolean = false;
  @State showOriginalTitle: boolean = true;

  async aboutToAppear() {
    if (!this.item.url) return;
    const path = await PixivService.cacheImage(this.item.url, `novel_${this.item.id}.jpg`);
    if (path) {
      this.localCoverPath = path;
    }
    await this.checkCacheStatus();
  }

  async checkCacheStatus() {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      const novel = await pixivCacheDB.getNovelById(this.item.id);
      if (novel) {
        this.cacheStatus = novel.cacheStatus;
        if (novel.hasTitleTranslation && novel.titleTranslated) {
          this.translatedTitle = novel.titleTranslated;
          this.hasTitleTranslation = true;
          this.showOriginalTitle = false;
        }
      }
    } catch (_) {}
    this.updateCacheDisplay();
  }

  async handleTitleClick() {
    if (this.translatingTitle) return;

    if (this.hasTitleTranslation) {
      this.showOriginalTitle = !this.showOriginalTitle;
      promptAction.showToast({
        message: this.showOriginalTitle ? '已切换为原文' : '已切换为译文'
      });
      return;
    }

    const service = getDeepSeekService();
    if (!service.hasValidKey()) {
      promptAction.showToast({ message: '请先在设置中填入 DeepSeek API 密钥' });
      return;
    }

    this.translatingTitle = true;

    const result = await service.translateText(this.item.title, true);

    if (result.success && result.translatedText) {
      this.translatedTitle = result.translatedText;
      this.hasTitleTranslation = true;
      this.showOriginalTitle = false;

      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);
      await pixivCacheDB.saveTitleTranslation(this.item.id, result.translatedText);

      promptAction.showToast({ message: '标题翻译完成' });
    } else {
      promptAction.showToast({ message: result.error || '翻译失败' });
    }

    this.translatingTitle = false;
  }

  updateCacheDisplay() {
    const display = getCacheStatusDisplay(this.cacheStatus);
    this.cacheLabel = display.label;
    this.cacheColor = display.color;
  }

  async handleCache() {
    if (this.cacheStatus === CacheStatus.CACHED) {
      this.handleDeleteCache();
      return;
    }
    if (this.cacheStatus === CacheStatus.CACHING) {
      promptAction.showToast({ message: '正在缓存中...' });
      return;
    }

    try {
      this.cacheStatus = CacheStatus.CACHING;
      this.updateCacheDisplay();

      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);

      await pixivCacheDB.saveNovelMeta({
        id: this.item.id,
        title: this.item.title,
        caption: this.item.description || '',
        author: this.item.userName,
        authorId: this.item.userId,
        coverUrl: this.item.url,
        tags: (this.item.tags || []).map((t): PixivTag => ({ name: t })),
        textLength: this.item.wordCount || this.item.textCount || 0,
        pageCount: this.item.pageCount || 1,
        createDate: this.item.createDate,
        updateDate: this.item.updateDate,
        series: this.item.series ? {
          id: String(this.item.series.id),
          title: this.item.series.title,
          order: this.item.series.order ?? this.item.seriesContentOrder ?? this.item.seriesOrder
        } : (this.item.seriesId ? {
          id: String(this.item.seriesId),
          title: this.item.seriesTitle ?? '',
          order: this.item.seriesContentOrder ?? this.item.seriesOrder
        } : undefined),
        bookmarkCount: this.item.bookmarkCount || 0,
        viewCount: 0,
        commentCount: this.item.commentCount || 0,
        cacheStatus: CacheStatus.NOT_CACHED
      });

      await pixivCacheDB.markCaching(this.item.id);

      const fullText = await PixivService.fetchNovelText(this.item.id);

      await pixivCacheDB.saveFullText(this.item.id, fullText);

      this.cacheStatus = CacheStatus.CACHED;
      this.updateCacheDisplay();
      promptAction.showToast({ message: '缓存完成 ✓' });
    } catch (err) {
      console.error(`缓存小说失败: ${err}`);
      this.cacheStatus = CacheStatus.CACHE_FAIL;
      this.updateCacheDisplay();
      promptAction.showToast({ message: `缓存失败: ${err}` });
    }
  }

  async handleDeleteCache() {
    promptAction.showDialog({
      title: '删除缓存',
      message: `确定要删除「${this.item.title}」的本地缓存吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '删除', color: '#FF4D4F' }
      ]
    }).then(async (data) => {
      if (data.index === 1) {
        try {
          const ctx = getContext(this) as common.UIAbilityContext;
          await pixivCacheDB.init(ctx);
          await pixivCacheDB.deleteCachedText(this.item.id);
          this.cacheStatus = CacheStatus.NOT_CACHED;
          this.updateCacheDisplay();
          promptAction.showToast({ message: '缓存已删除' });
        } catch (err) {
          console.error(`删除缓存失败: ${err}`);
          promptAction.showToast({ message: '删除失败' });
        }
      }
    });
  }

  handleRead() {
    if (this.cacheStatus === CacheStatus.CACHED) {
      router.pushUrl({
        url: 'pages/novel/NovelReaderPage',
        params: {
          novelId: this.item.id,
          title: this.item.title,
          author: this.item.userName,
          cached: true,
          translatedTitle: this.translatedTitle || '',
          hasTitleTranslation: this.hasTitleTranslation
        }
      });
    } else {
      promptAction.showToast({ message: '请先缓存小说' });
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

      Row() {
        this.CacheStatusTag()
        Blank()
        this.ReadButton()
        this.CacheButton()
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .margin({ bottom: 12 })
    .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
  }

  @Builder
  CacheStatusTag() {
    if (this.cacheStatus !== CacheStatus.NOT_CACHED) {
      Row() {
        Text(this.cacheLabel)
          .fontSize(11)
          .fontColor(Color.White)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
      }
      .backgroundColor(this.cacheColor)
      .borderRadius(10)
      .height(22)
    }
  }

  @Builder
  ReadButton() {
    Button('📖 阅读')
      .fontSize(13)
      .fontColor(Color.White)
      .backgroundColor('#52C41A')
      .borderRadius(18)
      .height(36)
      .padding({ left: 16, right: 16 })
      .margin({ right: 8 })
      .onClick(() => this.handleRead())
  }

  @Builder
  CacheButton() {
    Button(this.cacheStatus === CacheStatus.CACHED ? '🗑 删除缓存' : '📥 缓存')
      .fontSize(13)
      .fontColor(Color.White)
      .backgroundColor($r('app.color.tab_selected'))
      .borderRadius(18)
      .height(36)
      .padding({ left: 16, right: 16 })
      .enabled(this.cacheStatus !== CacheStatus.CACHING)
      .onClick(() => this.handleCache())
  }

  @Builder
  CoverImage() {
    if (this.localCoverPath || this.item.url) {
      Image(this.localCoverPath || this.item.url)
        .width(80)
        .height(110)
        .objectFit(ImageFit.Cover)
        .borderRadius(8)
        .margin({ right: 14 })
    } else {
      Column() {
        Text('📄')
          .fontSize(28)
      }
      .width(80)
      .height(110)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.loading_card'))
      .borderRadius(8)
      .margin({ right: 14 })
    }
  }

  @Builder
  InfoSection() {
    Column() {
      Row() {
        if (this.translatingTitle) {
          LoadingProgress()
            .width(14).height(14)
            .color($r('app.color.tab_selected'))
            .margin({ right: 6 })
        }
        Text(
          this.showOriginalTitle ? this.item.title
            : (this.translatedTitle || this.item.title)
        )
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hasTitleTranslation && !this.showOriginalTitle
            ? $r('app.color.tab_selected') : $r('app.color.user_name'))
          .layoutWeight(1)
          .onClick(() => this.handleTitleClick())

        if (this.hasTitleTranslation) {
          Text('译')
            .fontSize(9)
            .fontColor('#52C41A')
            .backgroundColor('#F6FFED')
            .borderRadius(3)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .margin({ left: 4 })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.item.seriesTitle) {
        Text(this.item.seriesTitle)
          .fontSize(12)
          .fontColor($r('app.color.tab_selected'))
          .margin({ top: 4 })
          .width('100%')
          .onClick(() => {
            const sid = this.item.series?.id ?? this.item.seriesId;
            if (sid) {
              router.pushUrl({
                url: 'pages/novel/NovelSeriesPage',
                params: {
                  seriesId: String(sid),
                  seriesTitle: this.item.seriesTitle
                }
              });
            }
          })
      }

      Text(this.item.userName)
        .fontSize(12)
        .fontColor($r('app.color.tab_selected'))
        .maxLines(1)
        .margin({ top: 4 })
        .width('100%')
        .onClick(() => {
          router.pushUrl({
            url: 'pages/user/UserProfilePage',
            params: {
              userId: this.item.userId,
              userName: this.item.userName
            }
          });
        })

      if (this.item.tags && this.item.tags.length > 0) {
        Text(this.item.tags.join(' · '))
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
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
