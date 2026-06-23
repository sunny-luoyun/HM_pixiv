import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { pixivCacheDB } from '../database/PixivCacheDB';
import { TranslationController, PrepareFullTranslationError, PrepareFullTranslationSuccess } from '../services/TranslationController';
import { ContentBlock, parsePixivBlocks } from '../common/utils/NovelParser';
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import promptAction from '@ohos.promptAction';

export class NovelReaderEventType {
  static readonly LOAD_CONTENT = 'LOAD_CONTENT';
  static readonly TRANSLATE_TITLE = 'TRANSLATE_TITLE';
  static readonly TRANSLATE_FULL = 'TRANSLATE_FULL';
  static readonly TOGGLE_VIEW = 'TOGGLE_VIEW';
  static readonly SAVE_PROGRESS = 'SAVE_PROGRESS';
  static readonly START_AUTO_READ = 'START_AUTO_READ';
  static readonly STOP_AUTO_READ = 'STOP_AUTO_READ';
  static readonly TOGGLE_DARK_MODE = 'TOGGLE_DARK_MODE';
}

@Observed
export class NovelReaderState extends BaseState {
  novelId: string = '';
  novelTitle: string = '小说阅读';
  novelAuthor: string = '';
  isCachedMode: boolean = false;
  contentBlocks: ContentBlock[] = [];
  isLoading: boolean = true;
  fontSize: number = 18;
  isDark: boolean = false;
  showTranslation: boolean = false;
  isTranslating: boolean = false;
  translationProgress: number = 0;
  translatedTitle: string = '';
  translatedBlocks: ContentBlock[] = [];
  showOriginal: boolean = true;
  renderBlocks: ContentBlock[] = [];
  isAutoReading: boolean = false;
  autoReadSpeedIndex: number = 5;
  showFloatingMenu: boolean = false;
  activeSubMenuIndex: number = -1;
  commentCount: number = 0;
  hasTitleTranslation: boolean = false;
}

export class NovelReaderViewModel extends BaseVM<NovelReaderState> {
  private static instance: NovelReaderViewModel;
  private saveProgressTimer: number = -1;
  private readonly PROGRESS_SAVE_DELAY = 800;
  private pendingScrollY: number = 0;
  private autoSaveTimer: number = -1;
  private readonly AUTO_SAVE_INTERVAL = 30000;

  static getInstance(): NovelReaderViewModel {
    if (!NovelReaderViewModel.instance) {
      NovelReaderViewModel.instance = new NovelReaderViewModel();
    }
    return NovelReaderViewModel.instance;
  }

  private constructor() {
    super(new NovelReaderState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case NovelReaderEventType.LOAD_CONTENT:
        this.loadOfflineContent(this.state.novelId);
        break;
      case NovelReaderEventType.TRANSLATE_TITLE:
        this.translateTitle();
        break;
      case NovelReaderEventType.TRANSLATE_FULL:
        this.translateFullText();
        break;
      case NovelReaderEventType.TOGGLE_VIEW:
        this.toggleTranslationView((event.param as Record<string, boolean>)['showTranslated'] ?? false);
        break;
      case NovelReaderEventType.SAVE_PROGRESS:
        this.saveProgress((event.param as Record<string, number>)['yOffset'] ?? 0);
        break;
      case NovelReaderEventType.START_AUTO_READ:
        this.startAutoRead();
        break;
      case NovelReaderEventType.STOP_AUTO_READ:
        this.stopAutoRead();
        break;
      case NovelReaderEventType.TOGGLE_DARK_MODE:
        this.toggleDarkMode();
        break;
    }
  }

  setNovelId(novelId: string, title: string, author: string, cached: boolean, translatedTitle?: string, hasTitleTranslation?: boolean): void {
    const state = this.state;
    state.novelId = novelId;
    state.novelTitle = title || '小说阅读';
    state.novelAuthor = author || '';
    state.isCachedMode = cached;
    if (translatedTitle) state.translatedTitle = translatedTitle;
    if (hasTitleTranslation) state.showTranslation = true;
    if (state.isCachedMode && novelId) {
      state.hasTitleTranslation = hasTitleTranslation || false;
    }
  }

