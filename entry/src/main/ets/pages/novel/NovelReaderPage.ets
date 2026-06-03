import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { getDeepSeekService } from '../../services/DeepSeekService';
import preferences from '@ohos.data.preferences';

interface ReaderRouterParams {
  novelId: string;
  title: string;
  author: string;
  cached: boolean;
  translatedTitle?: string;
  hasTitleTranslation?: boolean;
}

interface ReaderColors {
  pageBg: string;
  headerBg: string;
  primaryText: string;
  secondaryText: string;
  accentText: string;
  divider: string;
  iconBtnBg: string;
  iconBtnText: string;
  chapterColor: string;
  hrColor: string;
  translateBtnText: string;
  translatedTextColor: string;
  translationProgressBg: string;
  translationProgressFill: string;
  dangerText: string;
  menuBg: string;
  menuItemActive: string;
}

function getReaderColors(isDark: boolean): ReaderColors {
  return {
    pageBg:        isDark ? '#0D0D0D' : '#F9F7F2',
    headerBg:      isDark ? '#141414' : '#FFFFFF',
    primaryText:   isDark ? '#E6E6E6' : '#1A1A1A',
    secondaryText: isDark ? '#888888' : '#666666',
    accentText:    isDark ? '#0A84FF' : '#007DFF',
    divider:       isDark ? '#2A2A2A' : '#E5E5E5',
    iconBtnBg:     isDark ? '#2A2A2A' : '#F0F0F0',
    iconBtnText:   isDark ? '#CCCCCC' : '#444444',
    chapterColor:  isDark ? '#AADDFF' : '#0055AA',
    hrColor:       isDark ? '#333333' : '#DDDDDD',
    translateBtnText: '#007DFF',
    translatedTextColor: isDark ? '#CCE5FF' : '#0055AA',
    translationProgressBg: isDark ? '#333333' : '#E5E5E5',
    translationProgressFill: '#007DFF',
    dangerText: '#FF4D4F',
    menuBg: isDark ? '#CC1C1C1E' : '#E8F2F2F7',
    menuItemActive: isDark ? '#3A3A3C' : '#DDDDDD'
  };
}

type BlockType = 'paragraph' | 'chapter' | 'hr' | 'blank';

interface ContentBlock {
  type: BlockType;
  text: string;
  bold?: boolean;
  italic?: boolean;
}

function parsePixivBlocks(raw: string): ContentBlock[] {
  if (!raw) return [];
  const blocks: ContentBlock[] = [];
  const lines = raw.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      blocks.push({ type: 'blank', text: '', bold: false, italic: false });
      continue;
    }
    if (trimmed === '[newpage]') {
      blocks.push({ type: 'hr', text: '', bold: false, italic: false });
      continue;
    }
    const chapterMatch = trimmed.match(/^\[chapter:(.*?)\]$/);
    if (chapterMatch) {
      blocks.push({ type: 'chapter', text: chapterMatch[1], bold: false, italic: false });
      continue;
    }
    let text = trimmed
      .replace(/\[\[rb:(.*?)>(.*?)\]\]/g, '$1')
      .replace(/\[b\]([\s\S]*?)\[\/b\]/g, '$1')
      .replace(/\[i\]([\s\S]*?)\[\/i\]/g, '$1')
      .replace(/\[jump:(.*?)\]/g, '')
      .replace(/\[[^\]]*\]/g, '');
    if (!text.trim()) continue;
    const hasBold = /\[b\]/.test(line);
    const hasItalic = /\[i\]/.test(line);
    blocks.push({ type: 'paragraph', text: text, bold: hasBold, italic: hasItalic });
  }
  return blocks;
}

@Entry
@Component
struct NovelReaderPage {
  private params: ReaderRouterParams | null = null;

  @State private isCachedMode: boolean = false;
  @State private novelTitle: string = '小说阅读';
  @State private novelAuthor: string = '';
  @State private contentBlocks: ContentBlock[] = [];
  @State private isLoading: boolean = true;
  @State private fontSize: number = 18;
  @StorageProp('isDarkMode') isDark: boolean = false;

