import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import common from '@ohos.app.ability.common';
import { pixivCacheDB } from '../../database/PixivCacheDB';

interface ReaderRouterParams {
  novelId: string;
  title: string;
  author: string;
  cached: boolean;
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
    hrColor:       isDark ? '#333333' : '#DDDDDD'
  };
}

type BlockType = 'paragraph' | 'chapter' | 'hr' | 'blank';

interface ContentBlock {
  type: BlockType;
  text: string;
}

function parsePixivBlocks(raw: string): ContentBlock[] {
  if (!raw) return [];
  const blocks: ContentBlock[] = [];
  const lines = raw.split('\n');

  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed) {
      blocks.push({ type: 'blank', text: '' });
      continue;
    }
    if (trimmed === '[newpage]') {
      blocks.push({ type: 'hr', text: '' });
      continue;
    }
    const chapterMatch = trimmed.match(/^\[chapter:(.*?)\]$/);
    if (chapterMatch) {
      blocks.push({ type: 'chapter', text: chapterMatch[1] });
      continue;
    }
    let text = trimmed
      .replace(/\[\[rb:(.*?)>(.*?)\]\]/g, '$1')
      .replace(/\[b\]([\s\S]*?)\[\/b\]/g, '$1')
      .replace(/\[i\]([\s\S]*?)\[\/i\]/g, '$1')
      .replace(/\[jump:(.*?)\]/g, '')
      .replace(/\[[^\]]*\]/g, '');
    if (!text.trim()) continue;
    blocks.push({ type: 'paragraph', text: text });
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
  @State private showFontPanel: boolean = false;
  @State private isDark: boolean = false;

  private scroller: Scroller = new Scroller();
  private saveProgressTimer: number = -1;
  private readonly PROGRESS_SAVE_DELAY = 800;
  @State private hasRestoredPosition: boolean = false;

  aboutToAppear(): void {
    this.params = router.getParams() as ReaderRouterParams;
    this.isCachedMode = this.params?.cached === true;
    this.novelTitle = this.params?.title ?? '小说阅读';
    this.novelAuthor = this.params?.author ?? '';

    if (this.isCachedMode && this.params?.novelId) {
      this.loadOfflineContent(this.params.novelId);
    } else if (this.params?.novelId) {
      promptAction.showToast({ message: '小说尚未缓存，请先缓存' });
      setTimeout(() => router.back(), 1000);
    }
  }

  aboutToDisappear(): void {
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
    }
    if (this.params?.novelId && this.isCachedMode) {
      const yOffset = this.scroller.currentOffset().yOffset;
      pixivCacheDB.saveReadingProgress(this.params.novelId, Math.floor(yOffset));
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

      if (this.contentBlocks.length > 0) {
        const savedY = await pixivCacheDB.getReadingProgress(novelId);
        if (savedY > 0) {
          setTimeout(() => {
            this.scroller.scrollTo({ xOffset: 0, yOffset: savedY });
            this.hasRestoredPosition = true;
          }, 100);
        }
      }
    } catch (e) {
      console.error(`加载离线内容失败: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '加载失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private debouncedSaveProgress(yOffset: number): void {
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
    }
    this.saveProgressTimer = setTimeout(() => {
      if (this.params?.novelId) {
        pixivCacheDB.saveReadingProgress(this.params.novelId, Math.floor(yOffset));
      }
    }, this.PROGRESS_SAVE_DELAY);
  }

  private getColors(): ReaderColors {
    return getReaderColors(this.isDark);
  }

  private toggleDarkMode(): void {
    this.isDark = !this.isDark;
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
      .onClick(() => router.back())

      Column() {
        Text(this.novelTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getColors().primaryText)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

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

      Button({ type: ButtonType.Circle }) {
        Text(this.isDark ? '☀' : '☾')
          .fontSize(16)
          .fontColor(this.getColors().iconBtnText)
      }
      .width(40).height(40)
      .backgroundColor(this.getColors().iconBtnBg)
      .margin({ right: 8 })
      .onClick(() => this.toggleDarkMode())

      Button({ type: ButtonType.Circle }) {
        Text('A')
          .fontSize(16)
          .fontColor(this.getColors().iconBtnText)
      }
      .width(40).height(40)
      .backgroundColor(this.getColors().iconBtnBg)
      .onClick(() => { this.showFontPanel = !this.showFontPanel; })
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
            this.contentBlocks,
            (block: ContentBlock, index: number) => {
              if (block.type === 'chapter') {
                Row() {
                  Blank()
                    .width(3)
                    .height('100%')
                    .backgroundColor(this.getColors().chapterColor)

                  Text(block.text)
                    .fontSize(this.fontSize * 1.1)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.getColors().chapterColor)
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
                  .lineHeight(this.fontSize * 1.9)
                  .fontColor(this.getColors().primaryText)
                  .width('100%')
                  .padding({ left: 20, right: 20 })
                  .textAlign(TextAlign.Start)
                  .copyOption(CopyOptions.LocalDevice)
              }
            },
            (block: ContentBlock, index: number) => `block_${index}`
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
          const yOffset = this.scroller.currentOffset().yOffset;
          this.debouncedSaveProgress(yOffset);
        }
      })
    }
  }

  @Builder FontSizePanel() {
    Column() {
      Blank()
        .layoutWeight(1)
        .width('100%')
        .onClick(() => { this.showFontPanel = false; })

      Column() {
        Text('字体大小')
          .fontSize(14)
          .fontColor(this.getColors().secondaryText)
          .margin({ bottom: 12 })

        Row() {
          Button('A-')
            .fontSize(16)
            .fontColor(this.getColors().iconBtnText)
            .backgroundColor(this.getColors().iconBtnBg)
            .borderRadius(8)
            .height(40)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              if (this.fontSize > 12) this.fontSize -= 2;
            })

          Text(`${this.fontSize}px`)
            .fontSize(16)
            .fontColor(this.getColors().primaryText)
            .width(80)
            .textAlign(TextAlign.Center)

          Button('A+')
            .fontSize(16)
            .fontColor(this.getColors().iconBtnText)
            .backgroundColor(this.getColors().iconBtnBg)
            .borderRadius(8)
            .height(40)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              if (this.fontSize < 32) this.fontSize += 2;
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .padding(20)
      .backgroundColor(this.getColors().headerBg)
      .borderRadius({ topLeft: 16, topRight: 16 })
      .shadow({ radius: 16, color: '#00000033', offsetY: -4 })
    }
    .width('100%')
    .height('100%')
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

      if (this.showFontPanel) {
        this.FontSizePanel()
      }
    }
    .width('100%')
    .height('100%')
  }
}
