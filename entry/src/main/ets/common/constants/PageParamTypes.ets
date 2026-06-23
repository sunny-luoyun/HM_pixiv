export interface IllustDetailParam {
  id: string;
  thumbnailLocalUrl: string;
}

export interface IllustDetailAnimParam extends IllustDetailParam {
  clickedComponentId: string;
  doDefaultTransition: () => void;
}

export interface UserProfileParam {
  userId: string;
  userName: string;
  userAvatar?: string;
}

export interface NovReaderParam {
  novelId: string;
  title: string;
  author: string;
  cached: boolean;
  translatedTitle: string;
  hasTitleTranslation: boolean;
}

export interface NovSeriesParam {
  seriesId: string;
  seriesTitle: string;
}

export interface NovCommentsParam {
  novelId: string;
}

export interface IllustCommentsParam {
  illustId: string;
}

export interface SeriesDetailParam {
  seriesId: string;
  seriesTitle: string;
  authorName: string;
}

export interface AuthorDetailParam {
  authorId: string;
  authorName: string;
}
