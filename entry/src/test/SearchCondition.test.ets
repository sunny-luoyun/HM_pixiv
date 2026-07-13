import { describe, it, expect } from '@ohos/hypium';
import {
  SearchCondition,
  DEFAULT_SEARCH_CONDITION,
  searchConditionToQueryString,
  isSearchConditionActive
} from '../main/ets/models/SearchModels';

function makeCond(overrides: Partial<SearchCondition>): SearchCondition {
  return {
    startDate: overrides.startDate !== undefined ? overrides.startDate : DEFAULT_SEARCH_CONDITION.startDate,
    endDate: overrides.endDate !== undefined ? overrides.endDate : DEFAULT_SEARCH_CONDITION.endDate,
    bookmarkMin: overrides.bookmarkMin !== undefined ? overrides.bookmarkMin : DEFAULT_SEARCH_CONDITION.bookmarkMin,
    bookmarkMax: overrides.bookmarkMax !== undefined ? overrides.bookmarkMax : DEFAULT_SEARCH_CONDITION.bookmarkMax,
    aiType: overrides.aiType !== undefined ? overrides.aiType : DEFAULT_SEARCH_CONDITION.aiType,
    ratio: overrides.ratio !== undefined ? overrides.ratio : DEFAULT_SEARCH_CONDITION.ratio,
    workLang: overrides.workLang !== undefined ? overrides.workLang : DEFAULT_SEARCH_CONDITION.workLang,
    isOriginal: overrides.isOriginal !== undefined ? overrides.isOriginal : DEFAULT_SEARCH_CONDITION.isOriginal,
    duration: overrides.duration !== undefined ? overrides.duration : DEFAULT_SEARCH_CONDITION.duration,
    sortOrder: overrides.sortOrder !== undefined ? overrides.sortOrder : DEFAULT_SEARCH_CONDITION.sortOrder,
    searchMode: overrides.searchMode !== undefined ? overrides.searchMode : DEFAULT_SEARCH_CONDITION.searchMode,
    contentType: overrides.contentType !== undefined ? overrides.contentType : DEFAULT_SEARCH_CONDITION.contentType,
    r18Mode: overrides.r18Mode !== undefined ? overrides.r18Mode : DEFAULT_SEARCH_CONDITION.r18Mode,
    genre: overrides.genre !== undefined ? overrides.genre : DEFAULT_SEARCH_CONDITION.genre,
  };
}

