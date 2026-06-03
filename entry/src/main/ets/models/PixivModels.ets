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

export interface PixivSeriesResult {
  seriesId: string;
  seriesTitle: string;
  seriesCaption?: string;
  authorId: string;
  authorName: string;
  novels: PixivNovel[];
  total: number;
  currentPage: number;
  hasMore: boolean;
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

export function parsePixivNovelFromRaw(raw: RawPixivNovelItem): PixivNovel {
  let order = 0;
  if (raw.seriesContentOrder !== undefined) {
    order = raw.seriesContentOrder;
  } else if (raw.series?.contentOrder !== undefined) {
    order = raw.series.contentOrder;
  } else if (raw.seriesOrder !== undefined) {
    order = raw.seriesOrder;
  }

  let series: PixivSeries | undefined = undefined;
  if (raw.seriesId) {
    series = {
      id: raw.seriesId,
      title: raw.seriesTitle ?? '',
      order: order
    };
  } else if (raw.series) {
    series = {
      id: String(raw.series.id),
      title: raw.seriesTitle ?? '',
      order: raw.series.contentOrder ?? order
    };
  }

  return {
    id: raw.id,
    title: raw.title,
    caption: raw.comment ?? '',
    author: raw.userName,
    authorId: raw.userId,
    coverUrl: raw.url,
    tags: (raw.tags ?? []).map((t: string): PixivTag => ({ name: t })),
    textLength: raw.textCount ?? raw.wordCount ?? 0,
    pageCount: raw.pageCount ?? 1,
    createDate: raw.createDate,
    updateDate: raw.updateDate,
    series: series,
    bookmarkCount: raw.bookmarkCount ?? 0,
    viewCount: raw.viewCount ?? 0,
    commentCount: raw.commentCount ?? 0,
    cacheStatus: CacheStatus.NOT_CACHED
  };
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

  titleTranslated?: string;
  hasTitleTranslation?: boolean;
  fullTextTranslated?: string;
  hasFullTranslation?: boolean;
  translationProgress?: number;
  translationStatus?: 'none' | 'in_progress' | 'completed' | 'failed';
}

export interface CacheStatusDisplay {
  label: string;
  color: Resource;
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
