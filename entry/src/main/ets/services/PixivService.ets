import { PixivApiService, sanitizeNovelBookmark } from './PixivApiService';
import { ImageCacheService } from './ImageCacheService';
import { BookmarkService } from './BookmarkService';
import { Context } from '@kit.AbilityKit';
import {
  UserInfoResponse, IllustBookmarkResponse, NovelBookmarkResponse,
  FollowLatestIllustResponse, FollowLatestNovelResponse,
  DiscoveryIllustsResponse, DiscoveryNovelsResponse,
  SearchIllustResponse, SearchNovelResponse, SearchUserResponse,
  FollowingUserResponse, ProfileAllResponse,
  ProfileIllustsResponse, ProfileNovelsResponse,
  PixivNovel, PixivSeriesResult,
  IllustDetailResponse, AjaxCommentsResponse,
  NovelBookmark,
} from '../models/PixivModels';

export { sanitizeNovelBookmark };

interface CacheCategoryInfo {
  size: number;
  count: number;
}

export class PixivService {
  static get getBaseUrl(): string {
    return PixivApiService.getBaseUrl;
  }

  static getCacheDir(): string {
    return ImageCacheService.getCacheDir();
  }

  static async request<T>(path: string, options?: object): Promise<T> {
    return PixivApiService.request<T>(path, options as never);
  }

  static async getUserInfo(): Promise<UserInfoResponse> {
    return PixivApiService.getUserInfo();
  }

  static async getUserProfile(userId: string): Promise<UserInfoResponse> {
    return PixivApiService.getUserProfile(userId);
  }

  static async getFollowLatestIllusts(page: number = 1, mode: string = 'all'): Promise<FollowLatestIllustResponse> {
    return PixivApiService.getFollowLatestIllusts(page, mode);
  }

  static async getFollowLatestNovels(page: number = 1, mode: string = 'all'): Promise<FollowLatestNovelResponse> {
    return PixivApiService.getFollowLatestNovels(page, mode);
  }

  static async getDiscoveryIllusts(mode: string = 'all', limit: number = 60): Promise<DiscoveryIllustsResponse> {
    return PixivApiService.getDiscoveryIllusts(mode, limit);
  }

  static async getDiscoveryNovels(mode: string = 'all', limit: number = 60): Promise<DiscoveryNovelsResponse> {
    return PixivApiService.getDiscoveryNovels(mode, limit);
  }

  static async getIllustBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<IllustBookmarkResponse> {
    return PixivApiService.getIllustBookmarks(userId, offset, limit, tag, rest);
  }

  static async getNovelBookmarks(userId: string, offset: number = 0, limit: number = 30, tag: string = '', rest: string = 'show'): Promise<NovelBookmarkResponse> {
    return PixivApiService.getNovelBookmarks(userId, offset, limit, tag, rest);
  }

  static async fetchNovelText(novelId: string): Promise<string> {
    return PixivApiService.fetchNovelText(novelId);
  }

  static async searchIllusts(keyword: string, page: number = 1, sMode: string = 's_tag', type: string = 'illust_and_ugoira', order: string = 'date_d', mode: string = 'all'): Promise<SearchIllustResponse> {
    return PixivApiService.searchIllusts(keyword, page, sMode, type, order, mode);
  }

  static async searchNovels(keyword: string, page: number = 1, sMode: string = 's_tag', order: string = 'date_d', mode: string = 'all'): Promise<SearchNovelResponse> {
    return PixivApiService.searchNovels(keyword, page, sMode, order, mode);
  }

  static async searchUsers(keyword: string, page: number = 1): Promise<SearchUserResponse> {
    return PixivApiService.searchUsers(keyword, page);
  }

  static async getFollowingList(userId: string, offset: number = 0, limit: number = 30): Promise<FollowingUserResponse> {
    return PixivApiService.getFollowingList(userId, offset, limit);
  }

