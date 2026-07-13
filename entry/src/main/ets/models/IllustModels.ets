import { BookmarkData } from './CommonModels';

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

export interface SearchIllustData {
  data: IllustBookmark[];
  total: number;
}

export interface SearchIllustBody {
  illust: SearchIllustData;
  illustManga?: SearchIllustData;
}

export interface SearchIllustResponse {
  error: boolean;
  body: SearchIllustBody;
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

export interface CommentProfileImageUrls {
  medium: string;
}

export interface CommentUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: CommentProfileImageUrls;
}

export interface CommentStamp {
  stamp_id: number;
  stamp_url: string;
}

export interface IllustComment {
  id: number;
  comment: string;
  date: string;
  user: CommentUser;
  has_replies: boolean;
  stamp?: CommentStamp;
}

export interface IllustCommentsResponse {
  total_comments: number;
  comments: IllustComment[];
  next_url: string | null;
}
