import { BaseState } from './BaseState';
import { BaseVM, BaseVMEvent } from './BaseVM';
import { LoadingModel } from '../models/LoadingModel';
import { IllustDetailBody } from '../models/PixivModels';
import { PixivService } from '../services/PixivService';
import promptAction from '@ohos.promptAction';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';

export class IllustDetailEventType {
  static readonly LOAD_DETAIL = 'LOAD_DETAIL';
  static readonly DOWNLOAD_IMAGE = 'DOWNLOAD_IMAGE';
  static readonly TOGGLE_BOOKMARK = 'TOGGLE_BOOKMARK';
  static readonly CHANGE_PAGE = 'CHANGE_PAGE';
}

export interface ImageRenderSize {
  width: number;
  height: number;
}

@Observed
export class IllustDetailState extends BaseState {
  illustId: string = '';
  thumbnailLocalUrl: string = '';
  detail: IllustDetailBody | null = null;
  isLoading: boolean = true;
  errorMsg: string = '';
  localImageUrls: string[] = [];
  currentIndex: number = 0;
  pageRegularUrls: string[] = [];
  isDownloading: boolean = false;
  downloadSuccess: boolean = false;
  downloadFail: boolean = false;
  illustPageCount: number = 1;
  isActive: boolean = false;
  isBookmarked: boolean = false;
  isBookmarkLoading: boolean = false;
  bookmarkScale: number = 1;
  scaleValue: number = 1;
  translateX: number = 0;
  translateY: number = 0;
  imageOpacityArray: number[] = [];
  imageRenderSizes: ImageRenderSize[] = [];
  backgroundImageUrl: string = '';
  backgroundOpacity: number = 0;
  dominantColor: string = '';
  bgColor: string = '#000000';
  screenWidth: number = 0;
  screenHeight: number = 0;
}

export class IllustDetailViewModel extends BaseVM<IllustDetailState> {
  private static instance: IllustDetailViewModel;

  static getInstance(): IllustDetailViewModel {
    if (!IllustDetailViewModel.instance) {
      IllustDetailViewModel.instance = new IllustDetailViewModel();
    }
    return IllustDetailViewModel.instance;
  }

  private constructor() {
    super(new IllustDetailState());
  }

  sendEvent(event: BaseVMEvent): void {
    switch (event.type) {
      case IllustDetailEventType.LOAD_DETAIL:
        this.loadDetail();
        break;
      case IllustDetailEventType.DOWNLOAD_IMAGE:
        this.handleDownload();
        break;
      case IllustDetailEventType.TOGGLE_BOOKMARK:
        this.toggleBookmark();
        break;
      case IllustDetailEventType.CHANGE_PAGE:
        this.changePage((event.param as Record<string, number>)['index'] ?? 0);
        break;
    }
  }

  setIllustId(illustId: string, thumbnailLocalUrl: string): void {
    const state = this.state;
    state.illustId = illustId;
    state.thumbnailLocalUrl = thumbnailLocalUrl;
    if (state.thumbnailLocalUrl) {
      state.localImageUrls = [state.thumbnailLocalUrl];
      state.imageOpacityArray = [0];
      state.backgroundImageUrl = state.thumbnailLocalUrl;
      state.illustPageCount = 1;
      state.backgroundOpacity = 0.5;
    }
  }

  async loadDetail(): Promise<void> {
    const state = this.state;
    if (!state.illustId) {
      state.errorMsg = '缺少插图ID';
      state.isLoading = false;
      return;
    }
    state.isLoading = true;
    state.errorMsg = '';
    try {
      const res = await PixivService.getIllustDetail(state.illustId);
      if (!state.isActive) return;
      if (!res.error && res.body) {
        state.detail = res.body;
        state.isBookmarked = !!res.body.bookmarkData;
        const pageCount = res.body.pageCount;
        state.illustPageCount = pageCount;
        const urls = PixivService.generatePageUrls(res.body.urls.regular, pageCount);
        state.pageRegularUrls = urls;
        const newUrls = new Array<string>(pageCount).fill('');
        if (state.thumbnailLocalUrl) {
          newUrls[0] = state.thumbnailLocalUrl;
        }
        state.localImageUrls = newUrls;
        state.imageOpacityArray = new Array<number>(pageCount).fill(0);
        state.imageRenderSizes = new Array(pageCount);
        state.isLoading = false;
        const illustId = res.body.illustId;
        const groupId = `detail_${illustId}`;
        urls.forEach((url, i) => {
          PixivService.cacheImage(url, `illust_${illustId}_pg${i}.jpg`, groupId)
            .then((path) => {
              if (state.isActive && path) {
                const updated = [...state.localImageUrls];
                updated[i] = path;
                state.localImageUrls = updated;
                const opacityUpdated = [...state.imageOpacityArray];
                opacityUpdated[i] = 0;
                state.imageOpacityArray = opacityUpdated;
              }
            })
            .catch(() => {});
        });
      } else {
        state.errorMsg = res.message || '获取详情失败';
        state.isLoading = false;
      }
    } catch (err) {
      if (!state.isActive) return;
      console.error('获取插画详情失败:', err);
      state.errorMsg = '加载失败，请检查网络';
      state.isLoading = false;
    }
  }

  async handleDownload(): Promise<void> {
    const state = this.state;
    if (!state.detail || state.isDownloading) return;
    if (state.currentIndex >= state.pageRegularUrls.length) {
      state.downloadFail = true;
      return;
    }
    state.isDownloading = true;
    state.downloadSuccess = false;
    state.downloadFail = false;
    try {
      const ctx = AppStorage.get<common.UIAbilityContext>('appContext');
      if (!ctx) {
        state.downloadFail = true;
        state.isDownloading = false;
        return;
      }
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.WRITE_IMAGEVIDEO'];
      const result = await atManager.requestPermissionsFromUser(ctx, permissions);
      const granted = result.authResults.every(r => r === 0);
      if (!granted) {
        state.downloadFail = true;
        state.isDownloading = false;
        return;
      }
      const localUrl = state.localImageUrls[state.currentIndex];
      const ok = await PixivService.saveImageToGallery(
        ctx,
        localUrl,
        `illust_${state.detail.illustId}_p${state.currentIndex}.jpg`
      );
      if (ok) {
        state.downloadSuccess = true;
      } else {
        state.downloadFail = true;
      }
    } catch (err) {
      console.error('下载失败:', err);
      state.downloadFail = true;
    }
    state.isDownloading = false;
  }

  async toggleBookmark(): Promise<void> {
    const state = this.state;
    if (state.isBookmarkLoading) return;
    state.isBookmarkLoading = true;
    try {
      if (state.isBookmarked) {
        await PixivService.deleteIllustBookmark(state.illustId);
        state.isBookmarked = false;
      } else {
        await PixivService.addIllustBookmark(state.illustId, 'public', []);
        state.isBookmarked = true;
      }
    } catch (err) {
      promptAction.showToast({ message: '操作失败: ' + String(err) });
    }
    state.isBookmarkLoading = false;
  }

  changePage(index: number): void {
    const state = this.state;
    state.currentIndex = index;
    state.scaleValue = 1;
    state.translateX = 0;
    state.translateY = 0;
    state.downloadSuccess = false;
    state.downloadFail = false;
    const bgUrl = state.localImageUrls[index];
    if (bgUrl && bgUrl !== state.backgroundImageUrl) {
      state.backgroundOpacity = 0;
      state.backgroundImageUrl = bgUrl;
      state.backgroundOpacity = 0.5;
    }
  }

  cancelDownloads(): void {
    PixivService.cancelDownloadGroup(`detail_${this.state.illustId}`);
  }
}
