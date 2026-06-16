// entry/src/main/ets/services/PixivService.ets
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import { CookieManager } from './CookieManager';
import { PixivNovel, CacheStatus, PixivTag, PixivSeries, PixivSeriesResult, parsePixivNovelFromRaw, RawPixivNovelItem } from '../models/PixivModels';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { Context } from '@kit.AbilityKit';
import { ProxyService } from './ProxyService';
import image from '@ohos.multimedia.image';

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

export interface IllustDetailUrls {
  mini: string;
  thumb: string;
  small: string;
  regular: string;
  original: string;
}

export interface IllustTagTranslation {
  en?: string;
  zh?: string;
}

export interface IllustTag {
  tag: string;
  translation?: IllustTagTranslation;
}

export interface IllustDetailTags {
  tags: IllustTag[];
}

export interface IllustDetailBody {
  illustId: string;
  illustTitle: string;
  userId: string;
  userName: string;
  userAccount: string;
  description: string;
  urls: IllustDetailUrls;
  tags: IllustDetailTags;
  width: number;
  height: number;
  pageCount: number;
  bookmarkCount: number;
  likeCount: number;
  viewCount: number;
  createDate: string;
  uploadDate: string;
  profileImageUrl: string;
  bookmarkData?: BookmarkData | null;
}

export interface IllustDetailResponse {
  error: boolean;
  message?: string;
  body: IllustDetailBody;
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
  order?: number;
}

export interface NovelBookmark {
  id: string;
  title: string;
  tags: string[];
  userId: string;
  userName: string;
  bookmarkData: BookmarkData | null;
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
  seriesContentOrder?: number;
  seriesOrder?: number;
  series?: NovelSeries;
  originalWork: boolean;
  aiType: number;
  titleTranslated?: string;
  hasTitleTranslation?: boolean;
}

export function sanitizeNovelBookmark(item: NovelBookmark): NovelBookmark {
  return {
    id: item.id,
    title: item.title ?? '',
    tags: item.tags ?? [],
    userId: item.userId,
    userName: item.userName ?? '',
    bookmarkData: item.bookmarkData,
    profileImageUrl: item.profileImageUrl ?? '',
    createDate: item.createDate ?? '',
    updateDate: item.updateDate ?? '',
    textCount: item.textCount,
    wordCount: item.wordCount,
    characterCount: item.characterCount,
    readingTime: item.readingTime,
    useWordCount: item.useWordCount,
    url: item.url ?? '',
    description: item.description ?? '',
    pageCount: item.pageCount,
    width: item.width,
    height: item.height,
    restrict: item.restrict,
    xRestrict: item.xRestrict,
    sl: item.sl,
    isBookmarkable: item.isBookmarkable,
    isUnlisted: item.isUnlisted,
    isMasked: item.isMasked,
    bookmarkCount: item.bookmarkCount,
    commentCount: item.commentCount,
    markerCount: item.markerCount,
    seriesId: item.seriesId,
    seriesTitle: item.seriesTitle ?? undefined,
    seriesContentOrder: item.seriesContentOrder,
    seriesOrder: item.seriesOrder,
    series: item.series,
    originalWork: item.originalWork,
    aiType: item.aiType,
    titleTranslated: item.titleTranslated,
    hasTitleTranslation: item.hasTitleTranslation,
  };
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
  bookmarkData?: BookmarkData | null;
}

