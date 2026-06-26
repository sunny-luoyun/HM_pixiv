import { CacheStatus, PixivTag, PixivSeries, RawPixivNovelItem, BookmarkData, getCacheStatusDisplay } from './CommonModels';
import { AppProfileImageUrls } from './IllustModels';

export interface NovelSeries {
  id: number;
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
  bookmarkData?: BookmarkData | null;
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

export interface NovelBookmark {
  id: string;
  title: string;
  tags: string[];
  userId: string;
  userName: string;
  bookmarkData: BookmarkData | null;
  profileImageUrl: string;
  createDate: string;
  updateDate: string;
  textCount: number;
  wordCount: number;
  characterCount: number;
  readingTime: number;
  useWordCount: boolean;
  url: string;
  description: string;
  pageCount: number;
  width: number;
  height: number;
  restrict: number;
  xRestrict: number;
  sl: number;
  isBookmarkable: boolean;
  isUnlisted: boolean;
  isMasked: boolean;
  bookmarkCount: number;
  commentCount: number;
  markerCount: number;
  seriesId?: number;
  seriesTitle?: string;
  seriesContentOrder?: number;
  seriesOrder?: number;
  series?: NovelSeries;
  originalWork: boolean;
  aiType: number;
  titleTranslated?: string;
  hasTitleTranslation?: boolean;
}

export interface NovelBookmarkResponseBody {
  works: NovelBookmark[];
  total: number;
}

export interface NovelBookmarkResponse {
  error: boolean;
  body: NovelBookmarkResponseBody;
}

export interface FollowLatestNovelResponse {
  error: boolean;
  body: FollowLatestNovelBody;
}

export interface FollowLatestNovelBody {
  thumbnails: FollowLatestNovelThumbnails;
  total: number;
  page: number;
  pages: number;
}

export interface FollowLatestNovelThumbnails {
  novel: NovelBookmark[];
}

export interface DiscoveryNovelsResponse {
  error: boolean;
  body: DiscoveryNovelsBody;
}

export interface DiscoveryNovelsBody {
  thumbnails: DiscoveryThumbnailsNovel;
}

export interface DiscoveryThumbnailsNovel {
  novel: NovelBookmark[];
}

export interface SearchNovelData {
  data: NovelBookmark[];
  total: number;
}

export interface SearchNovelBody {
  novel: SearchNovelData;
}

export interface SearchNovelResponse {
  error: boolean;
  body: SearchNovelBody;
}

export interface ProfileNovel {
  id: string;
  title: string;
  tags: string[];
  userId: string;
  userName?: string;
  url: string;
  description?: string;
  pageCount: number;
  textCount?: number;
  wordCount?: number;
  readingTime?: number;
  bookmarkCount?: number;
  createDate?: string;
  updateDate?: string;
  profileImageUrl?: string;
  seriesId?: number;
  seriesTitle?: string;
  seriesContentOrder?: number;
  seriesOrder?: number;
  series?: NovelSeries;
}

export interface ProfileNovelsBody {
  works?: Record<string, ProfileNovel>;
}

export interface ProfileNovelsResponse {
  error: boolean;
  body: ProfileNovelsBody;
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
    bookmarkData: raw.bookmarkData ?? undefined,
    bookmarkCount: raw.bookmarkCount ?? 0,
    viewCount: raw.viewCount ?? 0,
    commentCount: raw.commentCount ?? 0,
    cacheStatus: CacheStatus.NOT_CACHED
  };
}