  @State private showTranslation: boolean = false;
  @State private isTranslating: boolean = false;
  @State private translationProgress: number = 0;
  @State private translatedTitle: string = '';
  @State private translatedBlocks: ContentBlock[] = [];
  @State private showOriginal: boolean = true;
  @State private renderBlocks: ContentBlock[] = [];

  @State private isAutoReading: boolean = false;
  @State private autoReadSpeedIndex: number = 5;
  @State private showFloatingMenu: boolean = false;
  @State private activeSubMenuIndex: number = -1;
  private touchStartY: number = 0;
  private touchStartTime: number = 0;
  private wasAutoReadingBeforeMenu: boolean = false;
  private wasManuallyStopped: boolean = false;

  private scroller: Scroller = new Scroller();
  private saveProgressTimer: number = -1;
  private readonly PROGRESS_SAVE_DELAY = 800;
  private pendingScrollY: number = 0;
  private autoReadTimerId: number = -1;
  private isProgrammaticScroll: boolean = false;
  private readonly AUTO_READ_BASE_SPEED = 20;
  private readonly AUTO_READ_TICK_INTERVAL = 30;

  aboutToAppear(): void {
    this.params = router.getParams() as ReaderRouterParams;
    this.isCachedMode = this.params?.cached === true;
    this.novelTitle = this.params?.title ?? '小说阅读';
    this.novelAuthor = this.params?.author ?? '';
    if (this.params?.translatedTitle) {
      this.translatedTitle = this.params.translatedTitle;
    }
    if (this.params?.hasTitleTranslation) {
      this.showTranslation = true;
    }

    if (this.isCachedMode && this.params?.novelId) {
      this.loadOfflineContent(this.params.novelId);
    } else if (this.params?.novelId) {
      promptAction.showToast({ message: '小说尚未缓存，请先缓存' });
      setTimeout(() => router.back(), 1000);
    }
  }

