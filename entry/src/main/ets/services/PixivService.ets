// entry/src/main/ets/services/PixivService.ets
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { CookieManager } from './CookieManager';
import { PixivNovel, CacheStatus, PixivTag, PixivSeries } from '../models/PixivModels';
export interface UserInfoBody {
  userId?: string;
  name: string;
  image?: string;
  imageBig?: string;
}

interface RequestHeaders {
  'Cookie': string;
  'User-Agent': string;
  'Referer': string;
  'Accept': string;
  'X-Csrf-Token'?: string;
}

export interface UserInfoResponse {
  error: boolean;
  body?: UserInfoBody;
}

export interface BookmarkData {
  id: string;
  private: boolean;
  userId: string;
}

export interface IllustBookmark {
  id: string;
  title: string;
  illustType: number;
  url: string;
  tags: string[];
  userId: string;
  userName: string;
  width: number;
  height: number;
  pageCount: number;
  bookmarkData: BookmarkData;
  profileImageUrl: string;
  createDate: string;
}

export interface IllustBookmarkResponseBody {
  works: IllustBookmark[];
  total: number;
}

export interface IllustBookmarkResponse {
  error: boolean;
  body: IllustBookmarkResponseBody;
}

export interface NovelSeries {
  id: number;
  title: string;
}

export interface NovelBookmark {
  id: string;
  title: string;
  tags: string[];
  userId: string;
  userName: string;
  bookmarkData: BookmarkData;
  profileImageUrl: string;
  createDate: string;
  updateDate: string;
  textCount: number;
  wordCount: number;
  characterCount: number;
  readingTime: number;
  useWordCount: boolean;
  url: string;
  description: string;
  pageCount: number;
  width: number;
  height: number;
  restrict: number;
  xRestrict: number;
  sl: number;
  isBookmarkable: boolean;
  isUnlisted: boolean;
  isMasked: boolean;
  bookmarkCount: number;
  commentCount: number;
  markerCount: number;
  seriesId?: number;
  seriesTitle?: string;
  series?: NovelSeries;
  originalWork: boolean;
  aiType: number;
}

export interface NovelBookmarkResponseBody {
  works: NovelBookmark[];
  total: number;
}

export interface NovelBookmarkResponse {
  error: boolean;
  body: NovelBookmarkResponseBody;
}

interface NovelAjaxResponse<T> {
  error: boolean;
  message: string;
  body: T;
}

interface TagTranslation {
  en?: string;
  zh?: string;
}

interface TagItem {
  tag: string;
  translation?: TagTranslation;
}

interface TagsWrapper {
  tags: TagItem[];
}

interface NovelDetailBody {
  id: string;
  title: string;
  content: string;
  description: string;
  userId: string;
  userName: string;
  tags: TagsWrapper;
  createDate: string;
  uploadDate: string;
  bookmarkCount: number;
  viewCount: number;
  commentCount: number;
  pageCount: number;
  wordCount: number;
  coverUrl: string;
}

interface DownloadTask {
  resolve: (value: boolean) => void;
  url: string;
  savePath: string;
}

interface FollowLatestIllustThumbnails {
  illust: IllustBookmark[];
}

interface FollowLatestIllustBody {
  thumbnails: FollowLatestIllustThumbnails;
  total: number;
  page: number;
  pages: number;
}

export interface FollowLatestIllustResponse {
  error: boolean;
  body: FollowLatestIllustBody;
}

interface FollowLatestNovelThumbnails {
  novel: NovelBookmark[];
}

interface FollowLatestNovelBody {
  thumbnails: FollowLatestNovelThumbnails;
  total: number;
  page: number;
  pages: number;
}

export interface FollowLatestNovelResponse {
  error: boolean;
  body: FollowLatestNovelBody;
}

// ---- Discovery 发现页 ----

interface DiscoveryThumbnailsIllust {
  illust: IllustBookmark[];
}