export default function searchConditionTest() {
  describe('SearchCondition', () => {

    describe('DEFAULT_SEARCH_CONDITION', () => {
      it('应有正确的默认值', 0, () => {
        expect(DEFAULT_SEARCH_CONDITION.startDate).assertUndefined();
        expect(DEFAULT_SEARCH_CONDITION.endDate).assertUndefined();
        expect(DEFAULT_SEARCH_CONDITION.bookmarkMin).assertUndefined();
        expect(DEFAULT_SEARCH_CONDITION.bookmarkMax).assertUndefined();
        expect(DEFAULT_SEARCH_CONDITION.aiType).assertEqual(0);
        expect(DEFAULT_SEARCH_CONDITION.ratio).assertEqual('');
        expect(DEFAULT_SEARCH_CONDITION.workLang).assertEqual('');
        expect(DEFAULT_SEARCH_CONDITION.isOriginal).assertEqual(0);
        expect(DEFAULT_SEARCH_CONDITION.duration).assertEqual('');
        expect(DEFAULT_SEARCH_CONDITION.sortOrder).assertEqual('date_d');
        expect(DEFAULT_SEARCH_CONDITION.searchMode).assertEqual('s_tag');
        expect(DEFAULT_SEARCH_CONDITION.contentType).assertEqual('illust_and_ugoira');
        expect(DEFAULT_SEARCH_CONDITION.r18Mode).assertEqual('all');
      });
    });

    describe('searchConditionToQueryString', () => {
      it('默认条件应返回空字符串', 0, () => {
        const result = searchConditionToQueryString(DEFAULT_SEARCH_CONDITION);
        expect(result).assertEqual('');
      });

      it('bookmarkMin 应生成正确参数', 0, () => {
        const cond = makeCond({ bookmarkMin: 1000 });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&bookmark_num_min=1000');
      });

      it('bookmarkMax 应生成正确参数', 0, () => {
        const cond = makeCond({ bookmarkMax: 5000 });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&bookmark_num_max=5000');
      });

      it('startDate 和 endDate 应生成正确参数', 0, () => {
        const cond = makeCond({ startDate: '2024-01-01', endDate: '2024-12-31' });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&scd=2024-01-01&ecd=2024-12-31');
      });

      it('aiType 非0应生成参数', 0, () => {
        const cond = makeCond({ aiType: 2 });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&ai_type=2');
      });

      it('ratio 非空应生成参数', 0, () => {
        const cond = makeCond({ ratio: '0.6' });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&ratio=0.6');
      });

      it('workLang 非空应生成参数', 0, () => {
        const cond = makeCond({ workLang: 'zh-cn' });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&work_lang=zh-cn');
      });

      it('isOriginal 非0应生成参数', 0, () => {
        const cond = makeCond({ isOriginal: 1 });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&is_original=1');
      });

      it('duration 非空应生成参数', 0, () => {
        const cond = makeCond({ duration: 'within_last_week' });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&duration=within_last_week');
      });

      it('多个条件应正确拼接', 0, () => {
        const cond = makeCond({
          startDate: '2024-06-01',
          endDate: '2024-08-31',
          bookmarkMin: 500,
          bookmarkMax: 5000,
          aiType: 2,
          workLang: 'ja',
          isOriginal: 1,
        });
        const result = searchConditionToQueryString(cond);
        expect(result).assertEqual('&scd=2024-06-01&ecd=2024-08-31&bookmark_num_min=500&bookmark_num_max=5000&ai_type=2&work_lang=ja&is_original=1');
      });

      it('所有条件同时设置', 0, () => {
        const cond = makeCond({
          startDate: '2024-01-01',
          endDate: '2024-12-31',
          bookmarkMin: 100,
          bookmarkMax: 10000,
          aiType: 1,
          ratio: '1.0',
          workLang: 'en',
          isOriginal: 1,
          duration: 'within_last_year',
        });
        const result = searchConditionToQueryString(cond);
        const expected = '&scd=2024-01-01&ecd=2024-12-31&bookmark_num_min=100&bookmark_num_max=10000&ai_type=1&ratio=1.0&work_lang=en&is_original=1&duration=within_last_year';
        expect(result).assertEqual(expected);
      });
    });

    describe('isSearchConditionActive', () => {
      it('默认条件应返回 false', 0, () => {
        expect(isSearchConditionActive(DEFAULT_SEARCH_CONDITION)).assertFalse();
      });

      it('bookmarkMin 设置后应返回 true', 0, () => {
        const cond = makeCond({ bookmarkMin: 100 });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('aiType 非0应返回 true', 0, () => {
        const cond = makeCond({ aiType: 1 });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('ratio 非空应返回 true', 0, () => {
        const cond = makeCond({ ratio: '1.0' });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('sortOrder 非默认应返回 true', 0, () => {
        const cond = makeCond({ sortOrder: 'popular_d' });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('searchMode 非默认应返回 true', 0, () => {
        const cond = makeCond({ searchMode: 's_tc' });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('contentType 非默认应返回 true', 0, () => {
        const cond = makeCond({ contentType: 'manga' });
        expect(isSearchConditionActive(cond)).assertTrue();
      });

      it('r18Mode 非默认应返回 true', 0, () => {
        const cond = makeCond({ r18Mode: 'r18' });
        expect(isSearchConditionActive(cond)).assertTrue();
      });
    });
  });
}
