import { describe, it, expect } from '@ohos/hypium';
import { getSemanticTagCount, filterByMaxTags } from '../main/ets/common/utils/NovelFilterUtils';

interface MockNovel {
  tags: string[];
  id: string;
}

export default function novelFilterUtilsTest() {
  describe('NovelFilterUtils', () => {

    describe('getSemanticTagCount', () => {
      it('空数组应返回 0', 0, () => {
        const result = getSemanticTagCount([]);
        expect(result).assertEqual(0);
      })

      it('单个普通 tag 应返回 1', 0, () => {
        const result = getSemanticTagCount(['R-18']);
        expect(result).assertEqual(1);
      })

      it('含 / 的 tag 应正确拆分统计', 0, () => {
        const result = getSemanticTagCount(['古風/古风/古装/武侠/仙侠']);
        expect(result).assertEqual(5);
      })

      it('混合普通 tag 和含 / 的 tag', 0, () => {
        const result = getSemanticTagCount(['R-18', '古風/古风/古装', '原创']);
        expect(result).assertEqual(5);
      })

      it('含空段的字符串不会计入', 0, () => {
        const result = getSemanticTagCount(['a//b', 'c']);
        expect(result).assertEqual(3);
      })

      it('多个含 / 的 tag 累加统计', 0, () => {
        const result = getSemanticTagCount(['a/b/c', 'd/e/f/g', 'h']);
        expect(result).assertEqual(8);
      })
    })

    describe('filterByMaxTags', () => {
      it('maxTags <= 0 应返回原数组（关闭过滤）', 0, () => {
        const items: MockNovel[] = [
          { id: '1', tags: ['a', 'b/c/d/e/f'] },
          { id: '2', tags: ['x'] }
        ];
        const result = filterByMaxTags(items, 0);
        expect(result.length).assertEqual(2);
      })

      it('应过滤掉语义 tag 超过 maxTags 的小说', 0, () => {
        const items: MockNovel[] = [
          { id: '1', tags: ['a/b/c/d/e/f/g/h'] },
          { id: '2', tags: ['a', 'b', 'c'] }
        ];
        const result = filterByMaxTags(items, 5);
        expect(result.length).assertEqual(1);
        expect(result[0].id).assertEqual('2');
      })

      it('边界值：等于 maxTags 应保留', 0, () => {
        const items: MockNovel[] = [
          { id: '1', tags: ['a/b/c'] },
          { id: '2', tags: ['a/b/c/d'] }
        ];
        const result = filterByMaxTags(items, 3);
        expect(result.length).assertEqual(1);
        expect(result[0].id).assertEqual('1');
      })

      it('边界值：大于 maxTags 应过滤', 0, () => {
        const items: MockNovel[] = [
          { id: '1', tags: ['a/b/c/d'] },
          { id: '2', tags: ['a/b/c'] }
        ];
        const result = filterByMaxTags(items, 3);
        expect(result.length).assertEqual(1);
        expect(result[0].id).assertEqual('2');
      })

      it('空数组应返回空数组', 0, () => {
        const result = filterByMaxTags([], 50);
        expect(result.length).assertEqual(0);
      })

      it('没有 tag 的小说应被保留', 0, () => {
        const items: MockNovel[] = [
          { id: '1', tags: [] }
        ];
        const result = filterByMaxTags(items, 50);
        expect(result.length).assertEqual(1);
        expect(result[0].id).assertEqual('1');
      })

      it('默认值 50 下正常小说应保留，盗版应过滤', 0, () => {
        const items: MockNovel[] = [
          { id: 'normal', tags: ['R-18', '原创', '故事'] },
          { id: 'pirated', tags: ['a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z/aa/ab/ac/ad/ae/af/ag/ah/ai/aj/ak/al/am/an/ao/ap/aq/ar/as/at/au/av/aw/ax/ay/az/ba/bb/bc'] }
        ];
        const result = filterByMaxTags(items, 50);
        expect(result.length).assertEqual(1);
        expect(result[0].id).assertEqual('normal');
      })
    })
  })
}
