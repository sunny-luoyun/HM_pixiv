import http from '@ohos.net.http';
import { CookieManager } from './CookieManager';
import {
  PixivNovel, CacheStatus, PixivTag, PixivSeries, PixivSeriesResult,
  parsePixivNovelFromRaw, RawPixivNovelItem,
  NovelBookmark, BookmarkData, IllustBookmark, NovelSeries,
  UserInfoBody, UserInfoResponse,
  IllustDetailBody, IllustDetailResponse,
  AjaxComment, AjaxCommentUser, AjaxCommentsBody, AjaxCommentsResponse,
  IllustBookmarkResponseBody, IllustBookmarkResponse,
  NovelBookmarkResponseBody, NovelBookmarkResponse,
  FollowLatestIllustResponse, FollowLatestNovelResponse,
  DiscoveryIllustsResponse, DiscoveryNovelsResponse,
  SearchIllustData, SearchIllustBody, SearchIllustResponse,
  SearchNovelData, SearchNovelBody, SearchNovelResponse,
  UserSearchResult, SearchUserPage, SearchUserBody, SearchUserResponse,
  FollowingUserRaw, FollowingUserBody, FollowingUserResponse,
  ProfileIllust, ProfileIllustsBody, ProfileIllustsResponse,
  ProfileNovel, ProfileNovelsBody, ProfileNovelsResponse,
  ProfileAllBody, ProfileAllResponse,
  RankingResponse, NovelRankingResponse,
  UgoiraMetaResponse,
} from '../models/PixivModels';
import { ApiConfig } from '../common/constants/ApiConfig';
import { ProxyService } from './ProxyService';
import { SearchCondition, searchConditionToQueryString } from '../models/SearchModels';

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

export class PixivApiService {
  private static baseUrl = ApiConfig.PIXIV_WEB;

  private static apiQueue: Array<ApiQueueTask> = [];
  private static isProcessingApiQueue = false;
  private static lastApiRequestTime = 0;
  private static readonly MIN_API_INTERVAL = 800;
  private static readonly MAX_RETRIES = 2;

  private static csrfToken: string = '';
  private static csrfTokenExpiry: number = 0;

