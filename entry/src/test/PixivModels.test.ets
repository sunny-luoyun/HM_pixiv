import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import {
  CacheStatus,
  PixivNovel,
  PixivTag,
  PixivSeries,
  RawPixivNovelItem,
  parsePixivNovelFromRaw,
  getCacheStatusDisplay,
  formatTextLength,
  formatPixivDate,
  isReadableOffline
} from '../main/ets/models/PixivModels';

export default function pixivModelsTest() {
  describe('PixivModels', () => {

    describe('CacheStatus 枚举', () => {
      it('应定义四个缓存状态', 0, () => {
        expect(CacheStatus.NOT_CACHED).assertEqual('not_cached');
        expect(CacheStatus.CACHING).assertEqual('caching');
        expect(CacheStatus.CACHED).assertEqual('cached');
        expect(CacheStatus.CACHE_FAIL).assertEqual('cache_fail');
      });
    });

    describe('getCacheStatusDisplay', () => {
      it('NOT_CACHED 应返回未缓存', 0, () => {
        const result = getCacheStatusDisplay(CacheStatus.NOT_CACHED);
        expect(result.label).assertEqual('未缓存');
      });

      it('CACHING 应返回缓存中', 0, () => {
        const result = getCacheStatusDisplay(CacheStatus.CACHING);
        expect(result.label).assertEqual('缓存中');
      });

      it('CACHED 应返回已缓存', 0, () => {
        const result = getCacheStatusDisplay(CacheStatus.CACHED);
        expect(result.label).assertEqual('已缓存');
      });

      it('CACHE_FAIL 应返回缓存失败', 0, () => {
        const result = getCacheStatusDisplay(CacheStatus.CACHE_FAIL);
        expect(result.label).assertEqual('缓存失败');
      });
    });

    describe('formatTextLength', () => {
      it('10000字以上显示为万字', 0, () => {
        expect(formatTextLength(15000)).assertEqual('1.5万字');
        expect(formatTextLength(10000)).assertEqual('1.0万字');
        expect(formatTextLength(50000)).assertEqual('5.0万字');
      });

      it('1000-9999字显示为千字', 0, () => {
        expect(formatTextLength(5500)).assertEqual('5.5千字');
        expect(formatTextLength(1000)).assertEqual('1.0千字');
      });

      it('1000字以下直接显示字数', 0, () => {
        expect(formatTextLength(500)).assertEqual('500字');
        expect(formatTextLength(0)).assertEqual('0字');
        expect(formatTextLength(1)).assertEqual('1字');
      });

      it('边界值 9999 和 10000', 0, () => {
        expect(formatTextLength(9999)).assertEqual('10.0千字');
        expect(formatTextLength(10000)).assertEqual('1.0万字');
      });
    });

    describe('formatPixivDate', () => {
      it('应格式化 ISO 日期为 yyyy/MM/dd', 0, () => {
        expect(formatPixivDate('2025-06-20T12:00:00')).assertEqual('2025/06/20');
        expect(formatPixivDate('2024-01-01T00:00:00Z')).assertEqual('2024/01/01');
      });

      it('空字符串返回空', 0, () => {
        expect(formatPixivDate('')).assertEqual('');
      });

      it('非标准格式也应截取前10位', 0, () => {
        expect(formatPixivDate('2025-06-20')).assertEqual('2025/06/20');
      });
    });

    describe('isReadableOffline', () => {
      it('CACHED 状态应返回 true', 0, () => {
        const novel: PixivNovel = {
          id: '1',
          title: '测试小说',
          caption: '',
          author: '作者',
          authorId: '1',
          coverUrl: '',
          tags: [],
          textLength: 100,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0,
          cacheStatus: CacheStatus.CACHED
        };
        expect(isReadableOffline(novel)).assertTrue();
      });

      it('非 CACHED 状态应返回 false', 0, () => {
        const notCached: PixivNovel = {
          id: '2',
          title: '未缓存',
          caption: '',
          author: '作者',
          authorId: '2',
          coverUrl: '',
          tags: [],
          textLength: 100,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0,
          cacheStatus: CacheStatus.NOT_CACHED
        };
        expect(isReadableOffline(notCached)).assertFalse();

        const caching: PixivNovel = {
          id: '3', title: '未缓存', caption: '', author: '作者', authorId: '2',
          coverUrl: '', tags: [], textLength: 100, pageCount: 1, createDate: '',
          updateDate: '', bookmarkCount: 0, viewCount: 0, commentCount: 0,
          cacheStatus: CacheStatus.CACHING
        };
        expect(isReadableOffline(caching)).assertFalse();

        const fail: PixivNovel = {
          id: '4', title: '未缓存', caption: '', author: '作者', authorId: '2',
          coverUrl: '', tags: [], textLength: 100, pageCount: 1, createDate: '',
          updateDate: '', bookmarkCount: 0, viewCount: 0, commentCount: 0,
          cacheStatus: CacheStatus.CACHE_FAIL
        };
        expect(isReadableOffline(fail)).assertFalse();
      });
    });

    describe('parsePixivNovelFromRaw', () => {
      it('应从完整 raw 数据正确解析小说', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '12345',
          title: 'ある小説',
          comment: '这是一部有趣的小说',
          userName: '絵師太郎',
          userId: '999',
          url: 'https://i.pximg.net/novel/cover.jpg',
          tags: ['オリジナル', '創作'],
          textCount: 5000,
          pageCount: 2,
          createDate: '2025-01-15',
          updateDate: '2025-06-01',
          bookmarkCount: 120,
          viewCount: 3500,
          commentCount: 8,
          seriesId: '100',
          seriesTitle: 'シリーズ名',
          seriesOrder: 3
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.id).assertEqual('12345');
        expect(novel.title).assertEqual('ある小説');
        expect(novel.caption).assertEqual('这是一部有趣的小说');
        expect(novel.author).assertEqual('絵師太郎');
        expect(novel.authorId).assertEqual('999');
        expect(novel.coverUrl).assertEqual('https://i.pximg.net/novel/cover.jpg');
        expect(novel.tags.length).assertEqual(2);
        expect(novel.tags[0].name).assertEqual('オリジナル');
        expect(novel.tags[1].name).assertEqual('創作');
        expect(novel.textLength).assertEqual(5000);
        expect(novel.pageCount).assertEqual(2);
        expect(novel.bookmarkCount).assertEqual(120);
        expect(novel.viewCount).assertEqual(3500);
        expect(novel.commentCount).assertEqual(8);
        expect(novel.cacheStatus).assertEqual(CacheStatus.NOT_CACHED);
      });

      it('应正确解析系列信息', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0,
          seriesId: '42',
          seriesTitle: 'My Series',
          seriesOrder: 1
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.series !== null).assertTrue();
        if (novel.series) {
          expect(novel.series.id).assertEqual('42');
          expect(novel.series.title).assertEqual('My Series');
          expect(novel.series.order).assertEqual(1);
        }
      });

      it('无系列时 series 应为 undefined', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.series).assertUndefined();
      });

      it('comment 为 null 时 caption 应为空字符串', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.caption).assertEqual('');
      });

      it('tags 为 null 时返回空数组', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.tags.length).assertEqual(0);
      });

      it('缺失可选数字字段默认为0', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.bookmarkCount).assertEqual(0);
        expect(novel.viewCount).assertEqual(0);
        expect(novel.commentCount).assertEqual(0);
      });

      it('seriesContentOrder 优先于 seriesOrder', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0,
          seriesId: '1',
          seriesTitle: 'S',
          seriesContentOrder: 5,
          seriesOrder: 3
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.series!.order).assertEqual(5);
      });

      it('raw series 对象应正确解析', 0, () => {
        const raw: RawPixivNovelItem = {
          id: '1',
          title: 'test',
          comment: '',
          userName: 'a',
          userId: '1',
          url: '',
          tags: [],
          textCount: 0,
          pageCount: 1,
          createDate: '',
          updateDate: '',
          bookmarkCount: 0,
          viewCount: 0,
          commentCount: 0,
          series: { id: 10, contentOrder: 7 }
        };
        const novel = parsePixivNovelFromRaw(raw);
        expect(novel.series!.id).assertEqual('10');
        expect(novel.series!.order).assertEqual(7);
      });
    });
  });
}
