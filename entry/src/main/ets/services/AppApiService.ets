import http from '@ohos.net.http';
import { PixivAuth } from './PixivAuth';
import { ProxyService } from './ProxyService';
import { ApiConfig } from '../common/constants/ApiConfig';
import {
  IllustCommentsResponse, AppUserIllustsResponse, AppUserNovelsResponse,
} from '../models/PixivModels';

interface ApiResult<T> {
  error: boolean;
  message?: string;
  body?: T;
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
  private static baseUrl = ApiConfig.PIXIV_APP;
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
    isRetry: boolean = false,
  ): Promise<T> {
    const auth = PixivAuth.getInstance();

    if (!auth.getAuthHeader() && !isRetry) {
      throw new Error('未登录');
    }

    return AppApiService.enqueue<T>(async () => {
      return AppApiService.executeRequest<T>(method, path, data, auth, false);
    });
  }

  private static async executeRequest<T>(
    method: http.RequestMethod,
    path: string,
    data: object | undefined,
    auth: PixivAuth,
    isRetry: boolean,
  ): Promise<T> {
    const httpRequest = http.createHttp();
    try {
      const url = `${AppApiService.baseUrl}${path}`;
      const authHeader = auth.getAuthHeader();
      const header: Record<string, string> = {
        'User-Agent': ApiConfig.USER_AGENT_APP,
        'Accept': 'application/json',
        'Accept-Language': 'zh-CN,zh;q=0.9',
        'App-OS': 'android',
        'App-OS-Version': '11.0',
        'App-Version': '5.0.234',
      };
      if (authHeader) {
        header['Authorization'] = authHeader;
      }

      const proxyConfig = await ProxyService.getRequestProxyConfig();

      const options: http.HttpRequestOptions = {
        method,
        header,
        connectTimeout: 6000,
        readTimeout: 6000,
        usingProxy: proxyConfig || false,
      };

      if (data && method === http.RequestMethod.POST) {
        header['Content-Type'] = 'application/x-www-form-urlencoded';
        options.extraData = Object.entries(data as Record<string, string | number | boolean | string[]>)
          .map((entry: [string, string | number | boolean | string[]]) => `${encodeURIComponent(entry[0])}=${encodeURIComponent(String(entry[1]))}`)
          .join('&');
      }

      const response = await httpRequest.request(url, options);

      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T;
      }

      if (!isRetry) {
        const bodyStr = response.result as string || '';
        const shouldRefresh = response.responseCode === 401 ||
          (response.responseCode === 400 && bodyStr.includes('invalid_grant'));

        if (shouldRefresh) {
          console.info('AppApi: Token 可能已过期，尝试刷新...');
          const refreshed = await auth.refreshAccessToken();
          if (refreshed) {
            console.info('AppApi: Token 刷新成功，重试请求');
            return AppApiService.executeRequest<T>(method, path, data, auth, true);
          }
          throw new Error('认证已过期，请重新登录');
        }
      }

      console.error(`AppApi 请求失败 [${method} ${path}]: HTTP ${response.responseCode}, body: ${response.result}`);
      throw new Error(`HTTP ${response.responseCode}`);
    } finally {
      httpRequest.destroy();
    }
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

  static async getIllustComments(illustId: number, offset: number = 0): Promise<IllustCommentsResponse> {
    const path = `/v1/illust/comments?illust_id=${illustId}&offset=${offset}&include_total_comments=true`;
    return AppApiService.request<IllustCommentsResponse>(http.RequestMethod.GET, path);
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
