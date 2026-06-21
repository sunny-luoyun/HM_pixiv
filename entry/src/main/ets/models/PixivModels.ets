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

export interface IllustTagTranslation {
  en?: string;
  zh?: string;
}

export interface IllustTag {
  tag: string;
  translation?: IllustTagTranslation;
}

export interface IllustDetailTags {
  tags: IllustTag[];
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

export interface UserInfoBody {
  userId?: string;
  name: string;
  image?: string;
  imageBig?: string;
}

export interface UserInfoResponse {
  error: boolean;
  body?: UserInfoBody;
}

export interface IllustDetailUrls {
  mini: string;
  thumb: string;
  small: string;
  regular: string;
  original: string;
}

export interface IllustDetailBody {
  illustId: string;
  illustTitle: string;
  userId: string;
  userName: string;
  userAccount: string;
  description: string;
  urls: IllustDetailUrls;
  tags: IllustDetailTags;
  width: number;
  height: number;
  pageCount: number;
  bookmarkCount: number;
  likeCount: number;
  viewCount: number;
  commentCount: number;
  createDate: string;
  uploadDate: string;
  profileImageUrl: string;
  bookmarkData?: BookmarkData | null;
}

export interface IllustDetailResponse {
  error: boolean;
  message?: string;
  body: IllustDetailBody;
}

export interface AjaxCommentUser {
  id: string;
  name: string;
  account: string;
  img: string;
}

export interface AjaxComment {
  id: string;
  comment: string;
  date: string;
  userId: string;
  userName: string;
  userAccount: string;
  img: string;
  hasReplies: boolean;
  stamp?: object;
  replies?: AjaxComment[];
}

export interface AjaxCommentsBody {
  total: number;
  comments: AjaxComment[];
}

export interface AjaxCommentsResponse {
  error: boolean;
  message?: string;
  body: AjaxCommentsBody;
}

export interface BookmarkData {
  id: string;
  private: boolean;
  userId: string;
}

export interface IllustBookmark {
  id: string;
  title: string;
  illustType: number;
  url: string;
  tags: string[];
  userId: string;
  userName: string;
  width: number;
  height: number;
  pageCount: number;
  bookmarkData: BookmarkData;
  profileImageUrl: string;
  createDate: string;
}

export interface IllustBookmarkResponseBody {
  works: IllustBookmark[];
  total: number;
}

export interface IllustBookmarkResponse {
  error: boolean;
  body: IllustBookmarkResponseBody;
}

export interface NovelSeries {
  id: number;
  title: string;
  order?: number;
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

export interface FollowLatestIllustResponse {
  error: boolean;
  body: FollowLatestIllustBody;
}

export interface FollowLatestIllustBody {
  thumbnails: FollowLatestIllustThumbnails;
  total: number;
  page: number;
  pages: number;
}

export interface FollowLatestIllustThumbnails {
  illust: IllustBookmark[];
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

export interface DiscoveryIllustsResponse {
  error: boolean;
  body: DiscoveryIllustsBody;
}

export interface DiscoveryIllustsBody {
  thumbnails: DiscoveryThumbnailsIllust;
}

export interface DiscoveryThumbnailsIllust {
  illust: IllustBookmark[];
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

export interface SearchIllustData {
  data: IllustBookmark[];
  total: number;
}

export interface SearchIllustBody {
  illust: SearchIllustData;
}

export interface SearchIllustResponse {
  error: boolean;
  body: SearchIllustBody;
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

export interface UserSearchResult {
  userId: string;
  name: string;
  image: string;
  imageBig: string;
  comment: string;
  premium: boolean;
  isFollowed: boolean;
  following: number;
}

export interface SearchUserPage {
  userIds: number[];
  total: number;
}

export interface SearchUserBody {
  users: UserSearchResult[];
  page: SearchUserPage;
}

export interface SearchUserResponse {
  error: boolean;
  body: SearchUserBody;
}

export interface FollowingUserRaw {
  userId: string;
  userName: string;
  profileImageUrl: string;
  userComment: string;
  following: boolean;
  followed: boolean;
  isBlocking: boolean;
  isMypixiv: boolean;
  acceptRequest: boolean;
}

export interface FollowingUserBody {
  total: number;
  users: FollowingUserRaw[];
}

export interface FollowingUserResponse {
  error: boolean;
  body: FollowingUserBody;
}

export interface ProfileIllust {
  id: string;
  title: string;
  illustType: number;
  xRestrict: number;
  url: string;
  tags: string[];
  userId: string;
  userName?: string;
  width: number;
  height: number;
  pageCount: number;
  isBookmarkable: boolean;
  bookmarkData: BookmarkData | null;
  createDate?: string;
  profileImageUrl?: string;
}

export interface ProfileIllustsBody {
  works: Record<string, ProfileIllust>;
}

export interface ProfileIllustsResponse {
  error: boolean;
  body: ProfileIllustsBody;
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

export interface ProfileAllBody {
  illusts: Record<string, null>;
  manga: Record<string, null>;
  novels: Record<string, null>;
}

export interface ProfileAllResponse {
  error: boolean;
  body: ProfileAllBody;
}

// ---- AppApi types ----

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

export interface CommentProfileImageUrls {
  medium: string;
}

export interface CommentUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: CommentProfileImageUrls;
}

export interface IllustComment {
  id: number;
  comment: string;
  date: string;
  user: CommentUser;
  has_replies: boolean;
  stamp?: object;
}

export interface IllustCommentsResponse {
  total_comments: number;
  comments: IllustComment[];
  next_url: string | null;
}

// ---- Cache ----

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

// ---- Helper functions ----

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
