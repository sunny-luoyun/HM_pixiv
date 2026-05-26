import http from '@ohos.net.http';
import { CookieManager } from './CookieManager';

interface ApiResult<T> {
  error: boolean;
  message?: string;
  body?: T;
}

export interface AppProfileImageUrls {
  medium: string;
}

export interface AppIllustUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: AppProfileImageUrls;
}

export interface AppImageUrls {
  square_medium: string;
  medium: string;
  large: string;
}

export interface AppIllustTag {
  name: string;
}

export interface AppIllust {
  id: number;
  title: string;
  type: string;
  image_urls: AppImageUrls;
  caption: string;
  restrict: number;
  user: AppIllustUser;
  tags: AppIllustTag[];
  tools: string[];
  create_date: string;
  page_count: number;
  width: number;
  height: number;
  total_view: number;
  total_bookmarks: number;
  is_bookmarked: boolean;
  x_restrict: number;
  sanity_level: number;
}

export interface AppUserIllustsResponse {
  illusts: AppIllust[];
  next_url: string | null;
}

export interface AppNovelUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: AppProfileImageUrls;
}

export interface AppNovelSeries {
  id: number;
  title: string;
}

export interface AppNovelImageUrls {
  square_medium: string;
  medium: string;
  large: string;
}

export interface AppNovel {
  id: number;
  title: string;
  caption: string;
  restrict: number;
  x_restrict: number;
  is_original: boolean;
  user: AppNovelUser;
  tags: string[];
  series: AppNovelSeries | null;
  create_date: string;
  upload_date: string;
  page_count: number;
  text_count: number;
  word_count: number;
  reading_time: number;
  bookmark_count: number;
  comment_count: number;
  is_bookmarked: boolean;
  url: string;
  image_urls: AppNovelImageUrls;
}

export interface AppUserNovelsResponse {
  novels: AppNovel[];
  next_url: string | null;
}

interface PostCommentUser {
  id: number;
  name: string;
  account: string;
}

interface PostCommentData {
  id: number;
  comment: string;
  comment_date: string;
  user: PostCommentUser;
}

interface PostCommentResponse {
  comment: PostCommentData;
}

interface QueueTask {
  resolve: (value: object) => void;
  reject: (reason: object) => void;
  execute: () => Promise<object>;
}

interface RemoveIllustBookmarkParams {
  illust_id: number;
}

interface AddNovelBookmarkParams {
  novel_id: number;
  restrict: string;
}

interface RemoveNovelBookmarkParams {
  novel_id: number;
}

interface FollowUserParams {
  user_id: number;
  restrict: string;
}

interface UnfollowUserParams {
  user_id: number;
}

interface PostIllustCommentParams {
  illust_id: number;
  comment: string;
}

interface PostIllustCommentReplyParams {
  illust_id: number;
  comment: string;
  parent_comment_id: number;
}

interface PostNovelCommentParams {
  novel_id: number;
  comment: string;
}

interface PostNovelCommentReplyParams {
  novel_id: number;
  comment: string;
  parent_comment_id: number;
}

interface DeleteCommentParams {
  comment_id: number;
}

interface AddIllustBookmarkParams {
  illust_id: number;
  restrict: string;
}

interface AddIllustBookmarkWithTagsParams {
  illust_id: number;
  restrict: string;
  tags: string[];
}

export class AppApiService {
  private static baseUrl = 'https://app-api.pixiv.net';
  private static queue: Array<QueueTask> = [];
  private static isProcessing = false;
  private static lastRequestTime = 0;
  private static readonly MIN_INTERVAL = 1200;