interface DiscoveryIllustsBody {
  thumbnails: DiscoveryThumbnailsIllust;
}

export interface DiscoveryIllustsResponse {
  error: boolean;
  body: DiscoveryIllustsBody;
}

interface DiscoveryThumbnailsNovel {
  novel: NovelBookmark[];
}

interface DiscoveryNovelsBody {
  thumbnails: DiscoveryThumbnailsNovel;
}

export interface DiscoveryNovelsResponse {
  error: boolean;
  body: DiscoveryNovelsBody;
}

// ---- Search ----

export interface SearchIllustData {
  data: IllustBookmark[];
  total: number;
}

export interface SearchIllustBody {
  illust: SearchIllustData;
}

export interface SearchIllustResponse {
  error: boolean;
  body: SearchIllustBody;
}

export interface SearchNovelData {
  data: NovelBookmark[];
  total: number;
}

export interface SearchNovelBody {
  novel: SearchNovelData;
}

export interface SearchNovelResponse {
  error: boolean;
  body: SearchNovelBody;
}

export interface UserSearchResult {
  userId: string;
  name: string;
  image: string;
  imageBig: string;
  comment: string;
  premium: boolean;
  isFollowed: boolean;
  following: number;
}

export interface SearchUserPage {
  userIds: number[];
  total: number;
}

export interface SearchUserBody {
  users: UserSearchResult[];
  page: SearchUserPage;
}

export interface SearchUserResponse {
  error: boolean;
  body: SearchUserBody;
}

interface ApiQueueTask {
  resolve: (value: object) => void;
  reject: (reason: object) => void;
  execute: () => Promise<object>;
}

interface CacheCategoryInfo {
  size: number;
  count: number;
}

interface AllImageCacheInfo {
  illust: CacheCategoryInfo;
  novel: CacheCategoryInfo;
  avatar: CacheCategoryInfo;
}

export class PixivService {
  private static baseUrl = 'https://www.pixiv.net';

  // 下载并发队列（已有）
  private static maxConcurrentDownloads = 3;
  private static activeDownloads = 0;
  private static downloadQueue: Array<DownloadTask> = [];

  // ---- API 请求风控防护 ----
  // 请求队列（串行执行，一次只发一个请求）
  private static apiQueue: Array<ApiQueueTask> = [];
  private static isProcessingApiQueue = false;
  private static lastApiRequestTime = 0;
  // 最小请求间隔（单位 ms），在此基础增加随机 jitter
  private static readonly MIN_API_INTERVAL = 1200;
  // 最大重试次数（额外尝试，不含首次）
  private static readonly MAX_RETRIES = 2;

