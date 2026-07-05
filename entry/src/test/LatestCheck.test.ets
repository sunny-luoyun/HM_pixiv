import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';

interface TestWork {
  id: string;
  title: string;
  userName: string;
}

function findNewWorks(works: TestWork[], storedIds: string[], firstCheckDone: boolean): TestWork[] {
  if (!firstCheckDone || storedIds.length === 0) return [];
  const storedSet = new Set(storedIds);
  return works.filter((w) => !storedSet.has(w.id));
}

export default function latestCheckTest() {
  describe('LatestCheckTest', () => {
    it('首次检查不返回新作品', 0, () => {
      const works: TestWork[] = [
        { id: '1', title: 'A', userName: 'u1' },
        { id: '2', title: 'B', userName: 'u2' },
      ];
      const result = findNewWorks(works, [], false);
      expect(result.length).assertEqual(0);
    });

    it('无新作品时返回空', 0, () => {
      const works: TestWork[] = [
        { id: '1', title: 'A', userName: 'u1' },
        { id: '2', title: 'B', userName: 'u2' },
      ];
      const storedIds = ['1', '2'];
      const result = findNewWorks(works, storedIds, true);
      expect(result.length).assertEqual(0);
    });

    it('发现新作品正确返回', 0, () => {
      const works: TestWork[] = [
        { id: '1', title: 'A', userName: 'u1' },
        { id: '2', title: 'B', userName: 'u2' },
        { id: '3', title: 'C', userName: 'u3' },
      ];
      const storedIds = ['1', '2'];
      const result = findNewWorks(works, storedIds, true);
      expect(result.length).assertEqual(1);
      expect(result[0].id).assertEqual('3');
      expect(result[0].title).assertEqual('C');
    });

    it('多个新作品全部返回', 0, () => {
      const works: TestWork[] = [
        { id: '1', title: 'A', userName: 'u1' },
        { id: '2', title: 'B', userName: 'u2' },
        { id: '3', title: 'C', userName: 'u3' },
        { id: '4', title: 'D', userName: 'u4' },
      ];
      const storedIds = ['1'];
      const result = findNewWorks(works, storedIds, true);
      expect(result.length).assertEqual(3);
    });

    it('空作品列表返回空', 0, () => {
      const works: TestWork[] = [];
      const storedIds: string[] = [];
      const result = findNewWorks(works, storedIds, true);
      expect(result.length).assertEqual(0);
    });

    it('未完成首次检查时不返回', 0, () => {
      const works: TestWork[] = [
        { id: '1', title: 'A', userName: 'u1' },
      ];
      const result = findNewWorks(works, [], false);
      expect(result.length).assertEqual(0);
    });
  });
}