  aboutToDisappear(): void {
    this.stopAutoRead();
    if (this.params?.novelId && this.isCachedMode) {
      this.saveProgressInternal(Math.floor(this.scroller.currentOffset().yOffset));
    }
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
    }
  }

  private async loadOfflineContent(novelId: string): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      await pixivCacheDB.init(ctx);

      const text = await pixivCacheDB.getFullText(novelId);
      if (!text) {
        promptAction.showToast({ message: '缓存内容丢失，请重新缓存' });
        router.back();
        return;
      }

      this.contentBlocks = parsePixivBlocks(text);
      this.renderBlocks = this.contentBlocks;

      const novel = await pixivCacheDB.getNovelById(novelId);
      if (novel?.hasTitleTranslation && novel.titleTranslated) {
        this.translatedTitle = novel.titleTranslated;
      }
      if (novel?.hasFullTranslation && novel.fullTextTranslated) {
        this.translatedBlocks = parsePixivBlocks(novel.fullTextTranslated);
      }

      if (this.translatedBlocks.length > 0) {
        const preferTranslation = await this.getViewPreference();
        if (preferTranslation) {
          this.showOriginal = false;
          this.showTranslation = true;
          this.renderBlocks = this.translatedBlocks;
        }
      }

      if (this.renderBlocks.length > 0) {
        const savedY = await pixivCacheDB.getReadingProgress(novelId, !this.showOriginal);
        if (savedY > 0) {
          this.pendingScrollY = savedY;
        }
      }
    } catch (e) {
      console.error(`加载离线内容失败: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '加载失败，请重试' });
    } finally {
      this.isLoading = false;
      if (this.pendingScrollY > 0) {
        setTimeout(() => {
          this.scroller.scrollTo({ xOffset: 0, yOffset: this.pendingScrollY });
          this.pendingScrollY = 0;
        }, 50);
      }
    }
  }

  private async saveProgressInternal(yOffset: number): Promise<void> {
    if (this.params?.novelId) {
      const resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
      if (resetOnReachEnd && this.scroller.isAtEnd()) {
        await pixivCacheDB.deleteReadingProgress(this.params.novelId, !this.showOriginal);
      } else {
        await pixivCacheDB.saveReadingProgress(this.params.novelId, yOffset, !this.showOriginal);
      }
    }
  }

  private debouncedSaveProgress(yOffset: number): void {
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
    }
    this.saveProgressTimer = setTimeout(async () => {
      if (this.params?.novelId) {
        await this.saveProgressInternal(Math.floor(yOffset));
      }
    }, this.PROGRESS_SAVE_DELAY);
  }

  private async translateTitle(): Promise<void> {
    const service = getDeepSeekService();

    if (!service.hasValidKey()) {
      promptAction.showToast({ message: '请先在设置中填入 DeepSeek API 密钥' });
      return;
    }

    this.isTranslating = true;

    const result = await service.translateText(this.novelTitle, true);

    if (result.success && result.translatedText) {
      this.translatedTitle = result.translatedText;

      if (this.params?.novelId) {
        await pixivCacheDB.saveTitleTranslation(this.params.novelId, result.translatedText);
      }

      promptAction.showToast({ message: '标题翻译完成' });
    } else {
      promptAction.showToast({ message: result.error || '翻译失败' });
    }

    this.isTranslating = false;
  }

  private async translateFullText(): Promise<void> {
    const service = getDeepSeekService();

    if (!service.hasValidKey()) {
      promptAction.showToast({ message: '请先在设置中填入 DeepSeek API 密钥' });
      return;
    }

    const novelId = this.params?.novelId;
    if (!novelId) return;

    const ctx = getContext(this) as common.UIAbilityContext;
    await pixivCacheDB.init(ctx);
    const originalText = await pixivCacheDB.getFullText(novelId);

    if (!originalText) {
      promptAction.showToast({ message: '找不到原文内容' });
      return;
    }

    await service.initTokenizer(ctx);
    const inputTokens = service.estimateTokens(originalText);
    const estimatedCostYuan = service.estimateCost(inputTokens);
    const ratio = service.getAdaptiveRatio();
    const count = service.getRatioCount();

    promptAction.showDialog({
      title: '确认翻译全文',
      message: `预计翻译 ${originalText.length} 字符 / ${inputTokens} tokens · 费用约 ¥${estimatedCostYuan.toFixed(4)}\n输出/输入比 ${ratio.toFixed(3)}（已校准 ${count} 次）\n是否继续？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '开始翻译', color: '#007DFF' }
      ]
    }).then((data) => {
      if (data.index === 1) {
        this.performFullTranslation(novelId, originalText);
      }
    });
  }

  private async performFullTranslation(novelId: string, originalText: string): Promise<void> {
    this.isTranslating = true;
    this.showTranslation = true;
    this.translationProgress = 0;

    await pixivCacheDB.updateTranslationProgress(novelId, 0, 'in_progress');

    const service = getDeepSeekService();

    const result = await service.translateLongText(
      originalText,
      (current, total) => {
        this.translationProgress = Math.floor((current / total) * 100);
      }
    );

    if (!result.success) {
      this.isTranslating = false;
      this.showTranslation = false;
      this.translationProgress = 0;
      await pixivCacheDB.updateTranslationProgress(novelId, 0, 'none');
      promptAction.showDialog({
        title: '翻译失败',
        message: result.error || '网络请求失败，请稍后重试',
        buttons: [
          { text: '取消', color: '#666666' },
          { text: '重新翻译', color: '#007DFF' }
        ]
      }).then((data) => {
        if (data.index === 1) {
          this.translateFullText();
        }
      });
      return;
    }

    const translatedText = result.translatedText ?? originalText;
    const newBlocks = parsePixivBlocks(translatedText);
    this.translatedBlocks = newBlocks;
    this.showOriginal = false;
    this.showTranslation = true;
    this.renderBlocks = newBlocks;

    await pixivCacheDB.saveFullTextTranslation(novelId, translatedText);

    this.isTranslating = false;
    promptAction.showToast({ message: '全文翻译完成' });
  }

  private async saveViewPreference(showTranslation: boolean): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const pref = await preferences.getPreferences(ctx, 'pixiv_novel_view');
      await pref.put(`${this.params!.novelId}_showTranslation`, showTranslation);
      await pref.flush();
    } catch (e) {
      console.error('saveViewPreference failed', JSON.stringify(e));
    }
  }

  private async getViewPreference(): Promise<boolean> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const pref = await preferences.getPreferences(ctx, 'pixiv_novel_view');
      const value = await pref.get(`${this.params!.novelId}_showTranslation`, false);
      return value as boolean;
    } catch (e) {
      return false;
    }
  }

  private getColors(): ReaderColors {
    return getReaderColors(this.isDark);
  }

  private toggleDarkMode(): void {
    this.isDark = !this.isDark;
    globalThis.isDarkMode = this.isDark;
    AppStorage.Set('isDarkMode', this.isDark);
  }

  private getSpeedMultiplier(): number {
    return 0.5 + this.autoReadSpeedIndex * 0.1;
  }

  private startAutoRead(): void {
    this.stopAutoRead();
    this.isAutoReading = true;

    this.autoReadTimerId = setInterval(() => {
      if (this.scroller.isAtEnd()) {
        this.stopAutoRead();
        promptAction.showToast({ message: '已到达底部' });
        return;
      }

      const delta = this.AUTO_READ_BASE_SPEED * this.getSpeedMultiplier()
        * this.AUTO_READ_TICK_INTERVAL / 1000;
      this.isProgrammaticScroll = true;
      this.scroller.scrollBy(0, delta);
      this.isProgrammaticScroll = false;
    }, this.AUTO_READ_TICK_INTERVAL);
  }

  private stopAutoRead(): void {
    if (this.autoReadTimerId !== -1) {
      clearInterval(this.autoReadTimerId);
      this.autoReadTimerId = -1;
    }
    this.isAutoReading = false;
  }

  private toggleAutoRead(): void {
    if (this.isAutoReading) {
      this.stopAutoRead();
    } else {
      this.startAutoRead();
    }
  }

  private dismissFloatingMenu(): void {
    this.showFloatingMenu = false;
    this.activeSubMenuIndex = -1;
    if (this.wasAutoReadingBeforeMenu && !this.wasManuallyStopped) {
      this.startAutoRead();
    }
    this.wasAutoReadingBeforeMenu = false;
  }

  private async toggleTranslationView(showTranslated: boolean): Promise<void> {
    if (!this.params?.novelId) return;

    await this.saveProgressInternal(Math.floor(this.scroller.currentOffset().yOffset));

    this.showOriginal = !showTranslated;
    this.showTranslation = showTranslated;
    this.renderBlocks = showTranslated ? this.translatedBlocks : this.contentBlocks;
    this.saveViewPreference(showTranslated);

    setTimeout(async () => {
      const targetY = await pixivCacheDB.getReadingProgress(
        this.params!.novelId, showTranslated
      );
      this.scroller.scrollTo({
        xOffset: 0, yOffset: targetY > 0 ? targetY : 0
      });
    }, 50);
  }

  @Builder HeaderBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('←')
          .fontSize(20)
          .fontColor(this.getColors().iconBtnText)
      }
      .width(40).height(40)
      .backgroundColor(this.getColors().iconBtnBg)
      .onClick(() => {
        this.stopAutoRead();
        router.back();
      })

      Column() {
        if (this.showTranslation && this.translatedTitle) {
          Text(this.translatedTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getColors().translatedTextColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(this.novelTitle)
            .fontSize(11)
            .fontColor(this.getColors().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        } else {
          Text(this.novelTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getColors().primaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }

        if (this.novelAuthor) {
          Text(this.novelAuthor)
            .fontSize(12)
            .fontColor(this.getColors().secondaryText)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 12, right: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.getColors().headerBg)
  }

  @Builder ContentView() {
    if (this.isLoading) {
      Column() {
        LoadingProgress()
          .width(48).height(48)
          .color(this.getColors().accentText)
        Text('正在加载...')
          .fontSize(14)
          .fontColor(this.getColors().secondaryText)
          .margin({ top: 12 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.contentBlocks.length === 0) {
      Column() {
        Text('内容为空')
          .fontSize(16)
          .fontColor(this.getColors().secondaryText)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Scroll(this.scroller) {
        Column() {
          ForEach(
            this.renderBlocks,
            (block: ContentBlock, index: number) => {
              if (block.type === 'chapter') {
                Row() {
                  Blank()
                    .width(3)
                    .height('100%')
                    .backgroundColor(this.showOriginal
                      ? this.getColors().chapterColor
                      : this.getColors().translatedTextColor)

                  Text(block.text)
                    .fontSize(this.fontSize * 1.1)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.showOriginal
                      ? this.getColors().chapterColor
                      : this.getColors().translatedTextColor)
                    .layoutWeight(1)
                    .padding({ left: 13, right: 16, top: 20, bottom: 8 })
                }
                .margin({ left: 16, top: 4, bottom: 4 })
                .width('100%')
              } else if (block.type === 'hr') {
                Divider().color(this.getColors().hrColor)
                  .strokeWidth(1)
                  .margin({ top: 24, bottom: 24, left: 20, right: 20 })
              } else if (block.type === 'blank') {
                Row().height(this.fontSize * 0.6).width('100%')
              } else {
                Text(block.text)
                  .fontSize(this.fontSize)
                  .fontWeight(block.bold ? FontWeight.Bold : FontWeight.Normal)
                  .fontStyle(block.italic ? FontStyle.Italic : FontStyle.Normal)
                  .lineHeight(this.fontSize * 1.9)
                  .fontColor(this.showOriginal
                    ? this.getColors().primaryText
                    : this.getColors().translatedTextColor)
                  .width('100%')
                  .padding({ left: 20, right: 20 })
                  .textAlign(TextAlign.Start)
                  .copyOption(CopyOptions.LocalDevice)
              }
            },
            (block: ContentBlock, index: number) => `${this.showOriginal ? 'orig' : 'trans'}_${index}`
          )

          Row().height(80).width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .scrollable(ScrollDirection.Vertical)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
      .layoutWeight(1)
      .onScroll((_x: number, _y: number) => {
        if (!this.isLoading && this.params?.novelId) {
          this.debouncedSaveProgress(_y);
        }
      })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.touchStartY = event.touches[0].y;
          this.touchStartTime = Date.now();
        } else if (event.type === TouchType.Up) {
          const dy = Math.abs(event.touches[0].y - this.touchStartY);
          const dt = Date.now() - this.touchStartTime;
          if (dy < 10 && dt < 300 && !this.showFloatingMenu) {
            this.wasAutoReadingBeforeMenu = this.isAutoReading;
            this.wasManuallyStopped = false;
            if (this.isAutoReading) {
              this.stopAutoRead();
            }
            this.showFloatingMenu = true;
          }
        }
      })
    }

    if (this.isTranslating) {
      Column() {
        Row() {
          Text(`翻译中... ${this.translationProgress}%`)
            .fontSize(12)
            .fontColor(this.getColors().secondaryText)
          Blank()
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 8 })

        Progress({
          value: this.translationProgress,
          total: 100,
          type: ProgressType.Linear
        })
          .width('100%')
          .height(4)
          .color(this.getColors().accentText)
          .backgroundColor(this.getColors().translationProgressBg)
      }
      .width('100%')
      .backgroundColor(this.getColors().headerBg)
      .padding({ top: 8, bottom: 8 })
    }
  }

  @Builder FloatingMenuBar() {
    Row() {
      this.FloatingTabItem('外观', 0)
      this.FloatingTabItem('翻译', 1)
      this.FloatingTabItem('自动阅读', 2)
    }
    .height(50)
    .padding({ left: 4, right: 4 })
    .width('85%')
    .backgroundColor(this.getColors().menuBg)
    .borderRadius(25)
  }

  @Builder FloatingTabItem(label: string, index: number) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontColor(this.activeSubMenuIndex === index
          ? this.getColors().primaryText
          : this.getColors().secondaryText)
        .fontWeight(this.activeSubMenuIndex === index ? FontWeight.Medium : FontWeight.Normal)
      if (this.activeSubMenuIndex === index) {
        Column()
          .width(20).height(3)
          .backgroundColor(this.getColors().accentText)
          .borderRadius(1.5)
          .margin({ top: 6 })
      }
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.activeSubMenuIndex = index; })
  }

  @Builder SubMenuPanel() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          Text('←')
            .fontSize(18)
            .fontColor(this.getColors().iconBtnText)
        }
        .width(32).height(32)
        .backgroundColor(this.getColors().iconBtnBg)
        .onClick(() => { this.activeSubMenuIndex = -1; })

        Text(this.activeSubMenuIndex === 0 ? '外观'
          : this.activeSubMenuIndex === 1 ? '翻译'
          : '自动阅读')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().primaryText)
          .margin({ left: 10 })
      }
      .width('100%')
      .margin({ bottom: 16 })

      if (this.activeSubMenuIndex === 0) {
        Row() {
          Text(this.isDark ? '☀' : '☾')
            .fontSize(18)
            .margin({ right: 8 })
          Text('深色模式')
            .fontSize(15)
            .fontColor(this.getColors().primaryText)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.isDark })
            .onChange((value: boolean) => {
              this.isDark = value;
              globalThis.isDarkMode = value;
              AppStorage.Set('isDarkMode', value);
            })
        }
        .width('100%')
        .height(40)

        Row() {
          Text('字号')
            .fontSize(15)
            .fontColor(this.getColors().primaryText)
          Blank()
          Button('A-')
            .fontSize(16)
            .fontColor(this.getColors().iconBtnText)
            .backgroundColor(this.getColors().iconBtnBg)
            .borderRadius(8)
            .height(36)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              if (this.fontSize > 12) this.fontSize -= 2;
            })

          Text(`${this.fontSize}px`)
            .fontSize(14)
            .fontColor(this.getColors().primaryText)
            .width(60)
            .textAlign(TextAlign.Center)

          Button('A+')
            .fontSize(16)
            .fontColor(this.getColors().iconBtnText)
            .backgroundColor(this.getColors().iconBtnBg)
            .borderRadius(8)
            .height(36)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              if (this.fontSize < 32) this.fontSize += 2;
            })
        }
        .width('100%')
        .height(44)
      } else if (this.activeSubMenuIndex === 1) {
        if (this.translatedBlocks.length > 0) {
          Row() {
            Text('显示译文')
              .fontSize(15)
              .fontColor(this.getColors().primaryText)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: !this.showOriginal })
              .onChange((value: boolean) => {
                this.toggleTranslationView(value);
              })
          }
          .width('100%')
          .height(40)
        } else {
          Button('翻译全文')
            .fontSize(15)
            .fontColor('#FFFFFF')
            .backgroundColor(this.getColors().accentText)
            .borderRadius(8)
            .height(40)
            .width('100%')
            .onClick(() => { this.translateFullText(); })
        }
      } else if (this.activeSubMenuIndex === 2) {
        Row() {
          Text('自动阅读')
            .fontSize(15)
            .fontColor(this.getColors().primaryText)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.isAutoReading })
            .onChange((value: boolean) => {
              if (value) {
                this.wasManuallyStopped = false;
                this.startAutoRead();
              } else {
                this.wasManuallyStopped = true;
                this.stopAutoRead();
              }
            })
        }
        .width('100%')
        .height(40)

        Row() {
          Text('速度')
            .fontSize(15)
            .fontColor(this.getColors().primaryText)
          Blank()
          Slider({
            value: this.autoReadSpeedIndex,
            min: 0,
            max: 10,
            step: 1,
            style: SliderStyle.InSet
          })
            .width(160)
            .onChange((value: number) => {
              this.autoReadSpeedIndex = value;
              if (this.isAutoReading) {
                this.startAutoRead();
              }
            })
          Text(`${this.getSpeedMultiplier().toFixed(1)}x`)
            .fontSize(14)
            .fontColor(this.getColors().primaryText)
            .width(40)
            .textAlign(TextAlign.End)
        }
        .width('100%')
        .height(44)
      }
    }
    .width('85%')
    .padding(16)
    .backgroundColor(this.getColors().menuBg)
    .borderRadius(20)
  }

  build() {
    Stack() {
      Column() {
        this.HeaderBar()

        Divider()
          .color(this.getColors().divider)
          .strokeWidth(0.5)

        this.ContentView()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.getColors().pageBg)

      if (this.showFloatingMenu) {
        Column() {
          Column()
            .layoutWeight(1)
            .width('100%')

          if (this.activeSubMenuIndex !== -1) {
            Column() { this.SubMenuPanel() }
              .margin({ bottom: 8 })
              .transition(TransitionEffect.translate({ y: 20 })
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 250, curve: Curve.EaseOut }))
          }

          Column() { this.FloatingMenuBar() }
            .margin({ bottom: 24 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#30000000')
        .onClick(() => { this.dismissFloatingMenu(); })
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .height('100%')
  }
}
