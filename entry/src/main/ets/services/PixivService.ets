// entry/src/main/ets/services/PixivService.ets
import http from '@ohos.net.http';
import fileIo from '@ohos.file.fs';
import { CookieManager } from './CookieManager';
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

export class PixivService {
  private static baseUrl = 'https://www.pixiv.net';

  static async request<T>(path: string, options?: http.HttpRequestOptions): Promise<T> {
    const cookie = await CookieManager.getFullCookie();
    const url = `${PixivService.baseUrl}${path}`;

    const httpRequest = http.createHttp();

    // 更精细的 headers
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
      connectTimeout: 10000,  // 增加超时时间
      readTimeout: 10000,
      usingCache: true
    };

    try {
      console.info(`Pixiv API 请求: ${url}`);
      console.info(`请求 Cookie 长度: ${cookie.length}`);  // 调试
      console.info(`请求 Cookie 内容: ${cookie.substring(0, 100)}...`);  // 调试前100字符

      const response = await httpRequest.request(url, finalOptions);

      console.info(`Pixiv API 响应状态: ${response.responseCode}`);
      console.info(`Pixiv API 响应体: ${response.result}`);  // 完整响应用于调试

      if (response.responseCode === 200) {
        const result = JSON.parse(response.result as string) as T;
        console.info(`解析后结果:`, result);
        return result;
      } else {
        console.error(`Pixiv API 错误 (${response.responseCode}):`, response.result);
        throw new Error(`HTTP ${response.responseCode}`);
      }
    } catch (err) {
      console.error('Pixiv API 请求异常: ', err);
      console.error(`异常类型: ${typeof err}, 异常信息: ${String(err)}`);
      throw new Error(`Pixiv API 请求失败: ${String(err)}`);
    } finally {
      httpRequest.destroy();
    }
  }

  static async getUserInfo(): Promise<UserInfoResponse> {
    return PixivService.request<UserInfoResponse>('/ajax/user/me');
  }

  static async fetchUserName(): Promise<string> {
    const userInfo: UserInfoResponse = await PixivService.getUserInfo();
    if (userInfo && !userInfo.error && userInfo.body?.name) {
      return userInfo.body.name;
    }
    throw new Error('无法获取用户名');
  }

  static async downloadImage(imageUrl: string, savePath: string): Promise<boolean> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(imageUrl, {
        method: http.RequestMethod.GET,
        header: {
          'Referer': 'https://www.pixiv.net/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
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
}