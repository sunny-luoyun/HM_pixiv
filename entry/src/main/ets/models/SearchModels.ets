export interface SearchCondition {
  startDate: string | undefined;
  endDate: string | undefined;
  bookmarkMin: number | undefined;
  bookmarkMax: number | undefined;
  aiType: number;
  ratio: string;
  workLang: string;
  isOriginal: number;
  duration: string;
  sortOrder: string;
  searchMode: string;
  contentType: string;
  r18Mode: string;
  genre: string;
}

export const DEFAULT_SEARCH_CONDITION: SearchCondition = {
  startDate: undefined,
  endDate: undefined,
  bookmarkMin: undefined,
  bookmarkMax: undefined,
  aiType: 0,
  ratio: '',
  workLang: '',
  isOriginal: 0,
  duration: '',
  sortOrder: 'date_d',
  searchMode: 's_tag',
  contentType: 'illust_and_ugoira',
  r18Mode: 'all',
  genre: '',
};

export function searchConditionToQueryString(cond: SearchCondition): string {
  const params: string[] = [];
  if (cond.startDate !== undefined) {
    params.push('scd=' + cond.startDate);
  }
  if (cond.endDate !== undefined) {
    params.push('ecd=' + cond.endDate);
  }
  if (cond.bookmarkMin !== undefined) {
    params.push('bookmark_num_min=' + cond.bookmarkMin);
  }
  if (cond.bookmarkMax !== undefined) {
    params.push('bookmark_num_max=' + cond.bookmarkMax);
  }
  if (cond.aiType !== 0) {
    params.push('ai_type=' + cond.aiType);
  }
  if (cond.ratio !== '') {
    params.push('ratio=' + cond.ratio);
  }
  if (cond.workLang !== '') {
    params.push('work_lang=' + cond.workLang);
  }
  if (cond.isOriginal !== 0) {
    params.push('is_original=' + cond.isOriginal);
  }
  if (cond.duration !== '') {
    params.push('duration=' + cond.duration);
  }
  if (cond.genre !== '') {
    params.push('genre=' + cond.genre);
  }
  if (params.length > 0) {
    return '&' + params.join('&');
  }
  return '';
}

export function isSearchConditionActive(cond: SearchCondition): boolean {
  if (cond.sortOrder !== 'date_d') return true;
  if (cond.searchMode !== 's_tag') return true;
  if (cond.contentType !== 'illust_and_ugoira') return true;
  if (cond.r18Mode !== 'all') return true;
  if (cond.startDate !== undefined) return true;
  if (cond.endDate !== undefined) return true;
  if (cond.bookmarkMin !== undefined) return true;
  if (cond.bookmarkMax !== undefined) return true;
  if (cond.aiType !== 0) return true;
  if (cond.ratio !== '') return true;
  if (cond.workLang !== '') return true;
  if (cond.isOriginal !== 0) return true;
  if (cond.duration !== '') return true;
  if (cond.genre !== '') return true;
  return false;
}

export function conditionLabelSummary(cond: SearchCondition): string {
  const parts: string[] = [];
  if (cond.sortOrder !== 'date_d') parts.push('排序');
  if (cond.searchMode !== 's_tag') parts.push('模式');
  if (cond.contentType !== 'illust_and_ugoira') parts.push('类型');
  if (cond.r18Mode !== 'all') parts.push('R18');
  if (cond.bookmarkMin !== undefined || cond.bookmarkMax !== undefined) {
    parts.push('收藏数');
  }
  if (cond.startDate !== undefined || cond.endDate !== undefined) {
    parts.push('投稿日');
  }
  if (cond.aiType !== 0) parts.push('AI');
  if (cond.ratio !== '') parts.push('比率');
  if (cond.workLang !== '') parts.push('言語');
  if (cond.isOriginal !== 0) parts.push('オリジナル');
  if (cond.duration !== '') parts.push('期間');
  return parts.join(' ');
}