  private static async fetchCsrfToken(): Promise<string> {
    const now = Date.now();
    if (PixivApiService.csrfToken && now < PixivApiService.csrfTokenExpiry) {
      return PixivApiService.csrfToken;
    }
    try {
      const httpRequest = http.createHttp();
      const url = `${PixivApiService.baseUrl}/`;
      const cookie = await CookieManager.getFullCookie();
      const header: Record<string, string> = {
        'User-Agent': ApiConfig.USER_AGENT,
        'Referer': ApiConfig.REFERER,
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
          PixivApiService.csrfToken = match[1];
          PixivApiService.csrfTokenExpiry = now + 3600000;
          return PixivApiService.csrfToken;
        }
      }
      throw new Error('无法获取 CSRF token');
    } catch (err) {
      console.error('获取 CSRF token 失败:', err);
      throw new Error(`CSRF token 获取失败: ${String(err)}`);
    }
  }

  static async ensureCsrfToken(): Promise<string> {
    return PixivApiService.fetchCsrfToken();
  }

  private static enqueueApiRequest<T>(execute: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      PixivApiService.apiQueue.push({
        resolve: resolve as (value: object) => void,
        reject: reject as (reason: object) => void,
        execute: execute as () => Promise<object>
      });
      PixivApiService.processApiQueue();
    });
  }

  private static async processApiQueue(): Promise<void> {
    if (PixivApiService.isProcessingApiQueue) return;
    PixivApiService.isProcessingApiQueue = true;

    while (PixivApiService.apiQueue.length > 0) {
      const task = PixivApiService.apiQueue.shift()!;

      const now = Date.now();
      const elapsed = now - PixivApiService.lastApiRequestTime;
      const gap = PixivApiService.MIN_API_INTERVAL + Math.floor(Math.random() * 600);
      if (elapsed < gap) {
        await new Promise<void>(resolve => setTimeout(resolve, gap - elapsed));
      }

      let lastError: Error | null = null;
      for (let attempt = 0; attempt <= PixivApiService.MAX_RETRIES; attempt++) {
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
          PixivApiService.lastApiRequestTime = Date.now();
          task.resolve(result);
          lastError = null;
          break;
        } catch (err) {
          lastError = err as Error;
          const msg = String(err);
          const isRetryable = /HTTP (429|5\d{2})/.test(msg);
          if (!isRetryable) break;
          console.warn(`⏳ 请求限流/服务器错误，准备重试: ${msg}`);
        }
      }

      if (lastError) {
        task.reject(lastError);
      }
    }

    PixivApiService.isProcessingApiQueue = false;
  }

  static async request<T>(path: string, options?: http.HttpRequestOptions): Promise<T> {
    const cookie = await CookieManager.getFullCookie();
    const url = `${PixivApiService.baseUrl}${path}`;

    const header: Record<string, string> = {
      'User-Agent': ApiConfig.USER_AGENT,
      'Referer': ApiConfig.REFERER,
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

    return PixivApiService.enqueueApiRequest<T>(async () => {
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
    return PixivApiService.baseUrl;
  }

  static async getUserInfo(): Promise<UserInfoResponse> {
    return PixivApiService.request<UserInfoResponse>('/ajax/user/me');
  }

  static async getUserProfile(userId: string): Promise<UserInfoResponse> {
    return PixivApiService.request<UserInfoResponse>(`/ajax/user/${userId}`);
  }

  static async getFollowLatestIllusts(page: number = 1, mode: string = 'all'): Promise<FollowLatestIllustResponse> {
    const path = `/ajax/follow_latest/illust?mode=${mode}&p=${page}`;
    return PixivApiService.request<FollowLatestIllustResponse>(path);
  }

  static async getFollowLatestNovels(page: number = 1, mode: string = 'all'): Promise<FollowLatestNovelResponse> {
    const path = `/ajax/follow_latest/novel?mode=${mode}&p=${page}`;
    const resp = await PixivApiService.request<FollowLatestNovelResponse>(path);
    if (!resp.error && resp.body?.thumbnails?.novel) {
      resp.body.thumbnails.novel = resp.body.thumbnails.novel.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async getDiscoveryIllusts(mode: string = 'all', limit: number = 60): Promise<DiscoveryIllustsResponse> {
    const path = `/ajax/discovery/artworks?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    return PixivApiService.request<DiscoveryIllustsResponse>(path);
  }

  static async getDiscoveryNovels(mode: string = 'all', limit: number = 60): Promise<DiscoveryNovelsResponse> {
    const path = `/ajax/discovery/novels?mode=${mode}&limit=${limit}&t=${Date.now()}`;
    const resp = await PixivApiService.request<DiscoveryNovelsResponse>(path);
    if (!resp.error && resp.body?.thumbnails?.novel) {
      resp.body.thumbnails.novel = resp.body.thumbnails.novel.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async getIllustBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<IllustBookmarkResponse> {
    const path = `/ajax/user/${userId}/illusts/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    return PixivApiService.request<IllustBookmarkResponse>(path);
  }

  static async getNovelBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<NovelBookmarkResponse> {
    const path = `/ajax/user/${userId}/novels/bookmarks?tag=${encodeURIComponent(tag)}&offset=${offset}&limit=${limit}&rest=${rest}`;
    const resp = await PixivApiService.request<NovelBookmarkResponse>(path);
    if (!resp.error && resp.body?.works) {
      resp.body.works = resp.body.works.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async fetchNovelText(novelId: string): Promise<string> {
    const path = `/ajax/novel/${novelId}`;
    try {
      const resp = await PixivApiService.request<NovelAjaxResponse<NovelDetailBody>>(path);
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

  static async searchIllusts(keyword: string, page: number = 1, sMode: string = 's_tag', type: string = 'illust_and_ugoira', order: string = 'date_d', mode: string = 'all', condition?: SearchCondition): Promise<SearchIllustResponse> {
    const encoded = encodeURIComponent(keyword);
    let path = `/ajax/search/illustrations/${encoded}?word=${encoded}&type=${type}&order=${order}&mode=${mode}&s_mode=${sMode}&p=${page}`;
    if (condition !== undefined) {
      path += searchConditionToQueryString(condition);
    }
    console.info(`[PixivApi] searchIllusts path: ${path}`);
    const resp = await PixivApiService.request<SearchIllustResponse>(path);
    if (!resp.error && resp.body !== undefined) {
      if (resp.body.illust === undefined || resp.body.illust.data === undefined) {
        if (resp.body.illustManga !== undefined) {
          const adapted: SearchIllustBody = {
            illust: {
              data: resp.body.illustManga.data,
              total: resp.body.illustManga.total
            },
            illustManga: resp.body.illustManga
          };
          return { error: false, body: adapted };
        }
      }
    }
    return resp;
  }

  static async searchNovels(keyword: string, page: number = 1, sMode: string = 's_tag', order: string = 'date_d', mode: string = 'all', condition?: SearchCondition): Promise<SearchNovelResponse> {
    const encoded = encodeURIComponent(keyword);
    let path = `/ajax/search/novels/${encoded}?word=${encoded}&order=${order}&mode=${mode}&s_mode=${sMode}&include_translated_tags=1&p=${page}&type=novel&lang=zh`;
    if (condition !== undefined) {
      path += searchConditionToQueryString(condition);
    }
    console.info(`[PixivApi] searchNovels path: ${path}`);
    const resp = await PixivApiService.request<SearchNovelResponse>(path);
    if (!resp.error && resp.body?.novel?.data) {
      resp.body.novel.data = resp.body.novel.data.map(sanitizeNovelBookmark);
    }
    return resp;
  }

  static async searchUsers(keyword: string, page: number = 1, sMode: string = 's_usr'): Promise<SearchUserResponse> {
    const encoded = encodeURIComponent(keyword);
    const path = `/ajax/search/users?nick=${encoded}&s_mode=${sMode}&i=0&lang=en&p=${page}`;
    return PixivApiService.request<SearchUserResponse>(path);
  }

  static async getFollowingList(userId: string, offset: number = 0, limit: number = 30): Promise<FollowingUserResponse> {
    const path = `/ajax/user/${userId}/following?offset=${offset}&limit=${limit}&rest=show`;
    return PixivApiService.request<FollowingUserResponse>(path);
  }

  static async getUserProfileAll(userId: string): Promise<ProfileAllResponse> {
    const path = `/ajax/user/${userId}/profile/all`;
    return PixivApiService.request<ProfileAllResponse>(path);
  }

  static async getUserProfileIllusts(userId: string, ids: string[], workCategory: string = 'illustManga'): Promise<ProfileIllustsResponse> {
    let path = `/ajax/user/${userId}/profile/illusts?is_first_page=1&work_category=${workCategory}`;
    for (let i = 0; i < ids.length; i++) {
      path += `&ids[]=${ids[i]}`;
    }
    return PixivApiService.request<ProfileIllustsResponse>(path);
  }

  static async getUserProfileNovels(userId: string, ids: string[]): Promise<ProfileNovelsResponse> {
    let path = `/ajax/user/${userId}/novels?lang=zh`;
    for (let i = 0; i < ids.length; i++) {
      path += `&ids[]=${ids[i]}`;
    }
    return PixivApiService.request<ProfileNovelsResponse>(path);
  }

  static async fetchNovelDetail(novelId: string): Promise<PixivNovel> {
    const path = `/ajax/novel/${novelId}`;
    const resp = await PixivApiService.request<NovelAjaxResponse<NovelDetailBody>>(path);
    if (resp.error) {
      throw new Error(resp.message || '获取小说详情失败');
    }
    const b = resp.body;
    const novel: PixivNovel = {
      id: b.id,
      title: b.title,
      caption: b.description ?? '',
      author: b.userName,
      authorId: b.userId,
      coverUrl: b.coverUrl ?? '',
      tags: (b.tags?.tags ?? []).map((t: TagItem): PixivTag => ({
        name: t.tag,
        translation: t.translation?.zh ?? t.translation?.en ?? undefined
      })),
      textLength: b.wordCount ?? 0,
      pageCount: b.pageCount ?? 1,
      createDate: b.createDate ?? '',
      updateDate: b.uploadDate ?? '',
      bookmarkCount: b.bookmarkCount ?? 0,
      viewCount: b.viewCount ?? 0,
      commentCount: b.commentCount ?? 0,
      cacheStatus: CacheStatus.NOT_CACHED,
      fullText: b.content ?? undefined
    };
    return novel;
  }

  static async fetchSeriesNovels(seriesId: string, page: number = 1): Promise<PixivSeriesResult | null> {
    if (!seriesId) return null;
    const limit = 30;
    const lastOrder = (page - 1) * limit;
    try {
      const infoResp = await PixivApiService.request<NovelAjaxResponse<SeriesInfoBody>>(
        `/ajax/novel/series/${seriesId}`
      );
      if (infoResp.error) {
        console.error(`获取系列信息失败: ${infoResp.message}`);
        return null;
      }
      const info = infoResp.body;
      const contentResp = await PixivApiService.request<NovelAjaxResponse<SeriesContentBody>>(
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
    return PixivApiService.request<IllustDetailResponse>(path);
  }

  static async getUgoiraMeta(illustId: string): Promise<UgoiraMetaResponse> {
    const path = `/ajax/illust/${illustId}/ugoira_meta`;
    return PixivApiService.request<UgoiraMetaResponse>(path);
  }

  static async getIllustComments(illustId: string, offset: number = 0): Promise<AjaxCommentsResponse> {
    const path = `/ajax/illusts/comments/roots?illust_id=${illustId}&offset=${offset}&limit=20`;
    return PixivApiService.request<AjaxCommentsResponse>(path);
  }

  static async getNovelComments(novelId: string, offset: number = 0): Promise<AjaxCommentsResponse> {
    const path = `/ajax/novels/comments/roots?novel_id=${novelId}&offset=${offset}&limit=20`;
    return PixivApiService.request<AjaxCommentsResponse>(path);
  }

  static async getIllustCommentReplies(commentId: string, page: number = 1): Promise<AjaxCommentsResponse> {
    const path = `/ajax/illusts/comments/replies?comment_id=${commentId}&page=${page}`;
    return PixivApiService.request<AjaxCommentsResponse>(path);
  }

  static async getNovelCommentReplies(commentId: string, page: number = 1): Promise<AjaxCommentsResponse> {
    const path = `/ajax/novels/comments/replies?comment_id=${commentId}&page=${page}`;
    return PixivApiService.request<AjaxCommentsResponse>(path);
  }

  static async getRanking(mode: string = 'daily', page: number = 1, content: string = 'all'): Promise<RankingResponse> {
    const path = `/ranking.php?mode=${mode}&content=${content}&p=${page}&format=json`;
    return PixivApiService.request<RankingResponse>(path);
  }

  static async getNovelRanking(mode: string = 'daily', page: number = 1): Promise<NovelRankingResponse> {
    const path = `/ajax/ranking/novel?mode=${mode}&p=${page}`;
    return PixivApiService.request<NovelRankingResponse>(path);
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
}
