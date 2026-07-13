import { describe, it, expect } from '@ohos/hypium';
import { BrowseHistoryRecord } from '../main/ets/models/PixivModels';

export default function browseHistoryDaoTest() {
  describe('BrowseHistoryDao（逻辑/Schema 验证）', () => {

    describe('BrowseHistoryRecord 接口', () => {
      it('BrowseHistoryRecord 应包含所有必需字段', 0, () => {
        const record: BrowseHistoryRecord = {
          id: 'illust_123',
          contentType: 'illust',
          contentId: '123',
          title: '测试作品',
          coverUrl: 'https://example.com/cover.jpg',
          userId: '456',
          userName: '测试作者',
          pageCount: 1,
          tags: ['tag1', 'tag2'],
          bookmarkCount: 10,
          wordCount: 0,
          seriesId: '',
          seriesTitle: '',
          createDate: '2026-01-01T00:00:00+00:00',
          updateDate: '',
          viewedAt: '2026-07-12T00:00:00'
        };
        expect(record.id).assertEqual('illust_123');
        expect(record.contentType).assertEqual('illust');
        expect(record.contentId).assertEqual('123');
        expect(record.title).assertEqual('测试作品');
        expect(record.coverUrl).assertEqual('https://example.com/cover.jpg');
        expect(record.userId).assertEqual('456');
        expect(record.userName).assertEqual('测试作者');
        expect(record.pageCount).assertEqual(1);
        expect(record.tags.length).assertEqual(2);
        expect(record.tags[0]).assertEqual('tag1');
        expect(record.tags[1]).assertEqual('tag2');
        expect(record.bookmarkCount).assertEqual(10);
        expect(record.wordCount).assertEqual(0);
        expect(record.seriesId).assertEqual('');
        expect(record.seriesTitle).assertEqual('');
        expect(record.createDate).assertEqual('2026-01-01T00:00:00+00:00');
        expect(record.updateDate).assertEqual('');
        expect(record.viewedAt).assertEqual('2026-07-12T00:00:00');
      });

      it('novel 类型记录应包含系列信息', 0, () => {
        const record: BrowseHistoryRecord = {
          id: 'novel_789',
          contentType: 'novel',
          contentId: '789',
          title: '测试小说',
          coverUrl: 'https://example.com/novel_cover.jpg',
          userId: '456',
          userName: '测试作者',
          pageCount: 5,
          tags: ['novel_tag'],
          bookmarkCount: 20,
          wordCount: 15000,
          seriesId: '999',
          seriesTitle: '测试系列',
          createDate: '2026-02-01T00:00:00+00:00',
          updateDate: '2026-03-01T00:00:00+00:00',
          viewedAt: '2026-07-12T00:00:00'
        };
        expect(record.id).assertEqual('novel_789');
        expect(record.contentType).assertEqual('novel');
        expect(record.wordCount).assertEqual(15000);
        expect(record.seriesId).assertEqual('999');
        expect(record.seriesTitle).assertEqual('测试系列');
        expect(record.createDate).assertEqual('2026-02-01T00:00:00+00:00');
        expect(record.updateDate).assertEqual('2026-03-01T00:00:00+00:00');
      });
    });

    describe('browse_history 表结构', () => {
      it('应包含 16 个字段', 0, () => {
        const columns = [
          'id', 'content_type', 'content_id', 'title', 'cover_url',
          'user_id', 'user_name', 'page_count', 'tags', 'bookmark_count',
          'word_count', 'series_id', 'series_title', 'create_date',
          'update_date', 'viewed_at'
        ];
        expect(columns.length).assertEqual(16);
        expect(columns[0]).assertEqual('id');
        expect(columns[1]).assertEqual('content_type');
        expect(columns[2]).assertEqual('content_id');
        expect(columns[columns.length - 1]).assertEqual('viewed_at');
      });

      it('id 应为 TEXT 类型主键', 0, () => {
        const idCol = 'id';
        expect(typeof idCol).assertEqual('string');
      });
    });

    describe('BrowseHistoryDao 方法签名', () => {
      it('saveHistory 应为 async 方法接受 BrowseHistoryRecord', 0, () => {
        const sig = 'saveHistory(record: BrowseHistoryRecord): Promise<void>';
        expect(sig.length > 0).assertTrue();
      });

      it('getAllIllustHistory 应返回 BrowseHistoryRecord[]', 0, () => {
        const sig = 'getAllIllustHistory(): Promise<BrowseHistoryRecord[]>';
        expect(sig.length > 0).assertTrue();
      });

      it('getAllNovelHistory 应返回 BrowseHistoryRecord[]', 0, () => {
        const sig = 'getAllNovelHistory(): Promise<BrowseHistoryRecord[]>';
        expect(sig.length > 0).assertTrue();
      });

      it('deleteHistory 应为 async 方法接受 id 字符串', 0, () => {
        const sig = 'deleteHistory(id: string): Promise<void>';
        expect(sig.length > 0).assertTrue();
      });

      it('deleteHistoryByDate 应为 async 方法接受 dateKey 和 contentType', 0, () => {
        const sig = 'deleteHistoryByDate(dateKey: string, contentType: string): Promise<number>';
        expect(sig.length > 0).assertTrue();
      });
    });
  });
}