  private static async enqueueDownload(url: string, savePath: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      PixivService.downloadQueue.push({ resolve, url, savePath });
      PixivService.processQueue();
    });
  }

  private static processQueue() {
    while (PixivService.activeDownloads < PixivService.maxConcurrentDownloads && PixivService.downloadQueue.length > 0) {
      const task = PixivService.downloadQueue.shift()!;
      PixivService.activeDownloads++;
      PixivService.doDownload(task.url, task.savePath).then((result) => {
        task.resolve(result);
        PixivService.activeDownloads--;
        PixivService.processQueue();
      });
    }
  }

  private static async doDownload(imageUrl: string, savePath: string): Promise<boolean> {
    const httpRequest = http.createHttp();
    try {
      const cookie = await CookieManager.getFullCookie();
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://www.pixiv.net/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Cookie': cookie
        },
        expectDataType: http.HttpDataType.ARRAY_BUFFER
      });
      if (response.responseCode === 200) {
        const file = fileIo.openSync(savePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
        fileIo.writeSync(file.fd, response.result as ArrayBuffer);
        fileIo.closeSync(file);
        console.info('✅ 图片已缓存到:', savePath);
        return true;
      }
      console.error('下载图片失败, 状态码:', response.responseCode);
      return false;
    } catch (err) {
      console.error('下载图片异常:', err);
      return false;
    } finally {
      httpRequest.destroy();
    }
  }

  // ---- 请求入队 + 串行调度 ----
  private static enqueueApiRequest<T>(execute: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      PixivService.apiQueue.push({
        resolve: resolve as (value: object) => void,
        reject: reject as (reason: object) => void,
        execute: execute as () => Promise<object>
      });
      PixivService.processApiQueue();
    });
  }

  // 串行处理队列，每次请求间加随机延迟
  private static async processApiQueue(): Promise<void> {
    if (PixivService.isProcessingApiQueue) return;
    PixivService.isProcessingApiQueue = true;

    while (PixivService.apiQueue.length > 0) {
      const task = PixivService.apiQueue.shift()!;

      // 确保最小请求间隔（基础间隔 + 0~600ms jitter）
      const now = Date.now();
      const elapsed = now - PixivService.lastApiRequestTime;
      const gap = PixivService.MIN_API_INTERVAL + Math.floor(Math.random() * 600);
      if (elapsed < gap) {
        await new Promise<void>(resolve => setTimeout(resolve, gap - elapsed));
      }

      // 执行请求 + 指数退避重试
      let lastError: Error | null = null;
      for (let attempt = 0; attempt <= PixivService.MAX_RETRIES; attempt++) {
        if (attempt > 0) {
          const backoff = Math.min(
            2000 * Math.pow(2, attempt - 1) + Math.floor(Math.random() * 1000),
            15000
          );
          console.warn(`⏳ 第${attempt + 1}次重试，等待${backoff}ms...`);
          await new Promise<void>(resolve => setTimeout(resolve, backoff));
        }
        try {
          const result = await task.execute();
          PixivService.lastApiRequestTime = Date.now();
          task.resolve(result);
          lastError = null;
          break;
        } catch (err) {
          lastError = err as Error;
          const msg = String(err);
          // 仅在限流(429)或服务端错误(5xx)时重试
          const isRetryable = /HTTP (429|5\d{2})/.test(msg);
          if (!isRetryable) break;
          console.warn(`⏳ 请求限流/服务器错误，准备重试: ${msg}`);
        }
      }

      if (lastError) {
        task.reject(lastError);
      }
    }

    PixivService.isProcessingApiQueue = false;
  }

  static async request<T>(path: string, options?: http.HttpRequestOptions): Promise<T> {
    const cookie = await CookieManager.getFullCookie();
    const url = `${PixivService.baseUrl}${path}`;

    const finalOptions: http.HttpRequestOptions = {
      method: options?.method || http.RequestMethod.GET,
      header: {
        'Cookie': cookie,
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.pixiv.net/',
        'Accept': 'application/json',
        'X-Requested-With': 'XMLHttpRequest',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'Accept-Encoding': 'gzip, deflate'
      },
      connectTimeout: 10000,
      readTimeout: 10000,
      usingCache: true
    };

    // 将实际 HTTP 调用包装后入队，由队列控制并发与间隔
    return PixivService.enqueueApiRequest<T>(async () => {
      const httpRequest = http.createHttp();
      try {
        console.info(`Pixiv API 请求: ${url}`);
        const response = await httpRequest.request(url, finalOptions);
        if (response.responseCode === 200) {
          return JSON.parse(response.result as string) as T;
        } else {
          console.error(`Pixiv API 错误 (${response.responseCode}):`, response.result);
          throw new Error(`HTTP ${response.responseCode}`);
        }
      } catch (err) {
        console.error('Pixiv API 请求异常: ', err);
        throw new Error(`Pixiv API 请求失败: ${String(err)}`);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  static async getUserInfo(): Promise<UserInfoResponse> {
    return PixivService.request<UserInfoResponse>('/ajax/user/me');
  }

  static async getUserProfile(userId: string): Promise<UserInfoResponse> {
    return PixivService.request<UserInfoResponse>(`/ajax/user/${userId}`);
  }

  static async fetchUserName(): Promise<string> {
    const userInfo: UserInfoResponse = await PixivService.getUserInfo();
    if (userInfo && !userInfo.error && userInfo.body?.name) {
      return userInfo.body.name;
    }
    throw new Error('无法获取用户名');
  }

  static async getFollowLatestIllusts(page: number = 1, mode: string = 'all'): Promise<FollowLatestIllustResponse> {
    const path = `/ajax/follow_latest/illust?mode=${mode}&p=${page}`;
    return PixivService.request<FollowLatestIllustResponse>(path);
  }

  static async getFollowLatestNovels(page: number = 1, mode: string = 'all'): Promise<FollowLatestNovelResponse> {
    const path = `/ajax/follow_latest/novel?mode=${mode}&p=${page}`;
    return PixivService.request<FollowLatestNovelResponse>(path);
  }

  // ---- Discovery 发现页 ----

  static async getDiscoveryIllusts(mode: string = 'all', limit: number = 60): Promise<DiscoveryIllustsResponse> {
    const path = `/ajax/discovery/artworks?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    return PixivService.request<DiscoveryIllustsResponse>(path);
  }

  static async getDiscoveryNovels(mode: string = 'all', limit: number = 60): Promise<DiscoveryNovelsResponse> {
    const path = `/ajax/discovery/novels?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    return PixivService.request<DiscoveryNovelsResponse>(path);
  }

  static async getIllustBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<IllustBookmarkResponse> {
    const path = `/ajax/user/${userId}/illusts/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    return PixivService.request<IllustBookmarkResponse>(path);
  }

  static async getNovelBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<NovelBookmarkResponse> {
    const path = `/ajax/user/${userId}/novels/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    return PixivService.request<NovelBookmarkResponse>(path);
  }

  static async downloadImage(imageUrl: string, savePath: string): Promise<boolean> {
    return PixivService.enqueueDownload(imageUrl, savePath);
  }

  static async downloadImageDirect(imageUrl: string, savePath: string): Promise<boolean> {
    return PixivService.doDownload(imageUrl, savePath);
  }

  static async cacheImage(url: string, fileName: string): Promise<string> {
    const appContext = globalThis.appContext as common.UIAbilityContext;
    if (!appContext) return '';
    const cacheDir: string = appContext.cacheDir;
    const localPath = cacheDir + '/' + fileName;

    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      fileIo.closeSync(file);
      return 'file://' + localPath;
    } catch (_) {}

    const success = await PixivService.downloadImage(url, localPath);
    return success ? 'file://' + localPath : '';
  }

  static async fetchNovelText(novelId: string): Promise<string> {
    const path = `/ajax/novel/${novelId}`;
    try {
      const resp = await PixivService.request<NovelAjaxResponse<NovelDetailBody>>(path);
      if (resp.error) {
        throw new Error(resp.message || '获取小说正文失败');
      }
      const content = resp.body?.content ?? '';
      if (!content) {
        throw new Error('正文内容为空');
      }
      return content;
    } catch (err) {
      console.error(`获取小说正文失败 id=${novelId}:`, err);
      throw err as Error;
    }
  }

  // ---- Search ----

  static async searchIllusts(keyword: string, page: number = 1, sMode: string = 's_tag', type: string = 'illust_and_ugoira'): Promise<SearchIllustResponse> {
    const encoded = encodeURIComponent(keyword);
    const path = `/ajax/search/illustrations/${encoded}?word=${encoded}&type=${type}&order=date_d&mode=all&s_mode=${sMode}&p=${page}`;
    return PixivService.request<SearchIllustResponse>(path);
  }

  static async searchNovels(keyword: string, page: number = 1, sMode: string = 's_tag'): Promise<SearchNovelResponse> {
    const encoded = encodeURIComponent(keyword);
    const path = `/ajax/search/novels/${encoded}?word=${encoded}&order=date_d&mode=all&s_mode=${sMode}&include_translated_tags=1&p=${page}&type=novel&lang=zh`;
    return PixivService.request<SearchNovelResponse>(path);
  }

  static async searchUsers(keyword: string, page: number = 1): Promise<SearchUserResponse> {
    const encoded = encodeURIComponent(keyword);
    const path = `/ajax/search/users?nick=${encoded}&s_mode=s_usr&i=0&lang=en&p=${page}`;
    return PixivService.request<SearchUserResponse>(path);
  }

  static async fetchNovelDetail(novelId: string): Promise<PixivNovel> {
    const path = `/ajax/novel/${novelId}`;
    const resp = await PixivService.request<NovelAjaxResponse<NovelDetailBody>>(path);
    if (resp.error) {
      throw new Error(resp.message || '获取小说详情失败');
    }
    const b = resp.body;
    const novel: PixivNovel = {
      id:            b.id,
      title:         b.title,
      caption:       b.description ?? '',
      author:        b.userName,
      authorId:      b.userId,
      coverUrl:      b.coverUrl ?? '',
      tags:          (b.tags?.tags ?? []).map((t: TagItem): PixivTag => ({
        name: t.tag,
        translation: t.translation?.zh ?? t.translation?.en ?? undefined
      })),
      textLength:    b.wordCount ?? 0,
      pageCount:     b.pageCount ?? 1,
      createDate:    b.createDate ?? '',
      updateDate:    b.uploadDate ?? '',
      bookmarkCount: b.bookmarkCount ?? 0,
      viewCount:     b.viewCount ?? 0,
      commentCount:  b.commentCount ?? 0,
      cacheStatus:   CacheStatus.NOT_CACHED,
      fullText:      b.content ?? undefined
    };
    return novel;
  }

  // ---- 缓存管理 ----

  static getCacheDir(): string {
    const appContext = globalThis.appContext as common.UIAbilityContext;
    if (!appContext) return '';
    return appContext.cacheDir;
  }

  static async getCategoryCacheInfo(prefix: string): Promise<CacheCategoryInfo> {
    const cacheDir = PixivService.getCacheDir();
    if (!cacheDir) return { size: 0, count: 0 };

    let totalSize = 0;
    let totalCount = 0;

    try {
      const files = fileIo.listFileSync(cacheDir);
      for (const fileName of files) {
        if (fileName.startsWith(prefix)) {
          try {
            const stat = fileIo.statSync(cacheDir + '/' + fileName);
            totalSize += stat.size;
            totalCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    return { size: totalSize, count: totalCount };
  }

  static async clearCategoryCache(prefix: string): Promise<number> {
    const cacheDir = PixivService.getCacheDir();
    if (!cacheDir) return 0;

    let deletedCount = 0;

    try {
      const files = fileIo.listFileSync(cacheDir);
      for (const fileName of files) {
        if (fileName.startsWith(prefix)) {
          try {
            fileIo.unlinkSync(cacheDir + '/' + fileName);
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    return deletedCount;
  }

  static async getAllImageCacheInfo(): Promise<AllImageCacheInfo> {
    const illust = await PixivService.getCategoryCacheInfo('illust_');
    const novel = await PixivService.getCategoryCacheInfo('novel_');
    const user = await PixivService.getCategoryCacheInfo('user_');
    const avatar = await PixivService.getCategoryCacheInfo('avatar_');
    const result: AllImageCacheInfo = {
      illust,
      novel,
      avatar: { size: user.size + avatar.size, count: user.count + avatar.count }
    };
    return result;
  }

  static async clearAllImageCache(): Promise<void> {
    await PixivService.clearCategoryCache('illust_');
    await PixivService.clearCategoryCache('novel_');
    await PixivService.clearCategoryCache('user_');
    await PixivService.clearCategoryCache('avatar_');
  }
}