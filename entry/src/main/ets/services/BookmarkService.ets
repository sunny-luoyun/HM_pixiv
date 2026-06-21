import http from '@ohos.net.http';
import { PixivApiService } from './PixivApiService';
import { BookmarkData } from '../models/PixivModels';

interface AddIllustBookmarkBody {
  illust_id: string;
  restrict: number;
  tags: string[];
}

interface AddNovelBookmarkBody {
  novel_id: string;
  restrict: number;
}

interface NovelAjaxResponse<T> {
  error: boolean;
  message: string;
  body: T;
}

interface NovelDetailBody {
  id: string;
  title: string;
  content: string;
  description: string;
  userId: string;
  userName: string;
  bookmarkData?: BookmarkData | null;
}

export class BookmarkService {
  static async addIllustBookmark(illustId: string, restrict: string = 'public', tags: string[] = []): Promise<void> {
    const csrfToken = await PixivApiService.ensureCsrfToken();
    const body: AddIllustBookmarkBody = {
      illust_id: illustId,
      restrict: restrict === 'public' ? 0 : 1,
      tags: tags,
    };
    await PixivApiService.request<object>('/ajax/illusts/bookmarks/add', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify(body),
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/json',
      },
    });
  }

  static async deleteIllustBookmark(illustId: string): Promise<void> {
    const csrfToken = await PixivApiService.ensureCsrfToken();
    const detail = await PixivApiService.getIllustDetail(illustId);
    const bmData = detail.body?.bookmarkData as BookmarkData | undefined;
    if (!bmData) {
      throw new Error('该作品未被收藏');
    }
    const formData = `bookmark_id=${encodeURIComponent(bmData.id)}`;
    await PixivApiService.request<object>('/ajax/illusts/bookmarks/delete', {
      method: http.RequestMethod.POST,
      extraData: formData,
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
  }

  static async addNovelBookmark(novelId: string, restrict: string = 'public'): Promise<void> {
    const csrfToken = await PixivApiService.ensureCsrfToken();
    const body: AddNovelBookmarkBody = {
      novel_id: novelId,
      restrict: restrict === 'public' ? 0 : 1,
    };
    await PixivApiService.request<object>('/ajax/novels/bookmarks/add', {
      method: http.RequestMethod.POST,
      extraData: JSON.stringify(body),
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/json',
      },
    });
  }

  static async deleteNovelBookmark(novelId: string): Promise<void> {
    const csrfToken = await PixivApiService.ensureCsrfToken();
    const detail = await PixivApiService.request<NovelAjaxResponse<NovelDetailBody>>(`/ajax/novel/${novelId}`);
    const bmData = detail.body?.bookmarkData as BookmarkData | undefined;
    if (!bmData) {
      throw new Error('该作品未被收藏');
    }
    const formData = `del=1&book_id=${encodeURIComponent(bmData.id)}`;
    await PixivApiService.request<object>('/ajax/novels/bookmarks/delete', {
      method: http.RequestMethod.POST,
      extraData: formData,
      header: {
        'X-Csrf-Token': csrfToken,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    });
  }
}
