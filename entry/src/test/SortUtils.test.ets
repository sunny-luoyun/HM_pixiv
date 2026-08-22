import { describe, it, expect } from '@ohos/hypium';
import { sortNovels, sortAuthorGroups, SortField, SortableAuthorGroup } from '../main/ets/common/utils/SortUtils';
import { PixivNovel, CacheStatus } from '../main/ets/models/PixivModels';

function makeNovel(overrides: Partial<PixivNovel>): PixivNovel {
  return {
    id: '0', title: '', caption: '', author: '', authorId: '',
    coverUrl: '', tags: [], textLength: 0, pageCount: 1,
    createDate: '', updateDate: '', bookmarkCount: 0,
    viewCount: 0, commentCount: 0,
    cacheStatus: CacheStatus.CACHED,
    ...overrides,
  };
}

function makeGroup(overrides: Partial<SortableAuthorGroup>): SortableAuthorGroup {
  return {
    authorId: 'u1',
    authorName: 'Author',
    standaloneNovels: [],
    seriesMap: new Map<string, { seriesId: string; seriesTitle: string; novels: PixivNovel[] }>(),
    totalCount: 0,
    ...overrides,
  };
}

export default function sortUtilsTest() {
  describe('SortUtils', () => {
    describe('sortNovels by title', () => {
      it('升序：A 在 B 前', 0, () => {
        const novels = [
          makeNovel({ id: '1', title: 'Banana' }),
          makeNovel({ id: '2', title: 'Apple' }),
        ];
        const result = sortNovels(novels, 'title', true);
        expect(result[0].title).assertEqual('Apple');
        expect(result[1].title).assertEqual('Banana');
      });

      it('降序：B 在 A 前', 0, () => {
        const novels = [
          makeNovel({ id: '1', title: 'Apple' }),
          makeNovel({ id: '2', title: 'Banana' }),
        ];
        const result = sortNovels(novels, 'title', false);
        expect(result[0].title).assertEqual('Banana');
        expect(result[1].title).assertEqual('Apple');
      });
    });

    describe('sortNovels by cachedAt', () => {
      it('降序：最新缓存在前', 0, () => {
        const novels = [
          makeNovel({ id: '1', cachedAt: '2025-01-01' }),
          makeNovel({ id: '2', cachedAt: '2025-06-01' }),
        ];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
        expect(result[1].id).assertEqual('1');
      });

      it('空 cachedAt 排最后', 0, () => {
        const novels = [
          makeNovel({ id: '1', cachedAt: '' }),
          makeNovel({ id: '2', cachedAt: '2025-06-01' }),
        ];
        const result = sortNovels(novels, 'cachedAt', false);
        expect(result[0].id).assertEqual('2');
      });
    });

    describe('sortNovels by lastReadAt', () => {
      it('未阅读排最前（升序）', 0, () => {
        const novels = [
          makeNovel({ id: '1', lastReadAt: '2025-06-01' }),
          makeNovel({ id: '2' }),  // 无 lastReadAt
        ];
        const result = sortNovels(novels, 'lastReadAt', true);
        expect(result[0].id).assertEqual('2');  // 未读排最前
        expect(result[1].id).assertEqual('1');
      });

      it('未阅读排最后（降序）', 0, () => {
        const novels = [
          makeNovel({ id: '1', lastReadAt: '2025-06-01' }),
          makeNovel({ id: '2' }),  // 无 lastReadAt
        ];
        const result = sortNovels(novels, 'lastReadAt', false);
        expect(result[0].id).assertEqual('1');
        expect(result[1].id).assertEqual('2');  // 未读排最后
      });
    });

    describe('sortNovels by seriesOrder', () => {
      it('按章节序号排序', 0, () => {
        const novels = [
          makeNovel({ id: '1', series: { id: 's1', title: '系列', order: 3 } }),
          makeNovel({ id: '2', series: { id: 's1', title: '系列', order: 1 } }),
        ];
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
        const groups = [
          makeGroup({ authorId: 'u1', authorName: 'Zoe' }),
          makeGroup({ authorId: 'u2', authorName: 'Alice' }),
        ];
        const result = sortAuthorGroups(groups, 'authorName', true);
        expect(result[0].authorName).assertEqual('Alice');
        expect(result[1].authorName).assertEqual('Zoe');
      });

      it('按小说数量降序', 0, () => {
        const groups = [
          makeGroup({ authorId: 'u1', authorName: 'A', totalCount: 3 }),
          makeGroup({ authorId: 'u2', authorName: 'B', totalCount: 10 }),
        ];
        const result = sortAuthorGroups(groups, 'novelCount', false);
        expect(result[0].totalCount).assertEqual(10);
        expect(result[1].totalCount).assertEqual(3);
      });

      it('按 cachedAt 取组内最新', 0, () => {
        const g1 = makeGroup({
          authorId: 'u1', authorName: 'A', totalCount: 1,
          standaloneNovels: [makeNovel({ id: 'n1', cachedAt: '2025-01-01' })],
        });
        const g2 = makeGroup({
          authorId: 'u2', authorName: 'B', totalCount: 1,
          standaloneNovels: [makeNovel({ id: 'n2', cachedAt: '2025-06-01' })],
        });
        const result = sortAuthorGroups([g1, g2], 'cachedAt', false);
        expect(result[0].authorId).assertEqual('u2');
        expect(result[1].authorId).assertEqual('u1');
      });

      it('按最后阅读时间排序（通过 lastReadMap）', 0, () => {
        const groups = [
          makeGroup({ authorId: 'a1', authorName: 'Alice', totalCount: 1,
            standaloneNovels: [makeNovel({ id: 'n1' })] }),
          makeGroup({ authorId: 'a2', authorName: 'Bob', totalCount: 1,
            standaloneNovels: [makeNovel({ id: 'n2' })] }),
        ];
        const lastReadMap = new Map<string, string>();
        lastReadMap.set('n1', '2025-06-01');
        lastReadMap.set('n2', '2025-01-01');
        const result = sortAuthorGroups(groups, 'lastReadAt', false, lastReadMap);
        expect(result[0].authorId).assertEqual('a1'); // newer read first
        expect(result[1].authorId).assertEqual('a2');
      });
    });
  });
}
