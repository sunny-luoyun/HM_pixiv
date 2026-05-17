export enum CacheStatus {
  NOT_CACHED = 'not_cached',
  CACHING    = 'caching',
  CACHED     = 'cached',
  CACHE_FAIL = 'cache_fail'
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

export interface PixivNovel {
  id: string;
  title: string;
  caption: string;
  author: string;
  authorId: string;
  coverUrl: string;
  tags: PixivTag[];
  textLength: number;
  pageCount: number;
  createDate: string;
  updateDate: string;
  series?: PixivSeries;
  bookmarkCount: number;
  viewCount: number;
  commentCount: number;
  cacheStatus: CacheStatus;
  cachedAt?: string;
  fullText?: string;
}

export interface CacheStatusDisplay {
  label: string;
  color: string;
}

export function getCacheStatusDisplay(status: CacheStatus): CacheStatusDisplay {
  switch (status) {
    case CacheStatus.CACHED:
      return { label: '已缓存', color: '#52C41A' };
    case CacheStatus.CACHING:
      return { label: '缓存中', color: '#FAAD14' };
    case CacheStatus.CACHE_FAIL:
      return { label: '缓存失败', color: '#FF4D4F' };
    case CacheStatus.NOT_CACHED:
    default:
      return { label: '未缓存', color: '#999999' };
  }
}

export function formatTextLength(len: number): string {
  if (len >= 10000) {
    return (len / 10000).toFixed(1) + '万字';
  }
  if (len >= 1000) {
    return (len / 1000).toFixed(1) + '千字';
  }
  return len + '字';
}

export function formatPixivDate(isoDate: string): string {
  if (!isoDate) return '';
  return isoDate.substring(0, 10).replace(/-/g, '/');
}

export function isReadableOffline(novel: PixivNovel): boolean {
  return novel.cacheStatus === CacheStatus.CACHED;
}