interface DownloadTask {
  resolve: (value: boolean) => void;
  url: string;
  savePath: string;
  groupId?: string;
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

export interface FollowingUserRaw {
  userId: string;
  userName: string;
  profileImageUrl: string;
  userComment: string;
  following: boolean;
  followed: boolean;
  isBlocking: boolean;
  isMypixiv: boolean;
  acceptRequest: boolean;
}

export interface FollowingUserBody {
  total: number;
  users: FollowingUserRaw[];
}

export interface FollowingUserResponse {
  error: boolean;
  body: FollowingUserBody;
}

export interface ProfileIllust {
  id: string;
  title: string;
  illustType: number;
  xRestrict: number;
  url: string;
  tags: string[];
  userId: string;
  userName?: string;
  width: number;
  height: number;
  pageCount: number;
  isBookmarkable: boolean;
  bookmarkData: BookmarkData | null;
  createDate?: string;
  profileImageUrl?: string;
}

export interface ProfileIllustsBody {
  works: Record<string, ProfileIllust>;
}

export interface ProfileIllustsResponse {
  error: boolean;
  body: ProfileIllustsBody;
}

export interface ProfileNovel {
  id: string;
  title: string;
  tags: string[];
  userId: string;
  userName?: string;
  url: string;
  description?: string;
  pageCount: number;
  textCount?: number;
  wordCount?: number;
  readingTime?: number;
  bookmarkCount?: number;
  createDate?: string;
  updateDate?: string;
  profileImageUrl?: string;
  seriesId?: number;
  seriesTitle?: string;
  seriesContentOrder?: number;
  seriesOrder?: number;
  series?: NovelSeries;
}

export interface ProfileNovelsBody {
  works?: Record<string, ProfileNovel>;
}

export interface ProfileNovelsResponse {
  error: boolean;
  body: ProfileNovelsBody;
}

export interface ProfileAllBody {
  illusts: Record<string, null>;
  manga: Record<string, null>;
  novels: Record<string, null>;
}

export interface ProfileAllResponse {
  error: boolean;
  body: ProfileAllBody;
}

interface SeriesInfoBody {
  id: number;
  title: string;
  caption?: string;
  userId: string;
  userName: string;
  publishedContentCount: number;
}

interface SeriesContentPage {
  seriesContents?: RawPixivNovelItem[];
}

interface SeriesContentThumbnails {
  novel?: RawPixivNovelItem[];
}

interface SeriesContentBody {
  page?: SeriesContentPage;
  thumbnails?: SeriesContentThumbnails;
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

interface AddIllustBookmarkBody {
  illust_id: string;
  restrict: number;
  tags: string[];
}

interface DeleteIllustBookmarkBody {
  bookmark_id: string;
}

interface AddNovelBookmarkBody {
  novel_id: string;
  restrict: number;
}

interface DeleteNovelBookmarkBody {
  del: string;
  book_id: string;
}

export class PixivService {
  private static baseUrl = 'https://www.pixiv.net';

  // 下载并发队列（已有）
  private static maxConcurrentDownloads = 3;
  private static activeDownloads = 0;
  private static downloadQueue: Array<DownloadTask> = [];

  // ---- API 请求风控防护 ----
  private static apiQueue: Array<ApiQueueTask> = [];
  private static isProcessingApiQueue = false;
  private static lastApiRequestTime = 0;
  private static readonly MIN_API_INTERVAL = 1200;
  private static readonly MAX_RETRIES = 2;

  // ---- CSRF Token ----
  private static csrfToken: string = '';
  private static csrfTokenExpiry: number = 0;

  private static async fetchCsrfToken(): Promise<string> {
    const now = Date.now();
    if (PixivService.csrfToken && now < PixivService.csrfTokenExpiry) {
      return PixivService.csrfToken;
    }
    try {
      const httpRequest = http.createHttp();
      const url = `${PixivService.baseUrl}/`;
      const cookie = await CookieManager.getFullCookie();
      const header: Record<string, string> = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.pixiv.net/',
      };
      if (cookie) header['Cookie'] = cookie;

      const proxyConfig = await ProxyService.getRequestProxyConfig();

      const resp = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header,
        connectTimeout: 3000,
        readTimeout: 3000,
        usingProxy: proxyConfig || false,
      });
      httpRequest.destroy();

