export enum CacheStatus {
  NOT_CACHED = 'not_cached',
  CACHING = 'caching',
  CACHED = 'cached',
  CACHE_FAIL = 'cache_fail'
}

export interface BookmarkData {
  id: string;
  private: boolean;
  userId: string;
}

export interface PixivTag {
  name: string;
  translation?: string;
}

export interface PixivSeries {
  id: string;
  title: string;
  order?: number;
}

export interface RawPixivSeries {
  id?: number;
  contentOrder?: number;
  viewableType?: number;
}

export interface RawPixivNovelItem {
  id: string;
  title: string;
  comment: string;
  userName: string;
  userId: string;
  url: string;
  tags: string[];
  textCount: number;
  wordCount?: number;
  pageCount: number;
  createDate: string;
  updateDate: string;
  seriesId?: string;
  seriesTitle?: string;
  seriesOrder?: number;
  seriesContentOrder?: number;
  series?: RawPixivSeries;
  bookmarkCount: number;
  viewCount: number;
  commentCount: number;
}

export interface CacheStatusDisplay {
  label: string;
  color: Resource;
}

export interface BlockedAuthor {
  authorId: string;
  authorName: string;
  blockedAt: string;
}

export interface BlockedSeries {
  seriesId: string;
  seriesTitle: string;
  authorId: string;
  authorName: string;
  blockedAt: string;
}

export interface BlockedSeriesTitle {
  title: string;
  blockedAt: string;
}

export function getCacheStatusDisplay(status: CacheStatus): CacheStatusDisplay {
  switch (status) {
    case CacheStatus.CACHED:
      return { label: '已缓存', color: $r('app.color.success') };
    case CacheStatus.CACHING:
      return { label: '缓存中', color: $r('app.color.warning') };
    case CacheStatus.CACHE_FAIL:
      return { label: '缓存失败', color: $r('app.color.danger') };
    case CacheStatus.NOT_CACHED:
    default:
      return { label: '未缓存', color: $r('app.color.text_secondary') };
  }
}
