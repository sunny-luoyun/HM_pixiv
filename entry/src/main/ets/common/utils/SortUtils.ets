import { PixivNovel } from '../../models/PixivModels';

export type SortField = 'cachedAt' | 'title' | 'authorName' | 'lastReadAt' | 'seriesOrder' | 'novelCount';

/**
 * 按 lastReadAt 排序的比较函数：空值（未阅读）排最前面
 */
function compareLastRead(a: string | undefined, b: string | undefined, ascending: boolean): number {
  const aEmpty = !a;
  const bEmpty = !b;
  if (aEmpty && bEmpty) return 0;
  if (aEmpty) return ascending ? -1 : 1;  // 未读排最前
  if (bEmpty) return ascending ? 1 : -1;
  const cmp = a!.localeCompare(b!);
  return ascending ? cmp : -cmp;
}

/**
 * 排序独立小说列表
 */
export function sortNovels(novels: PixivNovel[], field: SortField, ascending: boolean): PixivNovel[] {
  const sorted = [...novels];
  sorted.sort((a, b) => {
    switch (field) {
      case 'cachedAt': {
        const cmp = (a.cachedAt ?? '').localeCompare(b.cachedAt ?? '');
        return ascending ? cmp : -cmp;
      }
      case 'title': {
        const cmp = a.title.localeCompare(b.title);
        return ascending ? cmp : -cmp;
      }
      case 'lastReadAt':
        return compareLastRead(a.lastReadAt, b.lastReadAt, ascending);
      case 'seriesOrder': {
        const cmp = (a.series?.order ?? 0) - (b.series?.order ?? 0);
        return ascending ? cmp : -cmp;
      }
      default:
        return 0;
    }
  });
  return sorted;
}

export interface SortableAuthorGroup {
  authorId: string;
  authorName: string;
  standaloneNovels: PixivNovel[];
  seriesMap: Map<string, { seriesId: string; seriesTitle: string; novels: PixivNovel[] }>;
  totalCount: number;
}

/**
 * 排序作者组列表
 * field 为 'cachedAt' / 'lastReadAt' 时，取该作者下最新/最后的时间
 */
export function sortAuthorGroups(
  groups: SortableAuthorGroup[],
  field: SortField,
  ascending: boolean,
  lastReadMap?: Map<string, string>
): SortableAuthorGroup[] {
  const sorted = [...groups];
  sorted.sort((a, b) => {
    switch (field) {
      case 'authorName': {
        const cmp = a.authorName.localeCompare(b.authorName);
        return ascending ? cmp : -cmp;
      }
      case 'novelCount': {
        const cmp = a.totalCount - b.totalCount;
        return ascending ? cmp : -cmp;
      }
      case 'cachedAt': {
        // 取该作者下最新的一篇 cachedAt
        const aLatest = getLatestCachedAt(a);
        const bLatest = getLatestCachedAt(b);
        const cmp = aLatest.localeCompare(bLatest);
        return ascending ? cmp : -cmp;
      }
      case 'lastReadAt': {
        const aLatest = getLatestLastReadAt(a, lastReadMap);
        const bLatest = getLatestLastReadAt(b, lastReadMap);
        return compareLastRead(aLatest, bLatest, ascending);
      }
      default:
        return 0;
    }
  });
  return sorted;
}

function getLatestCachedAt(group: SortableAuthorGroup): string {
  let latest = '';
  for (const n of group.standaloneNovels) {
    if (n.cachedAt && n.cachedAt > latest) latest = n.cachedAt;
  }
  for (const sg of group.seriesMap.values()) {
    for (const n of sg.novels) {
      if (n.cachedAt && n.cachedAt > latest) latest = n.cachedAt;
    }
  }
  return latest;
}

function getLatestLastReadAt(group: SortableAuthorGroup, map?: Map<string, string>): string | undefined {
  if (!map) return undefined;
  let latest: string | undefined;
  const check = (nid: string) => {
    const t = map.get(nid);
    if (t && (!latest || t > latest)) latest = t;
  };
  for (const n of group.standaloneNovels) check(n.id);
  for (const sg of group.seriesMap.values()) {
    for (const n of sg.novels) check(n.id);
  }
  return latest;
}