  static async getUserProfileAll(userId: string): Promise<ProfileAllResponse> {
    return PixivApiService.getUserProfileAll(userId);
  }

  static async getUserProfileIllusts(userId: string, ids: string[], workCategory: string = 'illustManga'): Promise<ProfileIllustsResponse> {
    return PixivApiService.getUserProfileIllusts(userId, ids, workCategory);
  }

  static async getUserProfileNovels(userId: string, ids: string[]): Promise<ProfileNovelsResponse> {
    return PixivApiService.getUserProfileNovels(userId, ids);
  }

  static async fetchNovelDetail(novelId: string): Promise<PixivNovel> {
    return PixivApiService.fetchNovelDetail(novelId);
  }

  static async fetchSeriesNovels(seriesId: string, page: number = 1): Promise<PixivSeriesResult | null> {
    return PixivApiService.fetchSeriesNovels(seriesId, page);
  }

  static async getIllustDetail(illustId: string): Promise<IllustDetailResponse> {
    return PixivApiService.getIllustDetail(illustId);
  }

  static async getIllustComments(illustId: string, offset: number = 0): Promise<AjaxCommentsResponse> {
    return PixivApiService.getIllustComments(illustId, offset);
  }

  static async getNovelComments(novelId: string, offset: number = 0): Promise<AjaxCommentsResponse> {
    return PixivApiService.getNovelComments(novelId, offset);
  }

  static generatePageUrls(baseUrl: string, pageCount: number): string[] {
    return PixivApiService.generatePageUrls(baseUrl, pageCount);
  }

  static convertToOriginalUrl(regularUrl: string): string {
    return PixivApiService.convertToOriginalUrl(regularUrl);
  }

  static async downloadImage(imageUrl: string, savePath: string, groupId?: string): Promise<boolean> {
    return ImageCacheService.downloadImage(imageUrl, savePath, groupId);
  }

  static async downloadImageDirect(imageUrl: string, savePath: string): Promise<boolean> {
    return ImageCacheService.downloadImageDirect(imageUrl, savePath);
  }

  static async cacheImage(url: string, fileName: string, groupId?: string): Promise<string> {
    return ImageCacheService.cacheImage(url, fileName, groupId);
  }

  static cancelDownloadGroup(groupId: string): void {
    ImageCacheService.cancelDownloadGroup(groupId);
  }

  static detectImageExt(filePath: string): string | null {
    return ImageCacheService.detectImageExt(filePath);
  }

  static async saveImageToGallery(context: Context, source: string, fileName: string): Promise<boolean> {
    return ImageCacheService.saveImageToGallery(context, source, fileName);
  }

  static async getCategoryCacheInfo(prefix: string): Promise<CacheCategoryInfo> {
    return ImageCacheService.getCategoryCacheInfo(prefix);
  }

  static async clearCategoryCache(prefix: string, excludeFileName?: string): Promise<number> {
    return ImageCacheService.clearCategoryCache(prefix, excludeFileName);
  }

  static async clearAllImageCache(excludeAvatarFile?: string): Promise<void> {
    return ImageCacheService.clearAllImageCache(excludeAvatarFile);
  }

  static async addIllustBookmark(illustId: string, restrict: string = 'public', tags: string[] = []): Promise<void> {
    return BookmarkService.addIllustBookmark(illustId, restrict, tags);
  }

  static async deleteIllustBookmark(illustId: string): Promise<void> {
    return BookmarkService.deleteIllustBookmark(illustId);
  }

  static async addNovelBookmark(novelId: string, restrict: string = 'public'): Promise<void> {
    return BookmarkService.addNovelBookmark(novelId, restrict);
  }

  static async deleteNovelBookmark(novelId: string): Promise<void> {
    return BookmarkService.deleteNovelBookmark(novelId);
  }

  static async extractDominantColor(filePath: string): Promise<string> {
    return ImageCacheService.extractDominantColor(filePath);
  }
}
