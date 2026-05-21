import router from '@ohos.router';
import { AppState, appState } from '../../store/AppState';
import common from '@ohos.app.ability.common';
import { PixivService } from '../../services/PixivService';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { TranslationStorage } from '../../common/utils/TranslationStorage';
import { getDeepSeekService } from '../../services/DeepSeekService';

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
  @State deepseekApiKey: string = '';
  @State showApiKeyText: boolean = false;
  @State apiKeyCheckState: 'idle' | 'checking' | 'ok' | 'fail' = 'idle';
  @State balanceAmount: string = '';
  @State balanceFetchState: 'idle' | 'loading' | 'ok' | 'fail' = 'idle';

  aboutToAppear() {
    this.deepseekApiKey = AppStorage.get<string>('deepseekApiKey') ?? '';
    this.initCache();
  }

  async checkApiKeyValidity(): Promise<void> {
    this.apiKeyCheckState = 'checking';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(this.deepseekApiKey);
    if (result.success) {
      this.apiKeyCheckState = 'ok';
      this.balanceAmount = result.data;
      this.balanceFetchState = 'ok';
    } else {
      this.apiKeyCheckState = 'fail';
    }
  }

  async clearApiKey(): Promise<void> {
    this.deepseekApiKey = '';
    AppStorage.setOrCreate('deepseekApiKey', '');
    await TranslationStorage.clearDeepSeekApiKey();
    this.apiKeyCheckState = 'idle';
    this.balanceAmount = '';
    this.balanceFetchState = 'idle';
  }

  async fetchBalance(): Promise<void> {
    this.balanceFetchState = 'loading';
    const service = getDeepSeekService();
    const result = await service.fetchBalance(this.deepseekApiKey);
    if (result.success) {
      this.balanceAmount = result.data;
      this.balanceFetchState = 'ok';
    } else {
      this.balanceFetchState = 'fail';
    }
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
      .padding({ left: 24, right: 24, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.glass_bg'))

      Scroll() {
        Column() {
          this.DeepSeekApiKeyCard()
          this.CacheSection()
        }
        .width('100%')
        .padding({ top: 12 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }

  @Builder
  DeepSeekApiKeyCard() {
    Column() {
      Row() {
        Row() {
          Text('DeepSeek API 密钥')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.user_name'))

          if (this.apiKeyCheckState === 'ok') {
            Text(' ●').fontSize(12).fontColor('#52C41A')
          } else if (this.apiKeyCheckState === 'fail') {
            Text(' ●').fontSize(12).fontColor('#FF4D4F')
          } else if (this.deepseekApiKey.length > 0 && this.apiKeyCheckState === 'idle') {
            Text(' ●').fontSize(12).fontColor('#FAAD14')
          }
        }.alignItems(VerticalAlign.Center)

        Blank()

        Text(this.showApiKeyText ? '隐藏' : '显示')
          .fontSize(13)
          .fontColor($r('app.color.tab_selected'))
          .onClick(() => {
            this.showApiKeyText = !this.showApiKeyText;
          })
      }
      .width('100%')
      .margin({ bottom: 10 })

      TextInput({
        text: this.deepseekApiKey,
        placeholder: '粘贴 DeepSeek API 密钥...'
      })
        .width('100%')
        .height(44)
        .fontSize(13)
        .fontColor($r('app.color.user_name'))
        .placeholderColor($r('app.color.text_secondary'))
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(8)
        .padding({ left: 12, right: 12 })
        .border({
          width: 1,
          color: this.deepseekApiKey.length === 0
            ? $r('app.color.divider')
            : this.apiKeyCheckState === 'ok'
              ? '#52C41A'
              : this.apiKeyCheckState === 'fail'
                ? '#FF4D4F'
                : $r('app.color.tab_selected'),
          radius: 8
        })
        .type(this.showApiKeyText ? InputType.Normal : InputType.Password)
        .onChange((val: string): void => {
          this.deepseekApiKey = val;
          this.apiKeyCheckState = 'idle';
          AppStorage.setOrCreate('deepseekApiKey', val);
          TranslationStorage.saveDeepSeekApiKey(val);
        })

      Row() {
        Button(this.apiKeyCheckState === 'checking' ? '验证中...' : '验证密钥')
          .fontSize(13)
          .height(36)
          .layoutWeight(1)
          .fontColor('#FFFFFF')
          .backgroundColor($r('app.color.tab_selected'))
          .borderRadius(8)
          .enabled(this.apiKeyCheckState !== 'checking' && this.deepseekApiKey.length > 0)
          .onClick(() => { this.checkApiKeyValidity(); })

        if (this.deepseekApiKey.length > 0) {
          Button('清除')
            .fontSize(13)
            .height(36)
            .fontColor('#FF4D4F')
            .backgroundColor(Color.Transparent)
            .borderRadius(8)
            .margin({ left: 8 })
            .onClick(() => { this.clearApiKey(); })
        }
      }
      .width('100%')
      .margin({ top: 12 })

      Text('前往 deepseek.com 注册获取 API 密钥，用于翻译日文小说标题和内容')
        .fontSize(11)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 10 })
        .lineHeight(18)

      if (this.deepseekApiKey.length > 0) {
        Divider()
          .strokeWidth(1)
          .color($r('app.color.divider'))
          .margin({ top: 14, bottom: 14 })

        Row() {
          Column() {
            Text('账户余额')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.user_name'))

            if (this.balanceFetchState === 'loading') {
              Text('查询中...')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            } else if (this.balanceFetchState === 'ok' && this.balanceAmount !== '') {
              Text('¥ ' + this.balanceAmount)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#007DFF')
                .margin({ top: 4 })
              Text('约可翻译 ' + (Math.floor(parseFloat(this.balanceAmount) * 53.63 * 10) / 10).toString() + ' 万字小说')
                .fontSize(11)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            } else if (this.balanceFetchState === 'fail') {
              Text('获取失败，请重试')
                .fontSize(12)
                .fontColor('#FF4D4F')
                .margin({ top: 4 })
            } else {
              Text('点击刷新查询余额')
                .fontSize(12)
                .fontColor($r('app.color.text_secondary'))
                .margin({ top: 4 })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button(this.balanceFetchState === 'loading' ? '查询中' : '↻ 刷新')
            .fontSize(13)
            .height(34)
            .padding({ left: 14, right: 14 })
            .fontColor($r('app.color.tab_selected'))
            .backgroundColor($r('app.color.page_background'))
            .borderRadius(8)
            .border({ width: 1, color: $r('app.color.tab_selected'), radius: 8 })
            .enabled(this.balanceFetchState !== 'loading')
            .onClick(() => { this.fetchBalance(); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        Text('估算仅供参考，以官方为准')
          .fontSize(10)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
    .margin({ bottom: 12 })
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
            .color($r('app.color.divider'))
            .margin({ top: 8, bottom: 8 })
          this.CacheRow('总计', this.totalImageCacheSize, this.illustCacheCount + this.novelCoverCacheCount + this.avatarCacheCount, () => { this.clearImageCache('all') })
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
      .margin({ bottom: 12 })

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
          Text('查看详情')
            .fontSize(13)
            .fontColor($r('app.color.tab_selected'))
            .margin({ right: 12 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/settings/CachedNovelsSimplePage' });
            })
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
      .backgroundColor($r('app.color.card_bg'))
      .borderRadius(14)
      .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
      .margin({ bottom: 12 })
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