      if (resp.responseCode === 200) {
        const body = String(resp.result);
        let match = body.match(/\\"token\\"\s*:\s*\\"([a-f0-9]+)\\"?/);
        if (!match) {
          match = body.match(/"csrfToken"\s*:\s*"([a-f0-9]{32})"/);
        }
        if (match) {
          PixivService.csrfToken = match[1];
          PixivService.csrfTokenExpiry = now + 3600000;
          return PixivService.csrfToken;
        }
      }
      throw new Error('无法获取 CSRF token');
    } catch (err) {
      console.error('获取 CSRF token 失败:', err);
      throw new Error(`CSRF token 获取失败: ${String(err)}`);
    }
  }

  private static async ensureCsrfToken(): Promise<string> {
    return PixivService.fetchCsrfToken();
  }

  private static async enqueueDownload(url: string, savePath: string, groupId?: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      PixivService.downloadQueue.push({ resolve, url, savePath, groupId });
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
    const cookie = await CookieManager.getFullCookie();
    try {
      const header: Record<string, string> = {
        'Referer': 'https://www.pixiv.net/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      if (cookie) header['Cookie'] = cookie;

      const proxyConfig = await ProxyService.getRequestProxyConfig();

      const httpRequest = http.createHttp();
      try {
        const resp = await httpRequest.request(imageUrl, {
          method: http.RequestMethod.GET,
          header,
          expectDataType: http.HttpDataType.ARRAY_BUFFER,
          usingProxy: proxyConfig || false,
          connectTimeout: 15000,
          readTimeout: 30000,
        });
        if (resp.responseCode !== 200) {
          console.error(`❌ 下载图片失败 HTTP ${resp.responseCode}:`, imageUrl);
          return false;
        }
        const buf = resp.result as ArrayBuffer;
        if (!buf || buf.byteLength === 0) {
          console.error('❌ 下载图片为空:', imageUrl);
          return false;
        }
        const file = fileIo.openSync(savePath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
        fileIo.writeSync(file.fd, buf);
        fileIo.closeSync(file);

        const ext = PixivService.detectImageExt(savePath);
        if (!ext) {
          console.error('❌ 下载的文件不是有效图片，删除:', savePath);
          try { fileIo.unlinkSync(savePath); } catch (_) {}
          return false;
        }
        if (proxyConfig) {
          console.info(`🔗 通过代理 ${proxyConfig.host}:${proxyConfig.port} 下载图片:`, savePath);
        } else {
          console.info('✅ 图片下载完成:', savePath);
        }
        return true;
      } finally {
        httpRequest.destroy();
      }
    } catch (err) {
      console.error('❌ 下载图片失败:', err);
      return false;
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

    const header: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      'Referer': 'https://www.pixiv.net/',
      'Accept': 'application/json',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Accept-Encoding': 'gzip, deflate',
    };

    if (cookie) {
      header['Cookie'] = cookie;
      header['X-Requested-With'] = 'XMLHttpRequest';
    }

    if (!cookie) {
      console.warn('⚠️ 无Cookie，请求可能失败');
    }

    if (options?.header) {
      const customHeaders = options.header as Record<string, string>;
      const keys = Object.keys(customHeaders);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        header[key] = customHeaders[key];
      }
    }

    const proxyConfig = await ProxyService.getRequestProxyConfig();

    const finalOptions: http.HttpRequestOptions = {
      method: options?.method || http.RequestMethod.GET,
      header,
      extraData: options?.extraData,
      connectTimeout: options?.connectTimeout || 10000,
      readTimeout: options?.readTimeout || 10000,
      usingCache: true,
      usingProxy: proxyConfig || false,
    };

    if (proxyConfig) {
      console.info(`🔗 通过代理 ${proxyConfig.host}:${proxyConfig.port} 请求: ${url}`);
    }

    return PixivService.enqueueApiRequest<T>(async () => {
      const httpRequest = http.createHttp();
      try {
        console.info(`Pixiv API 请求: ${url}`);
        const response = await httpRequest.request(url, finalOptions);
        if (response.responseCode === 200) {
          return JSON.parse(response.result as string) as T;
        }
        console.error(`Pixiv API 错误 (${response.responseCode}):`, response.result);
        throw new Error(`HTTP ${response.responseCode}`);
      } catch (err) {
        console.error('Pixiv API 请求异常: ', err);
        throw new Error(`Pixiv API 请求失败: ${String(err)}`);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  static get getBaseUrl(): string {
    return PixivService.baseUrl;
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
    const resp = await PixivService.request<FollowLatestNovelResponse>(path);
    if (!resp.error && resp.body?.thumbnails?.novel) {
      resp.body.thumbnails.novel = resp.body.thumbnails.novel.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  // ---- Discovery 发现页 ----

  static async getDiscoveryIllusts(mode: string = 'all', limit: number = 60): Promise<DiscoveryIllustsResponse> {
    const path = `/ajax/discovery/artworks?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    return PixivService.request<DiscoveryIllustsResponse>(path);
  }

  static async getDiscoveryNovels(mode: string = 'all', limit: number = 60): Promise<DiscoveryNovelsResponse> {
    const path = `/ajax/discovery/novels?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    const resp = await PixivService.request<DiscoveryNovelsResponse>(path);
    if (!resp.error && resp.body?.thumbnails?.novel) {
      resp.body.thumbnails.novel = resp.body.thumbnails.novel.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async getIllustBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<IllustBookmarkResponse> {
    const path = `/ajax/user/${userId}/illusts/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    return PixivService.request<IllustBookmarkResponse>(path);
  }

  static async getNovelBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<NovelBookmarkResponse> {
    const path = `/ajax/user/${userId}/novels/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    const resp = await PixivService.request<NovelBookmarkResponse>(path);
    if (!resp.error && resp.body?.works) {
      resp.body.works = resp.body.works.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async downloadImage(imageUrl: string, savePath: string, groupId?: string): Promise<boolean> {
    return PixivService.enqueueDownload(imageUrl, savePath, groupId);
  }

  static async downloadImageDirect(imageUrl: string, savePath: string): Promise<boolean> {
    return PixivService.doDownload(imageUrl, savePath);
  }

  static async cacheImage(url: string, fileName: string, groupId?: string): Promise<string> {
    const cacheDir: string = PixivService.getCacheDir();
    if (!cacheDir) return '';
    const localPath = cacheDir + '/' + fileName;

    try {
      const file = fileIo.openSync(localPath, fileIo.OpenMode.READ_ONLY);
      fileIo.closeSync(file);
      const ext = PixivService.detectImageExt(localPath);
      if (ext) {
        return 'file://' + localPath;
      }
      fileIo.unlinkSync(localPath);
    } catch (_) {}

    const success = await PixivService.downloadImage(url, localPath, groupId);
    if (!success) {
      try { fileIo.unlinkSync(localPath); } catch (_) {}
      return '';
    }
    return 'file://' + localPath;
  }

  static cancelDownloadGroup(groupId: string): void {
    const remaining: Array<DownloadTask> = [];
    for (const task of PixivService.downloadQueue) {
      if (task.groupId === groupId) {
        task.resolve(false);
      } else {
        remaining.push(task);
      }
    }
    PixivService.downloadQueue = remaining;
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
    const resp = await PixivService.request<SearchNovelResponse>(path);
    if (!resp.error && resp.body?.novel?.data) {
      resp.body.novel.data = resp.body.novel.data.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async searchUsers(keyword: string, page: number = 1): Promise<SearchUserResponse> {
    const encoded = encodeURIComponent(keyword);
    const path = `/ajax/search/users?nick=${encoded}&s_mode=s_usr&i=0&lang=en&p=${page}`;
    return PixivService.request<SearchUserResponse>(path);
  }

  static async getFollowingList(userId: string, offset: number = 0, limit: number = 30): Promise<FollowingUserResponse> {
    const path = `/ajax/user/${userId}/following?offset=${offset}&limit=${limit}&rest=show`;
    return PixivService.request<FollowingUserResponse>(path);
  }

  static async getUserProfileAll(userId: string): Promise<ProfileAllResponse> {
    const path = `/ajax/user/${userId}/profile/all`;
    return PixivService.request<ProfileAllResponse>(path);
  }

  static async getUserProfileIllusts(userId: string, ids: string[], workCategory: string = 'illustManga'): Promise<ProfileIllustsResponse> {
    let path = `/ajax/user/${userId}/profile/illusts?is_first_page=1&work_category=${workCategory}`;
    for (let i = 0; i < ids.length; i++) {
      path += `&ids[]=${ids[i]}`;
    }
    return PixivService.request<ProfileIllustsResponse>(path);
  }

  static async getUserProfileNovels(userId: string, ids: string[]): Promise<ProfileNovelsResponse> {
    let path = `/ajax/user/${userId}/novels?lang=zh`;
    for (let i = 0; i < ids.length; i++) {
      path += `&ids[]=${ids[i]}`;
    }
    return PixivService.request<ProfileNovelsResponse>(path);
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

  static async fetchSeriesNovels(seriesId: string, page: number = 1): Promise<PixivSeriesResult | null> {
    if (!seriesId) return null;
    const limit = 30;
    const lastOrder = (page - 1) * limit;
    try {
      const infoResp = await PixivService.request<NovelAjaxResponse<SeriesInfoBody>>(
        `/ajax/novel/series/${seriesId}`
      );
      if (infoResp.error) {
        console.error(`获取系列信息失败: ${infoResp.message}`);
        return null;
      }
      const info = infoResp.body;
      const contentResp = await PixivService.request<NovelAjaxResponse<SeriesContentBody>>(
        `/ajax/novel/series_content/${seriesId}?limit=${limit}&last_order=${lastOrder}&order_by=asc`
      );
      if (contentResp.error) {
        console.error(`获取系列内容失败: ${contentResp.message}`);
        return null;
      }
      const content = contentResp.body;
      const rawList: RawPixivNovelItem[] =
        content?.page?.seriesContents ??
        content?.thumbnails?.novel ??
        [];
      const novels = rawList.map((raw) => parsePixivNovelFromRaw(raw));
      const total: number = info?.publishedContentCount ?? 0;
      return {
        seriesId: String(info?.id ?? seriesId),
        seriesTitle: info?.title ?? '',
        seriesCaption: info?.caption ?? '',
        authorId: String(info?.userId ?? ''),
        authorName: info?.userName ?? '',
        novels,
        total,
        currentPage: page,
        hasMore: lastOrder + limit < total
      };
    } catch (err) {
      console.error(`获取系列小说失败 seriesId=${seriesId}:`, err);
      return null;
    }
  }

  static async getIllustDetail(illustId: string): Promise<IllustDetailResponse> {
    const path = `/ajax/illust/${illustId}`;
    return PixivService.request<IllustDetailResponse>(path);
  }

  static generatePageUrls(baseUrl: string, pageCount: number): string[] {
    if (!baseUrl || pageCount <= 1) return [baseUrl];
    const urls: string[] = [];
    for (let i = 0; i < pageCount; i++) {
      urls.push(baseUrl.replace(/_p(\d+)/, `_p${i}`));
    }
    return urls;
  }

  static convertToOriginalUrl(regularUrl: string): string {
    if (!regularUrl) return '';
    return regularUrl
      .replace(/\/c\/[^/]+\/img-master\//, '/img-original/')
      .replace('_master1200', '');
  }

  static detectImageExt(filePath: string): string | null {
    try {
      const file = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const buf = new ArrayBuffer(8);
      fileIo.readSync(file.fd, buf);
      fileIo.closeSync(file);
      const arr = new Uint8Array(buf);
      if (arr[0] === 0x89 && arr[1] === 0x50 && arr[2] === 0x4E && arr[3] === 0x47) return 'png';
      if (arr[0] === 0xFF && arr[1] === 0xD8 && arr[2] === 0xFF) return 'jpg';
      if (arr[0] === 0x47 && arr[1] === 0x49 && arr[2] === 0x46) return 'gif';
      if (arr[0] === 0x52 && arr[1] === 0x49 && arr[2] === 0x46 && arr[3] === 0x46) return 'webp';
      if (arr[0] === 0x42 && arr[1] === 0x4D) return 'bmp';
      return null;
    } catch (_) {
      return null;
    }
  }

  static async saveImageToGallery(context: Context, source: string, fileName: string): Promise<boolean> {
    if (!source) {
      console.error('saveImageToGallery: 图片源为空');
      return false;
    }
    let filePath: string;
    if (source.startsWith('file://')) {
      filePath = source.slice(7);
    } else {
      const cachePath = await PixivService.cacheImage(source, fileName);
      if (!cachePath) return false;
      filePath = cachePath.replace('file://', '');
    }
    try {
      const ext = PixivService.detectImageExt(filePath);
      if (!ext) {
        console.error('保存到相册: 下载的文件不是可识别的图片格式');
        return false;
      }
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, ext);
      const dstFile = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
      const srcFile = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(filePath);
      fileIo.copyFileSync(srcFile.fd, dstFile.fd);
      fileIo.closeSync(srcFile);
      fileIo.closeSync(dstFile);
      console.info('✅ 图片已保存到相册:', fileName);
      return true;
    } catch (err) {
      console.error('保存到相册失败:', err);
      return false;
    }
  }

  // ---- 缓存管理 ----

  static getCacheDir(): string {
    const appContext = globalThis.appContext as common.UIAbilityContext;
    if (!appContext) return '';
    const imageDir = appContext.filesDir + '/image_cache';
    try {
      fileIo.mkdirSync(imageDir, true);
    } catch (_) {}
    return imageDir;
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
            totalSize += stat.size as number || 0;
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

  static async deleteSingleNovelCover(novelId: string): Promise<boolean> {
    const cacheDir = PixivService.getCacheDir();
    if (!cacheDir) return false;
    const fileName = `novel_${novelId}.jpg`;
    try {
      fileIo.unlinkSync(`${cacheDir}/${fileName}`);
      return true;
    } catch (_) {
      return false;
    }
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

  // ---- 收藏 (Cookie-based Web API) ----

  static async addIllustBookmark(illustId: string, restrict: string = 'public', tags: string[] = []): Promise<void> {
    const csrfToken = await PixivService.ensureCsrfToken();
    const body: AddIllustBookmarkBody = {
      illust_id: illustId,
      restrict: restrict === 'public' ? 0 : 1,
      tags: tags,
    };
    await PixivService.request<object>('/ajax/illusts/bookmarks/add', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify(body),
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/json',
      },
    });
  }

  static async deleteIllustBookmark(illustId: string): Promise<void> {
    const csrfToken = await PixivService.ensureCsrfToken();
    const detail = await PixivService.getIllustDetail(illustId);
    const bmData = detail.body?.bookmarkData as BookmarkData | undefined;
    if (!bmData) {
      throw new Error('该作品未被收藏');
    }
    const formData = `bookmark_id=${encodeURIComponent(bmData.id)}`;
    await PixivService.request<object>('/ajax/illusts/bookmarks/delete', {
      method: http.RequestMethod.POST,
      extraData: formData,
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
  }

  static async addNovelBookmark(novelId: string, restrict: string = 'public'): Promise<void> {
    const csrfToken = await PixivService.ensureCsrfToken();
    const body: AddNovelBookmarkBody = {
      novel_id: novelId,
      restrict: restrict === 'public' ? 0 : 1,
    };
    await PixivService.request<object>('/ajax/novels/bookmarks/add', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify(body),
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/json',
      },
    });
  }

  static async deleteNovelBookmark(novelId: string): Promise<void> {
    const csrfToken = await PixivService.ensureCsrfToken();
    const detail = await PixivService.request<NovelAjaxResponse<NovelDetailBody>>(`/ajax/novel/${novelId}`);
    const bmData = detail.body?.bookmarkData as BookmarkData | undefined;
    if (!bmData) {
      throw new Error('该作品未被收藏');
    }
    const formData = `del=1&book_id=${encodeURIComponent(bmData.id)}`;
    await PixivService.request<object>('/ajax/novels/bookmarks/delete', {
      method: http.RequestMethod.POST,
      extraData: formData,
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
  }

  static async extractDominantColor(filePath: string): Promise<string> {
    try {
      const imageSource = image.createImageSource(filePath);
      const pixelMap = await imageSource.createPixelMap({
        desiredSize: { width: 8, height: 8 }
      });
      const buffer = new ArrayBuffer(8 * 8 * 4);
      await pixelMap.readPixelsToBuffer(buffer);

      const pixels = new Uint8Array(buffer);
      let r = 0, g = 0, b = 0, count = 0;
      for (let i = 0; i < pixels.length; i += 4) {
        r += pixels[i];
        g += pixels[i + 1];
        b += pixels[i + 2];
        count++;
      }
      r = Math.round(r / count);
      g = Math.round(g / count);
      b = Math.round(b / count);

      imageSource.release();
      const toHex = (n: number): string => n.toString(16).padStart(2, '0');
      return `#${toHex(r)}${toHex(g)}${toHex(b)}`;
    } catch (err) {
      console.error('提取图片主色失败:', err);
      return '';
    }
  }
}