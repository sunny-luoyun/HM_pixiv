import { describe, it, expect } from '@ohos/hypium';
import {
  resolveBreakpoint,
  getColumnCount,
  getColumnsTemplate,
  getNovelColumnsTemplate,
} from '../main/ets/common/utils/BreakpointManager';

export default function breakpointManagerTest() {
  describe('BreakpointManager', () => {
    describe('resolveBreakpoint', () => {
      it('宽度为 0 应返回 "xs"', 0, () => {
        expect(resolveBreakpoint(0)).assertEqual('xs');
      });

      it('宽度 319 应返回 "xs"', 0, () => {
        expect(resolveBreakpoint(319)).assertEqual('xs');
      });

      it('宽度 320 应返回 "sm"', 0, () => {
        expect(resolveBreakpoint(320)).assertEqual('sm');
      });

      it('宽度 599 应返回 "sm"', 0, () => {
        expect(resolveBreakpoint(599)).assertEqual('sm');
      });

      it('宽度 600 应返回 "md"', 0, () => {
        expect(resolveBreakpoint(600)).assertEqual('md');
      });

      it('宽度 839 应返回 "md"', 0, () => {
        expect(resolveBreakpoint(839)).assertEqual('md');
      });

      it('宽度 840 应返回 "lg"', 0, () => {
        expect(resolveBreakpoint(840)).assertEqual('lg');
      });

      it('宽度 1439 应返回 "lg"', 0, () => {
        expect(resolveBreakpoint(1439)).assertEqual('lg');
      });

      it('宽度 1440 应返回 "xl"', 0, () => {
        expect(resolveBreakpoint(1440)).assertEqual('xl');
      });

      it('宽度 2000 应返回 "xl"（BP_MIN 无 xxl 阈值）', 0, () => {
        expect(resolveBreakpoint(2000)).assertEqual('xl');
      });
    });

    describe('getColumnCount', () => {
      it('xs 为 2 列', 0, () => {
        expect(getColumnCount('xs')).assertEqual(2);
      });

      it('sm 为 2 列', 0, () => {
        expect(getColumnCount('sm')).assertEqual(2);
      });

      it('md 为 4 列', 0, () => {
        expect(getColumnCount('md')).assertEqual(4);
      });

      it('lg 为 4 列', 0, () => {
        expect(getColumnCount('lg')).assertEqual(4);
      });

      it('xl 为 6 列', 0, () => {
        expect(getColumnCount('xl')).assertEqual(6);
      });

      it('xxl 为 6 列', 0, () => {
        expect(getColumnCount('xxl')).assertEqual(6);
      });

      it('未知断点默认 2 列', 0, () => {
        expect(getColumnCount('unknown')).assertEqual(2);
      });
    });

    describe('getColumnsTemplate', () => {
      it('xs 为 "1fr 1fr"', 0, () => {
        expect(getColumnsTemplate('xs')).assertEqual('1fr 1fr');
      });

      it('md 为 "1fr 1fr 1fr 1fr"', 0, () => {
        expect(getColumnsTemplate('md')).assertEqual('1fr 1fr 1fr 1fr');
      });

      it('xxl 为 "1fr 1fr 1fr 1fr 1fr 1fr"', 0, () => {
        expect(getColumnsTemplate('xxl')).assertEqual('1fr 1fr 1fr 1fr 1fr 1fr');
      });
    });

    describe('getNovelColumnsTemplate', () => {
      it('xs 为 "1fr"（单栏）', 0, () => {
        expect(getNovelColumnsTemplate('xs')).assertEqual('1fr');
      });

      it('sm 为 "1fr"', 0, () => {
        expect(getNovelColumnsTemplate('sm')).assertEqual('1fr');
      });

      it('md 为 "1fr"', 0, () => {
        expect(getNovelColumnsTemplate('md')).assertEqual('1fr');
      });

      it('lg 为 "1fr 1fr"（双栏）', 0, () => {
        expect(getNovelColumnsTemplate('lg')).assertEqual('1fr 1fr');
      });

      it('xl 为 "1fr 1fr"', 0, () => {
        expect(getNovelColumnsTemplate('xl')).assertEqual('1fr 1fr');
      });

      it('xxl 为 "1fr 1fr"', 0, () => {
        expect(getNovelColumnsTemplate('xxl')).assertEqual('1fr 1fr');
      });
    });
  });
}