  private static async enqueue<T>(fn: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      const task: QueueTask = {
        resolve: resolve as (v: object) => void,
        reject: reject as (r: object) => void,
        execute: fn as () => Promise<object>,
      };
      AppApiService.queue.push(task);
      AppApiService.processQueue();
    });
  }

  private static async processQueue(): Promise<void> {
    if (AppApiService.isProcessing) return;
    AppApiService.isProcessing = true;
    while (AppApiService.queue.length > 0) {
      const task = AppApiService.queue.shift()!;
      const now = Date.now();
      const elapsed = now - AppApiService.lastRequestTime;
      const gap = AppApiService.MIN_INTERVAL + Math.floor(Math.random() * 600);
      if (elapsed < gap) {
        await new Promise<void>(r => setTimeout(r, gap - elapsed));
      }
      try {
        const result = await task.execute();
        AppApiService.lastRequestTime = Date.now();
        task.resolve(result);
      } catch (err) {
        task.reject(err as object);
      }
    }
    AppApiService.isProcessing = false;
  }

  private static async request<T>(
    method: http.RequestMethod,
    path: string,
    data?: object,
  ): Promise<T> {
    const cookie = await CookieManager.getFullCookie();

    return AppApiService.enqueue<T>(async () => {
      const httpRequest = http.createHttp();
      try {
        const url = `${AppApiService.baseUrl}${path}`;
        const header: Record<string, string> = {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Referer': 'https://www.pixiv.net/',
          'Accept': 'application/json',
          'Accept-Language': 'zh-CN,zh;q=0.9',
        };
        if (cookie) {
          header['Cookie'] = cookie;
        }
        const options: http.HttpRequestOptions = {
          method,
          header,
          connectTimeout: 3000,
          readTimeout: 3000,
        };

        if (data && method === http.RequestMethod.POST) {
          options.extraData = Object.entries(data as Record<string, string | number | boolean | string[]>)
            .map((entry: [string, string | number | boolean | string[]]) => `${encodeURIComponent(entry[0])}=${encodeURIComponent(String(entry[1]))}`)
            .join('&');
        }

        console.info(`AppApi: ${method} ${url}`);
        const response = await httpRequest.request(url, options);

        if (response.responseCode === 200) {
          return JSON.parse(response.result as string) as T;
        }
        throw new Error(`HTTP ${response.responseCode}: ${response.result}`);
      } finally {
        httpRequest.destroy();
      }
    });
  }

  static async addIllustBookmark(illustId: number, restrict: string = 'public', tags?: string[]): Promise<void> {
    if (tags && tags.length > 0) {
      const data: AddIllustBookmarkWithTagsParams = {
        illust_id: illustId,
        restrict: restrict,
        tags: tags,
      };
      await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v2/illust/bookmark/add', data);
    } else {
      const data: AddIllustBookmarkParams = {
        illust_id: illustId,
        restrict: restrict,
      };
      await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v2/illust/bookmark/add', data);
    }
  }

  static async removeIllustBookmark(illustId: number): Promise<void> {
    const params: RemoveIllustBookmarkParams = {
      illust_id: illustId,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/illust/bookmark/delete', params);
  }

  static async addNovelBookmark(novelId: number, restrict: string = 'public'): Promise<void> {
    const params: AddNovelBookmarkParams = {
      novel_id: novelId,
      restrict: restrict,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v2/novel/bookmark/add', params);
  }

  static async removeNovelBookmark(novelId: number): Promise<void> {
    const params: RemoveNovelBookmarkParams = {
      novel_id: novelId,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/novel/bookmark/delete', params);
  }

  static async followUser(userId: number, restrict: string = 'public'): Promise<void> {
    const params: FollowUserParams = {
      user_id: userId,
      restrict: restrict,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/user/follow/add', params);
  }

  static async unfollowUser(userId: number): Promise<void> {
    const params: UnfollowUserParams = {
      user_id: userId,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/user/follow/delete', params);
  }

  static async postIllustComment(illustId: number, comment: string, parentCommentId?: number): Promise<PostCommentResponse> {
    if (parentCommentId !== undefined) {
      const data: PostIllustCommentReplyParams = {
        illust_id: illustId,
        comment: comment,
        parent_comment_id: parentCommentId,
      };
      return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/illust/comment/add', data);
    } else {
      const data: PostIllustCommentParams = {
        illust_id: illustId,
        comment: comment,
      };
      return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/illust/comment/add', data);
    }
  }

  static async postNovelComment(novelId: number, comment: string, parentCommentId?: number): Promise<PostCommentResponse> {
    if (parentCommentId !== undefined) {
      const data: PostNovelCommentReplyParams = {
        novel_id: novelId,
        comment: comment,
        parent_comment_id: parentCommentId,
      };
      return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/novel/comment/add', data);
    } else {
      const data: PostNovelCommentParams = {
        novel_id: novelId,
        comment: comment,
      };
      return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/novel/comment/add', data);
    }
  }

  static async deleteIllustComment(commentId: number): Promise<void> {
    const params: DeleteCommentParams = {
      comment_id: commentId,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/illust/comment/delete', params);
  }

  static async deleteNovelComment(commentId: number): Promise<void> {
    const params: DeleteCommentParams = {
      comment_id: commentId,
    };
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/novel/comment/delete', params);
  }

  static async getIllustDetail(illustId: number): Promise<object> {
    return AppApiService.request<object>(http.RequestMethod.GET, `/v1/illust/detail?illust_id=${illustId}`);
  }

  static async getUserDetail(userId: number): Promise<object> {
    return AppApiService.request<object>(http.RequestMethod.GET, `/v2/user/detail?user_id=${userId}&filter=for_ios`);
  }

  static async getRecommendedIllusts(): Promise<object> {
    return AppApiService.request<object>(http.RequestMethod.GET,
      '/v1/illust/recommended?include_ranking_illusts=false&include_privacy_policy=true&filter=for_ios');
  }

  static async getUserIllusts(userId: number, offset: number = 0, type: string = 'illust'): Promise<AppUserIllustsResponse> {
    return AppApiService.request<AppUserIllustsResponse>(
      http.RequestMethod.GET,
      `/v1/user/illusts?user_id=${userId}&type=${type}&offset=${offset}`
    );
  }

  static async getUserNovels(userId: number, offset: number = 0): Promise<AppUserNovelsResponse> {
    return AppApiService.request<AppUserNovelsResponse>(
      http.RequestMethod.GET,
      `/v1/user/novels?user_id=${userId}&offset=${offset}`
    );
  }
}
