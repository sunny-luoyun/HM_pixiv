export interface IllustContentType {
  sexual: number;
  lo: boolean;
  grotesque: boolean;
  violent: boolean;
  homosexual: boolean;
  drug: boolean;
  thoughts: boolean;
  antisocial: boolean;
  religion: boolean;
  original: boolean;
  furry: boolean;
  bl: boolean;
  yuri: boolean;
}

export interface RankingContentItem {
  title: string;
  date: string;
  tags: string[];
  url: string;
  illust_type: string;
  illust_book_style: string;
  illust_page_count: string;
  user_name: string;
  profile_img: string;
  illust_content_type: IllustContentType;
  illust_series: boolean | object;
  illust_id: number;
  width: number;
  height: number;
  user_id: number;
  rank: number;
  yes_rank: number;
  rating_count: number;
  view_count: number;
  illust_upload_timestamp: number;
  attr: string;
  is_masked: boolean;
}

export interface RankingResponse {
  contents: RankingContentItem[];
  mode: string;
  content: string;
  page: number;
  prev: number | boolean;
  next: number | boolean;
  date: string;
  prev_date: string;
  next_date: string | boolean;
  rank_total: number;
  meta: object;
  date_range_text: string;
  zoneConfig: object;
}

export interface NovelRankItem {
  rank: number;
  id: string;
  title: string;
  create_date: string;
  user_id: string;
  user_name: string;
  profile_img: string;
  comment: string;
  restrict: string;
  x_restrict: string;
  is_original: string;
  tag_a: string[];
  url: string;
  series_id: number | null;
  series_title: string | null;
  word_count: string;
  character_count: string;
  reading_time: number;
  bookmark_count: number;
  genre: string;
  ai_type: string;
  marker: string | null;
}

export interface NovelRankingDisplay {
  rank_a: NovelRankItem[];
  mode: string;
  page: number;
  prev: number | null;
  next: number | null;
  page_a: object;
  title: string;
}

export interface NovelRankingBody {
  display_a: NovelRankingDisplay;
  date: string;
  h_title: string;
}

export interface NovelRankingResponse {
  error: boolean;
  body: NovelRankingBody;
}
