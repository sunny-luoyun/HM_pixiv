import { describe, it, expect } from '@ohos/hypium';
import { PixivService } from '../main/ets/services/PixivService';
import { RankingContentItem, RankingResponse, IllustContentType, NovelRankItem, NovelRankingResponse, NovelRankingDisplay, NovelRankingBody } from '../main/ets/models/PixivModels';

function makeContentType(): IllustContentType {
  return {
    sexual: 0, lo: false, grotesque: false, violent: false,
    homosexual: false, drug: false, thoughts: false, antisocial: false,
    religion: false, original: false, furry: false, bl: false, yuri: false,
  };
}

function makeIllustItem(): RankingContentItem {
  const ct = makeContentType();
  return {
    title: 'テスト', date: '2026年07月08日 00:00', tags: [],
    url: 'https://i.pximg.net/test.jpg', illust_type: '0',
    illust_book_style: '0', illust_page_count: '1',
    user_name: '作者', profile_img: 'https://i.pximg.net/icon.jpg',
    illust_content_type: ct, illust_series: false,
    illust_id: 1, width: 100, height: 100, user_id: 100,
    rank: 1, yes_rank: 1, rating_count: 0, view_count: 0,
    illust_upload_timestamp: 0, attr: '', is_masked: false,
  };
}

function makeRankingResp(): RankingResponse {
  return {
    contents: [], mode: 'daily', content: 'all', page: 1,
    prev: false, next: 2, date: '20260708',
    prev_date: '20260707', next_date: false, rank_total: 500,
    meta: makeContentType(), date_range_text: '7/8/2026', zoneConfig: makeContentType(),
  };
}

function makeNovelItem(): NovelRankItem {
  return {
    rank: 1, id: '1', title: 't', create_date: 'd',
    user_id: 'u', user_name: 'un', profile_img: 'p',
    comment: 'c', restrict: '0', x_restrict: '0', is_original: '0',
    tag_a: [], url: 'u', series_id: null, series_title: null,
    word_count: '0', character_count: '0', reading_time: 0,
    bookmark_count: 0, genre: '0', ai_type: '0', marker: null,
  };
}

function makeNovelDisplay(): NovelRankingDisplay {
  return {
    rank_a: [], mode: 'daily', page: 1,
    prev: null, next: null, page_a: makeContentType(), title: 'title',
  };
}

function makeNovelBody(): NovelRankingBody {
  return {
    display_a: makeNovelDisplay(), date: '7/9/2026', h_title: 'title',
  };
}

export default function rankingServiceTest() {
  describe('RankingService', () => {

    describe('getRanking', () => {
      it('应是一个存在的异步函数', 0, () => {
        expect(typeof PixivService.getRanking).assertEqual('function');
      });

      it('支持 content 参数', 0, () => {
        const result = PixivService.getRanking('daily', 1, 'illust');
        expect(result instanceof Promise).assertTrue();
      });
    });

    describe('getNovelRanking', () => {
      it('应是一个存在的异步函数', 0, () => {
        expect(typeof PixivService.getNovelRanking).assertEqual('function');
      });

      it('默认参数应返回 Promise', 0, () => {
        const result = PixivService.getNovelRanking('daily', 1);
        expect(result instanceof Promise).assertTrue();
      });
    });

    describe('RankingResponse 模型', () => {
      it('应正确构造排行榜响应', 0, () => {
        const resp = makeRankingResp();
        expect(resp.mode).assertEqual('daily');
        expect(resp.page).assertEqual(1);
        expect(resp.next).assertEqual(2);
        expect(resp.rank_total).assertEqual(500);
      });

      it('最后一页时 next 应为 false', 0, () => {
        const resp = makeRankingResp();
        resp.next = false;
        expect(resp.next).assertFalse();
      });
    });

    describe('NovelRankItem 模型', () => {
      it('应正确构造条目', 0, () => {
        const item = makeNovelItem();
        item.id = '12345';
        item.title = 'テスト小説';
        item.rank = 1;
        item.user_name = '作者';
        item.bookmark_count = 100;
        expect(item.id).assertEqual('12345');
        expect(item.title).assertEqual('テスト小説');
        expect(item.rank).assertEqual(1);
        expect(item.user_name).assertEqual('作者');
        expect(item.bookmark_count).assertEqual(100);
      });
    });

    describe('NovelRankingResponse 模型', () => {
      it('应正确构造响应', 0, () => {
        const resp: NovelRankingResponse = {
          error: false, body: makeNovelBody(),
        };
        expect(resp.error).assertFalse();
        expect(resp.body.display_a.mode).assertEqual('daily');
      });

      it('应支持分页', 0, () => {
        const resp: NovelRankingResponse = {
          error: false, body: makeNovelBody(),
        };
        resp.body.display_a.next = 2;
        expect(resp.body.display_a.next).assertEqual(2);
      });
    });

    describe('字段覆盖', () => {
      it('插画条目包含 IllustCard 所需字段', 0, () => {
        const item = makeIllustItem();
        expect(String(item.illust_id)).assertEqual('1');
        expect(item.url).assertEqual('https://i.pximg.net/test.jpg');
        expect(item.user_name).assertEqual('作者');
        expect(parseInt(item.illust_type)).assertEqual(0);
      });

      it('小说条目包含 NovelCard 所需字段', 0, () => {
        const item = makeNovelItem();
        expect(item.id).assertEqual('1');
        expect(item.title).assertEqual('t');
        expect(item.user_name).assertEqual('un');
        expect(item.tag_a.length).assertEqual(0);
        expect(item.word_count).assertEqual('0');
      });
    });
  });
}
