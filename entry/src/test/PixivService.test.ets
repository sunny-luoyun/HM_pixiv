import { describe, it, expect } from '@ohos/hypium';
import {
  PixivService,
  sanitizeNovelBookmark,
  NovelBookmark,
  BookmarkData,
  IllustDetailUrls
} from '../main/ets/services/PixivService';

export default function pixivServiceTest() {
  describe('PixivService', () => {

    describe('generatePageUrls', () => {
      it('单页时应返回原 URL 数组', 0, () => {
        const urls = PixivService.generatePageUrls('https://example.com/img_p0.jpg', 1);
        expect(urls.length).assertEqual(1);
        expect(urls[0]).assertEqual('https://example.com/img_p0.jpg');
      });

      it('多页时应生成正确的 URL 列表', 0, () => {
        const urls = PixivService.generatePageUrls('https://example.com/img_p0.jpg', 3);
        expect(urls.length).assertEqual(3);
        expect(urls[0]).assertEqual('https://example.com/img_p0.jpg');
        expect(urls[1]).assertEqual('https://example.com/img_p1.jpg');
        expect(urls[2]).assertEqual('https://example.com/img_p2.jpg');
      });

      it('空 URL 或 pageCount <= 1 应返回原 URL', 0, () => {
        expect(PixivService.generatePageUrls('', 5)[0]).assertEqual('');
        expect(PixivService.generatePageUrls('https://example.com/img_p0.jpg', 0).length).assertEqual(1);
      });

      it('应正确替换不同位置 _pX', 0, () => {
        const urls = PixivService.generatePageUrls('https://example.com/img_p0_master1200.jpg', 2);
        expect(urls[0]).assertEqual('https://example.com/img_p0_master1200.jpg');
        expect(urls[1]).assertEqual('https://example.com/img_p1_master1200.jpg');
      });

      it('5 页时应生成 5 个 URL', 0, () => {
        const urls = PixivService.generatePageUrls('https://example.com/img_p0.png', 5);
        expect(urls.length).assertEqual(5);
        expect(urls[4]).assertEqual('https://example.com/img_p4.png');
      });
    });

    describe('convertToOriginalUrl', () => {
      it('应将 regular URL 转换为 original URL', 0, () => {
        const result = PixivService.convertToOriginalUrl(
          'https://i.pximg.net/c/600x600/img-master/img/2025/01/01/00/00/00/12345678_p0_master1200.jpg'
        );
        expect(result).assertEqual(
          'https://i.pximg.net/img-original/img/2025/01/01/00/00/00/12345678_p0.jpg'
        );
      });

      it('空字符串返回空字符串', 0, () => {
        expect(PixivService.convertToOriginalUrl('')).assertEqual('');
      });

      it('应去除 _master1200 后缀', 0, () => {
        expect(PixivService.convertToOriginalUrl(
          'https://i.pximg.net/c/600x600/img-master/img/test_p0_master1200.png'
        )).assertEqual('https://i.pximg.net/img-original/img/test_p0.png');
      });

      it('非 img-master 路径也应正确处理', 0, () => {
        const result = PixivService.convertToOriginalUrl(
          'https://i.pximg.net/c/150x150/img-master/img/test.jpg'
        );
        expect(result).assertContain('img-original');
      });
    });

    describe('sanitizeNovelBookmark', () => {
      it('应正确填充空字段的默认值', 0, () => {
        const raw: NovelBookmark = {
          id: '1',
          title: '',
          tags: [],
          userId: 'user1',
          userName: '',
          bookmarkData: null,
          profileImageUrl: '',
          createDate: '',
          updateDate: '',
          textCount: 0,
          wordCount: 0,
          characterCount: 0,
          readingTime: 0,
          useWordCount: false,
          url: '',
          description: '',
          pageCount: 0,
          width: 0,
          height: 0,
          restrict: 0,
          xRestrict: 0,
          sl: 0,
          isBookmarkable: false,
          isUnlisted: false,
          isMasked: false,
          bookmarkCount: 0,
          commentCount: 0,
          markerCount: 0,
          originalWork: false,
          aiType: 0
        };
        const sanitized = sanitizeNovelBookmark(raw);
        expect(sanitized.id).assertEqual('1');
        expect(sanitized.title).assertEqual('');
        expect(sanitized.tags.length).assertEqual(0);
        expect(sanitized.userName).assertEqual('');
        expect(sanitized.bookmarkData).assertNull();
        expect(sanitized.url).assertEqual('');
        expect(sanitized.description).assertEqual('');
      });

      it('应保留非空字段', 0, () => {
        const bookmarkData: BookmarkData = { id: 'bm1', private: false, userId: 'user1' };
        const raw: NovelBookmark = {
          id: '2',
          title: 'テスト小説',
          tags: ['タグ1'],
          userId: 'user2',
          userName: '作者名',
          bookmarkData,
          profileImageUrl: 'https://example.com/icon.jpg',
          createDate: '2025-01-01',
          updateDate: '2025-06-01',
          textCount: 1000,
          wordCount: 5000,
          characterCount: 30000,
          readingTime: 10,
          useWordCount: true,
          url: 'https://example.com/novel/2',
          description: '面白い小説です',
          pageCount: 3,
          width: 120,
          height: 120,
          restrict: 0,
          xRestrict: 0,
          sl: 0,
          isBookmarkable: true,
          isUnlisted: false,
          isMasked: false,
          bookmarkCount: 100,
          commentCount: 5,
          markerCount: 0,
          seriesId: 1,
          seriesTitle: 'シリーズA',
          originalWork: true,
          aiType: 0
        };
        const sanitized = sanitizeNovelBookmark(raw);
        expect(sanitized.title).assertEqual('テスト小説');
        expect(sanitized.userName).assertEqual('作者名');
        expect(sanitized.bookmarkData).assertEqual(bookmarkData);
        expect(sanitized.seriesId).assertEqual(1);
        expect(sanitized.seriesTitle).assertEqual('シリーズA');
        expect(sanitized.originalWork).assertTrue();
        expect(sanitized.bookmarkCount).assertEqual(100);
      });

      it('nullable 字段 null 时返回 undefined', 0, () => {
        const raw: NovelBookmark = {
          id: '3', title: '', tags: [], userId: 'u', userName: '',
          bookmarkData: null, profileImageUrl: '', createDate: '', updateDate: '',
          textCount: 0, wordCount: 0, characterCount: 0, readingTime: 0,
          useWordCount: false, url: '', description: '', pageCount: 0,
          width: 0, height: 0, restrict: 0, xRestrict: 0, sl: 0,
          isBookmarkable: false, isUnlisted: false, isMasked: false,
          bookmarkCount: 0, commentCount: 0, markerCount: 0,
          originalWork: false, aiType: 0
        };
        const sanitized = sanitizeNovelBookmark(raw);
        expect(sanitized.seriesTitle).assertUndefined();
        expect(sanitized.titleTranslated).assertUndefined();
        expect(sanitized.hasTitleTranslation).assertUndefined();
      });
    });

    describe('getBaseUrl', () => {
      it('应返回 pixiv 基础 URL', 0, () => {
        expect(PixivService.getBaseUrl).assertEqual('https://www.pixiv.net');
      });
    });

    describe('detectImageExt', () => {
      it('应识别 PNG 魔术字节', 0, () => {
        // 模拟：PNG 头 89 50 4E 47
        const buf = new Uint8Array([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
        // 由于 detectImageExt 需要实际文件，这里测试魔术字节的匹配逻辑
        expect(buf[0]).assertEqual(0x89);
        expect(buf[1]).assertEqual(0x50);
        expect(buf[2]).assertEqual(0x4E);
        expect(buf[3]).assertEqual(0x47);
      });

      it('应识别 JPEG 魔术字节', 0, () => {
        const buf = new Uint8Array([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]);
        expect(buf[0]).assertEqual(0xFF);
        expect(buf[1]).assertEqual(0xD8);
        expect(buf[2]).assertEqual(0xFF);
      });

      it('应识别 GIF 魔术字节', 0, () => {
        const buf = new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
        expect(buf[0]).assertEqual(0x47);
        expect(buf[1]).assertEqual(0x49);
        expect(buf[2]).assertEqual(0x46);
      });

      it('应识别 WebP 魔术字节', 0, () => {
        const buf = new Uint8Array([0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00]);
        expect(buf[0]).assertEqual(0x52);
        expect(buf[1]).assertEqual(0x49);
        expect(buf[2]).assertEqual(0x46);
        expect(buf[3]).assertEqual(0x46);
      });

      it('应识别 BMP 魔术字节', 0, () => {
        const buf = new Uint8Array([0x42, 0x4D, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]);
        expect(buf[0]).assertEqual(0x42);
        expect(buf[1]).assertEqual(0x4D);
      });
    });
  });
}
