import http from '@ohos.net.http';
import { TokenStorage } from '../common/utils/TokenStorage';

interface ApiResult<T> {
  error: boolean;
  message?: string;
  body?: T;
}

interface PostCommentResponse {
  comment: {
    id: number;
    comment: string;
    comment_date: string;
    user: {
      id: number;
      name: string;
      account: string;
    };
  };
}

export class AppApiService {
  private static baseUrl = 'https://app-api.pixiv.net';
  private static queue: Array<{
    resolve: (value: object) => void;
    reject: (reason: object) => void;
    execute: () => Promise<object>;
  }> = [];
  private static isProcessing = false;
  private static lastRequestTime = 0;
  private static readonly MIN_INTERVAL = 1200;

  private static async enqueue<T>(fn: () => Promise<T>): Promise<T> {
    return new Promise<T>((resolve, reject) => {
      AppApiService.queue.push({
        resolve: resolve as (v: object) => void,
        reject: reject as (r: object) => void,
        execute: fn as () => Promise<object>,
      });
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
    data?: Record<string, string | number | boolean>,
  ): Promise<T> {
    const accessToken = await TokenStorage.getAccessToken();
    if (!accessToken) {
      throw new Error('No access token available');
    }

    return AppApiService.enqueue<T>(async () => {
      const httpRequest = http.createHttp();
      try {
        const url = `${AppApiService.baseUrl}${path}`;
        const options: http.HttpRequestOptions = {
          method,
          header: {
            'Authorization': `Bearer ${accessToken}`,
            'User-Agent': 'PixivIOSApp/7.13.4 (iOS 16.0.3; iPhone13,3)',
            'App-OS': 'ios',
            'App-OS-Version': '16.0.3',
            'Accept': 'application/json',
            'Accept-Language': 'zh-CN,zh;q=0.9',
          },
          connectTimeout: 10000,
          readTimeout: 10000,
        };

        if (data && method === http.RequestMethod.POST) {
          options.extraData = Object.entries(data)
            .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
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
    const data: Record<string, string | number | boolean> = {
      illust_id: illustId,
      restrict: restrict,
    };
    if (tags && tags.length > 0) {
      data['tags'] = tags;
    }
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v2/illust/bookmark/add', data);
  }

  static async removeIllustBookmark(illustId: number): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/illust/bookmark/delete', {
      illust_id: illustId,
    });
  }

  static async addNovelBookmark(novelId: number, restrict: string = 'public'): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v2/novel/bookmark/add', {
      novel_id: novelId,
      restrict: restrict,
    });
  }

  static async removeNovelBookmark(novelId: number): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/novel/bookmark/delete', {
      novel_id: novelId,
    });
  }

  static async followUser(userId: number, restrict: string = 'public'): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/user/follow/add', {
      user_id: userId,
      restrict: restrict,
    });
  }

  static async unfollowUser(userId: number): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/user/follow/delete', {
      user_id: userId,
    });
  }

  static async postIllustComment(illustId: number, comment: string, parentCommentId?: number): Promise<PostCommentResponse> {
    const data: Record<string, string | number | boolean> = {
      illust_id: illustId,
      comment: comment,
    };
    if (parentCommentId !== undefined) {
      data['parent_comment_id'] = parentCommentId;
    }
    return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/illust/comment/add', data);
  }

  static async postNovelComment(novelId: number, comment: string, parentCommentId?: number): Promise<PostCommentResponse> {
    const data: Record<string, string | number | boolean> = {
      novel_id: novelId,
      comment: comment,
    };
    if (parentCommentId !== undefined) {
      data['parent_comment_id'] = parentCommentId;
    }
    return AppApiService.request<PostCommentResponse>(http.RequestMethod.POST, '/v1/novel/comment/add', data);
  }

  static async deleteIllustComment(commentId: number): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/illust/comment/delete', {
      comment_id: commentId,
    });
  }

  static async deleteNovelComment(commentId: number): Promise<void> {
    await AppApiService.request<ApiResult<null>>(http.RequestMethod.POST, '/v1/novel/comment/delete', {
      comment_id: commentId,
    });
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
}