  async loadOfflineContent(novelId: string): Promise<void> {
    const state = this.state;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) {
        promptAction.showToast({ message: '无法获取应用上下文' });
        return;
      }
      await pixivCacheDB.init(ctx);
      const text = await pixivCacheDB.getFullText(novelId);
      if (!text) {
        promptAction.showToast({ message: '缓存内容丢失，请重新缓存' });
        return;
      }
      state.contentBlocks = parsePixivBlocks(text);
      state.renderBlocks = state.contentBlocks;
      const novel = await pixivCacheDB.getNovelById(novelId);
      if (novel?.hasTitleTranslation && novel.titleTranslated) {
        state.translatedTitle = novel.titleTranslated;
      }
      if (novel?.hasFullTranslation && novel.fullTextTranslated) {
        state.translatedBlocks = parsePixivBlocks(novel.fullTextTranslated);
      }
      if (state.translatedBlocks.length > 0) {
        const preferTranslation = await this.getViewPreference();
        if (preferTranslation) {
          state.showOriginal = false;
          state.showTranslation = true;
          state.renderBlocks = state.translatedBlocks;
        }
      }
      if (state.renderBlocks.length > 0) {
        const savedY = await pixivCacheDB.getReadingProgress(novelId, !state.showOriginal);
        if (savedY > 0) {
          this.pendingScrollY = savedY;
        }
      }
    } catch (e) {
      console.error(`加载离线内容失败: ${JSON.stringify(e)}`);
      promptAction.showToast({ message: '加载失败，请重试' });
    } finally {
      state.isLoading = false;
    }
  }

  getPendingScrollY(): number {
    const y = this.pendingScrollY;
    this.pendingScrollY = 0;
    return y;
  }

  async saveProgress(yOffset: number): Promise<void> {
    const state = this.state;
    if (!state.novelId) return;
    const isTranslated = !state.showOriginal;
    const resetOnReachEnd = AppStorage.get<boolean>('resetOnReachEnd') ?? false;
    if (resetOnReachEnd) {
      await pixivCacheDB.deleteReadingProgress(state.novelId, isTranslated);
    } else {
      await pixivCacheDB.saveReadingProgress(state.novelId, Math.floor(yOffset), isTranslated);
    }
  }

  debouncedSaveProgress(yOffset: number): void {
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
    }
    this.saveProgressTimer = setTimeout(async () => {
      if (this.state.novelId) {
        await this.saveProgress(yOffset);
      }
    }, this.PROGRESS_SAVE_DELAY);
  }

  startAutoSave(): void {
    if (this.autoSaveTimer !== -1) return;
    this.autoSaveTimer = setInterval(() => {
      AppStorage.setOrCreate('bgNovelId', this.state.novelId);
      AppStorage.setOrCreate('bgIsTranslated', !this.state.showOriginal);
    }, this.AUTO_SAVE_INTERVAL);
  }

  stopAutoSave(): void {
    if (this.autoSaveTimer !== -1) {
      clearInterval(this.autoSaveTimer);
      this.autoSaveTimer = -1;
    }
  }

  async translateTitle(): Promise<void> {
    const state = this.state;
    state.isTranslating = true;
    const result = await TranslationController.translateTitle(state.novelId, state.novelTitle);
    if (result.success && result.translatedTitle) {
      state.translatedTitle = result.translatedTitle;
      promptAction.showToast({ message: '标题翻译完成' });
    } else {
      promptAction.showToast({ message: result.error || '翻译失败' });
    }
    state.isTranslating = false;
  }

  async translateFullText(): Promise<void> {
    const state = this.state;
    if (!state.novelId) return;
    const prep = await TranslationController.prepareFullTranslation(state.novelId);
    const prepErr = prep as PrepareFullTranslationError;
    if (prepErr.error) {
      promptAction.showToast({ message: prepErr.error });
      return;
    }
    const prepOk = prep as PrepareFullTranslationSuccess;
    await this.performFullTranslation(state.novelId, prepOk.originalText);
  }

  async performFullTranslation(novelId: string, originalText: string): Promise<void> {
    const state = this.state;
    state.isTranslating = true;
    state.showTranslation = true;
    state.translationProgress = 0;
    const result = await TranslationController.performFullTranslation(
      novelId, originalText,
      (current, total) => {
        state.translationProgress = Math.floor((current / total) * 100);
      }
    );
    if (!result.success) {
      state.isTranslating = false;
      state.showTranslation = false;
      state.translationProgress = 0;
      return;
    }
    state.translatedBlocks = result.translatedBlocks!;
    state.showOriginal = false;
    state.renderBlocks = state.translatedBlocks;
    state.isTranslating = false;
    promptAction.showToast({ message: '全文翻译完成' });
  }

  async toggleTranslationView(showTranslated: boolean): Promise<void> {
    const state = this.state;
    if (!state.novelId) return;
    state.showOriginal = !showTranslated;
    state.showTranslation = showTranslated;
    state.renderBlocks = showTranslated ? state.translatedBlocks : state.contentBlocks;
    await this.saveViewPreference(showTranslated);
  }

  async getSavedProgress(isTranslated: boolean): Promise<number> {
    if (!this.state.novelId) return 0;
    return await pixivCacheDB.getReadingProgress(this.state.novelId, isTranslated);
  }

  private async saveViewPreference(showTranslation: boolean): Promise<void> {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return;
    try {
      const pref = await preferences.getPreferences(ctx, 'pixiv_novel_view');
      await pref.put(`${this.state.novelId}_showTranslation`, showTranslation);
      await pref.flush();
    } catch (e) {
      console.error('saveViewPreference failed', JSON.stringify(e));
    }
  }

  private async getViewPreference(): Promise<boolean> {
    const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
    if (!ctx) return false;
    try {
      const pref = await preferences.getPreferences(ctx, 'pixiv_novel_view');
      const value = await pref.get(`${this.state.novelId}_showTranslation`, false);
      return value as boolean;
    } catch (e) {
      return false;
    }
  }

  toggleDarkMode(): void {
    this.state.isDark = !this.state.isDark;
    AppStorage.setOrCreate('isDarkMode', this.state.isDark);
  }

  getSpeedMultiplier(): number {
    return 0.5 + this.state.autoReadSpeedIndex * 0.15;
  }

  startAutoRead(): void {
    this.state.isAutoReading = true;
  }

  stopAutoRead(): void {
    this.state.isAutoReading = false;
  }

  cleanup(): void {
    if (this.saveProgressTimer !== -1) {
      clearTimeout(this.saveProgressTimer);
      this.saveProgressTimer = -1;
    }
    this.stopAutoSave();
    this.stopAutoRead();
  }

  async fetchCommentCount(): Promise<void> {
    const result = await TranslationController.fetchNovelDetail(this.state.novelId);
    this.state.commentCount = result.commentCount;
  }
}
