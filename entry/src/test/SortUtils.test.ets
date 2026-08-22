import { describe, it, expect } from '@ohos/hypium';
import { sortNovels, sortAuthorGroups, SortField, SortableAuthorGroup, SortableSeriesGroup } from '../main/ets/common/utils/SortUtils';
import { PixivNovel, CacheStatus } from '../main/ets/models/PixivModels';

function makeNovel(id: string, title: string, cachedAt?: string, lastReadAt?: string, seriesOrder?: number): PixivNovel {
  const novel: PixivNovel = {
    id: id,
    title: title,
    caption: '',
    author: '',
    authorId: '',
    coverUrl: '',
    tags: [],
    textLength: 0,
    pageCount: 1,
    createDate: '',
    updateDate: '',
    bookmarkCount: 0,
    viewCount: 0,
    commentCount: 0,
    cacheStatus: CacheStatus.CACHED,
  };
  if (cachedAt !== undefined) novel.cachedAt = cachedAt;
  if (lastReadAt !== undefined) novel.lastReadAt = lastReadAt;
  if (seriesOrder !== undefined) {
    novel.series = { id: 's1', title: '系列', order: seriesOrder };
  }
  return novel;
}

function makeGroup(authorId: string, authorName: string, totalCount: number, novels?: PixivNovel[]): SortableAuthorGroup {
  const group: SortableAuthorGroup = {
    authorId: authorId,
    authorName: authorName,
    standaloneNovels: novels ?? [],
    seriesMap: new Map<string, SortableSeriesGroup>(),
    totalCount: totalCount,
  };
  return group;
}

export default function sortUtilsTest() {
  describe('SortUtils', () => {
    describe('sortNovels by title', () => {
      it('升序：A 在 B 前', 0, () => {
        const novels = [makeNovel('1', 'Banana'), makeNovel('2', 'Apple')];
        const result = sortNovels(novels, 'title', true);
        expect(result[0].title).assertEqual('Apple');
        expect(result[1].title).assertEqual('Banana');
      });

      it('降序：B 在 A 前', 0, () => {
        const novels = [makeNovel('1', 'Apple'), makeNovel('2', 'Banana')];
        const result = sortNovels(novels, 'title', false);
        expect(result[0].title).assertEqual('Banana');
        expect(result[1].title).assertEqual('Apple');
      });
    });

    describe('sortNovels by cachedAt', () => {
      it('降序：最新缓存在前', 0, () => {
        const novels = [makeNovel('1', 'A', '2025-01-01'), makeNovel('2', 'B', '2025-06-01')];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });

      it('空 cachedAt 排最后', 0, () => {
        const novels = [makeNovel('1', 'A', ''), makeNovel('2', 'B', '2025-06-01')];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
      });
    });

    describe('sortNovels by lastReadAt', () => {
      it('未阅读排最前（升序）', 0, () => {
        const novels = [makeNovel('1', 'A', undefined, '2025-06-01'), makeNovel('2', 'B')];
        const result = sortNovels(novels, 'lastReadAt', true);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });

      it('未阅读排最后（降序）', 0, () => {
        const novels = [makeNovel('1', 'A', undefined, '2025-06-01'), makeNovel('2', 'B')];
        const result = sortNovels(novels, 'lastReadAt', false);
        expect(result[0].id).assertEqual('1');
        expect(result[1].id).assertEqual('2');
      });
    });

    describe('sortNovels by seriesOrder', () => {
      it('按章节序号排序', 0, () => {
        const novels = [makeNovel('1', 'A', undefined, undefined, 3), makeNovel('2', 'B', undefined, undefined, 1)];
        const result = sortNovels(novels, 'seriesOrder', true);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });

      it('空数组返回空数组', 0, () => {
        const result = sortNovels([], 'title', true);
        expect(result.length).assertEqual(0);
      });
    });

    describe('sortAuthorGroups', () => {
      it('按作者名升序', 0, () => {
        const groups = [makeGroup('u1', 'Zoe', 1), makeGroup('u2', 'Alice', 1)];
        const result = sortAuthorGroups(groups, 'authorName', true);
        expect(result[0].authorName).assertEqual('Alice');
        expect(result[1].authorName).assertEqual('Zoe');
      });

      it('按小说数量降序', 0, () => {
        const groups = [makeGroup('u1', 'A', 3), makeGroup('u2', 'B', 10)];
        const result = sortAuthorGroups(groups, 'novelCount', false);
        expect(result[0].totalCount).assertEqual(10);
        expect(result[1].totalCount).assertEqual(3);
      });

      it('按 cachedAt 取组内最新', 0, () => {
        const g1 = makeGroup('u1', 'A', 1, [makeNovel('n1', 'A', '2025-01-01')]);
        const g2 = makeGroup('u2', 'B', 1, [makeNovel('n2', 'B', '2025-06-01')]);
        const result = sortAuthorGroups([g1, g2], 'cachedAt', false);
        expect(result[0].authorId).assertEqual('u2');
        expect(result[1].authorId).assertEqual('u1');
      });

      it('按最后阅读时间排序（通过 lastReadMap）', 0, () => {
        const groups = [makeGroup('a1', 'Alice', 1, [makeNovel('n1', 'A')]), makeGroup('a2', 'Bob', 1, [makeNovel('n2', 'B')])];
        const lastReadMap = new Map<string, string>();
        lastReadMap.set('n1', '2025-06-01');
        lastReadMap.set('n2', '2025-01-01');
        const result = sortAuthorGroups(groups, 'lastReadAt', false, lastReadMap);
        expect(result[0].authorId).assertEqual('a1');
        expect(result[1].authorId).assertEqual('a2');
      });
    });
  });
}
