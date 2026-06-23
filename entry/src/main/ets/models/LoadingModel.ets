/**
 * 统一加载状态枚举
 */
export enum LoadingStatus {
  IDLE = 'idle',
  LOADING = 'loading',
  SUCCESS = 'success',
  FAILED = 'failed',
  EMPTY = 'empty'
}

/**
 * 分页加载状态
 */
export enum PageStatus {
  IDLE = 'idle',
  LOADING = 'loading',
  SUCCESS = 'success',
  LOADING_MORE = 'loadingMore',
  FAILED = 'failed',
  NO_MORE = 'noMore'
}

/**
 * 统一加载状态模型，使用 @Observed 保证响应式
 */
@Observed
export class LoadingModel {
  status: LoadingStatus = LoadingStatus.IDLE;
  errorMessage: string = '';

  get isLoading(): boolean {
    return this.status === LoadingStatus.LOADING;
  }

  get isSuccess(): boolean {
    return this.status === LoadingStatus.SUCCESS;
  }

  get isFailed(): boolean {
    return this.status === LoadingStatus.FAILED;
  }

  get isEmpty(): boolean {
    return this.status === LoadingStatus.EMPTY;
  }

  startLoading(): void {
    this.status = LoadingStatus.LOADING;
    this.errorMessage = '';
  }

  setSuccess(): void {
    this.status = LoadingStatus.SUCCESS;
  }

  setFailed(message: string): void {
    this.status = LoadingStatus.FAILED;
    this.errorMessage = message;
  }

  setEmpty(): void {
    this.status = LoadingStatus.EMPTY;
  }

  reset(): void {
    this.status = LoadingStatus.IDLE;
    this.errorMessage = '';
  }
}

/**
 * 分页加载状态模型
 */
@Observed
export class PageLoadModel {
  status: PageStatus = PageStatus.IDLE;
  page: number = 1;
  pages: number = 1;
  hasMore: boolean = true;
  errorMessage: string = '';

  get isLoading(): boolean {
    return this.status === PageStatus.LOADING;
  }

  get isLoadingMore(): boolean {
    return this.status === PageStatus.LOADING_MORE;
  }

  get isFailed(): boolean {
    return this.status === PageStatus.FAILED;
  }

  get isNoMore(): boolean {
    return this.status === PageStatus.NO_MORE;
  }

  startLoading(page: number = 1): void {
    this.status = page === 1 ? PageStatus.LOADING : PageStatus.LOADING_MORE;
    this.page = page;
    this.errorMessage = '';
  }

  setSuccess(page: number, totalPages: number): void {
    this.status = PageStatus.SUCCESS;
    this.page = page;
    this.pages = totalPages;
    this.hasMore = page < totalPages;
  }

  setFailed(message: string): void {
    this.status = PageStatus.FAILED;
    this.errorMessage = message;
  }

  setNoMore(): void {
    this.status = PageStatus.NO_MORE;
    this.hasMore = false;
  }

  reset(): void {
    this.status = PageStatus.IDLE;
    this.page = 1;
    this.pages = 1;
    this.hasMore = true;
    this.errorMessage = '';
  }
}
