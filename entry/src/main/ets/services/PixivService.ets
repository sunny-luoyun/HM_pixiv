// entry/src/main/ets/services/PixivService.ets
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import common from '@ohos.app.ability.common';
import request from '@ohos.request';
import { CookieManager } from './CookieManager';
import { OAuthService } from './OAuthService';
import { PixivNovel, CacheStatus, PixivTag, PixivSeries, PixivSeriesResult, parsePixivNovelFromRaw, RawPixivNovelItem } from '../models/PixivModels';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import { Context } from '@kit.AbilityKit';
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
    const context = globalThis.appContext as common.UIAbilityContext;
    if (!context) return false;
    const cookie = await CookieManager.getFullCookie();
    const accessToken = await CookieManager.getAccessToken();
    try {
      const header: Record<string, string> = {
        'Referer': 'https://www.pixiv.net/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      };
      if (cookie) header['Cookie'] = cookie;
      if (accessToken) header['Authorization'] = `Bearer ${accessToken}`;

      const downloadTask = await request.downloadFile(context, {
        url: imageUrl,
        filePath: savePath,
        header,
      });
      return new Promise<boolean>((resolve) => {
        downloadTask.on('complete', () => {
          console.info('✅ 图片下载完成:', savePath);
          resolve(true);
        });
        downloadTask.on('fail', (err: number) => {
          console.error('下载图片失败:', err);
          resolve(false);
        });
      });
    } catch (err) {
      console.error('下载图片启动失败:', err);
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
    const accessToken = await CookieManager.getAccessToken();
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
    if (accessToken) {
      header['Authorization'] = `Bearer ${accessToken}`;
    }

    if (!cookie && !accessToken) {
      console.warn('⚠️ 无认证信息(Cookie/Token)，请求可能失败');
    }

    const finalOptions: http.HttpRequestOptions = {
      method: options?.method || http.RequestMethod.GET,
      header,
      extraData: options?.extraData,
      connectTimeout: 10000,
      readTimeout: 10000,
      usingCache: true,
    };

    return PixivService.enqueueApiRequest<T>(async () => {
      const httpRequest = http.createHttp();
      try {
        console.info(`Pixiv API 请求: ${url}`);
        const response = await httpRequest.request(url, finalOptions);
        if (response.responseCode === 200) {
          return JSON.parse(response.result as string) as T;
        }
        if (response.responseCode === 400 || response.responseCode === 401) {
          const body = String(response.result);
          if (body.includes('Error occurred at the OAuth process') ||
              body.includes('Invalid refresh token') ||
              response.responseCode === 401) {
            console.warn('⚠️ Token可能已过期，尝试刷新...');
            const refreshed = await PixivService.tryRefreshToken();
            if (refreshed) {
              const newToken = await CookieManager.getAccessToken();
              if (newToken) {
                header['Authorization'] = `Bearer ${newToken}`;
                const retryResponse = await httpRequest.request(url, {
                  method: finalOptions.method,
                  header: header,
                  extraData: finalOptions.extraData,
                  connectTimeout: finalOptions.connectTimeout,
                  readTimeout: finalOptions.readTimeout,
                  usingCache: finalOptions.usingCache,
                });
                if (retryResponse.responseCode === 200) {
                  return JSON.parse(retryResponse.result as string) as T;
                }
              }
            }
          }
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

  private static async tryRefreshToken(): Promise<boolean> {
    try {
      const refreshToken = await CookieManager.getRefreshToken();
      if (!refreshToken) return false;
      const tokenResponse = await OAuthService.refreshAccessToken(refreshToken);
      await CookieManager.saveTokens({
        access_token: tokenResponse.access_token,
        refresh_token: tokenResponse.refresh_token,
        expires_in: tokenResponse.expires_in,
        obtained_at: Date.now(),
      });
      if (tokenResponse.user) {
        const userId = String(tokenResponse.user.id);
        const userName = tokenResponse.user.name;
        await CookieManager.saveUserInfo(userId, userName);
      }
      console.info('✅ Token 自动刷新成功');
      return true;
    } catch (err) {
      const msg = String(err);
      if (msg.includes('INVALID_REFRESH_TOKEN')) {
        console.warn('⚠️ refresh_token 已失效，需要重新登录');
      } else {
        console.error('❌ Token 自动刷新失败:', err);
      }
      return false;
    }
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

  static async saveImageToGallery(context: Context, imageUrl: string, fileName: string): Promise<boolean> {
    const cachePath = await PixivService.cacheImage(imageUrl, fileName);
    if (!cachePath) return false;
    const filePath = cachePath.replace('file://', '');
    try {
      const helper = photoAccessHelper.getPhotoAccessHelper(context);
      const uri = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const dstFile = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
      const srcFile = fileIo.openSync(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = fileIo.statSync(filePath);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(srcFile.fd, buf);
      fileIo.writeSync(dstFile.fd, buf);
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
}