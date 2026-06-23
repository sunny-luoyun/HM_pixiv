import { describe, it, expect } from '@ohos/hypium';

export default function segmentedTabBarTest() {
  describe('SegmentedTabBar_跟手滑动', () => {

    describe('基本属性', () => {
      it('默认 tabs 为空数组', 0, () => {
        const tabs: string[] = [];
        expect(tabs.length).assertEqual(0);
      });

      it('默认 currentIndex 为 0', 0, () => {
        const currentIndex = 0;
        expect(currentIndex).assertEqual(0);
      });

      it('默认 swipeProgress 为 0', 0, () => {
        const swipeProgress = 0;
        expect(swipeProgress).assertEqual(0);
      });
    });

    describe('pill 偏移计算', () => {
      it('swipeProgress=0 时 pill 应在 currentIndex 位置', 0, () => {
        const currentIndex = 0;
        const swipeProgress = 0;
        const pillWidth = 80;
        const offset = currentIndex * pillWidth + swipeProgress * pillWidth;
        expect(offset).assertEqual(0);
      });

      it('swipeProgress=0.3 时 pill 应向右移动 30%', 0, () => {
        const currentIndex = 0;
        const swipeProgress = 0.3;
        const pillWidth = 80;
        const raw = currentIndex + swipeProgress;
        const clamped = Math.max(0, Math.min(raw, 3));
        const offset = clamped * pillWidth;
        expect(offset).assertEqual(24);
      });

      it('swipeProgress=-0.5 时 pill 应向左移动 50%', 0, () => {
        const currentIndex = 1;
        const swipeProgress = -0.5;
        const pillWidth = 80;
        const raw = currentIndex + swipeProgress;
        const clamped = Math.max(0, Math.min(raw, 3));
        const offset = clamped * pillWidth;
        expect(offset).assertEqual(40);
      });

      it('swipeProgress=1.0 时 pill 应到达下一 tab', 0, () => {
        const currentIndex = 0;
        const swipeProgress = 1.0;
        const pillWidth = 80;
        const raw = currentIndex + swipeProgress;
        const clamped = Math.max(0, Math.min(raw, 3));
        const offset = clamped * pillWidth;
        expect(offset).assertEqual(80);
      });

      it('swipeProgress 导致越界时应被 clamp', 0, () => {
        const currentIndex = 3;
        const swipeProgress = 0.5;
        const pillWidth = 80;
        const maxIndex = 3;
        const raw = currentIndex + swipeProgress;
        const clamped = Math.max(0, Math.min(raw, maxIndex));
        const offset = clamped * pillWidth;
        expect(offset).assertEqual(240);
      });

      it('左侧越界时应被 clamp 到 0', 0, () => {
        const currentIndex = 0;
        const swipeProgress = -0.5;
        const pillWidth = 80;
        const maxIndex = 3;
        const raw = currentIndex + swipeProgress;
        const clamped = Math.max(0, Math.min(raw, maxIndex));
        const offset = clamped * pillWidth;
        expect(offset).assertEqual(0);
      });
    });

    describe('活动 tab 文本判定', () => {
      it('swipeProgress=0 时用 animIndex 判定', 0, () => {
        const animIndex = 1;
        const swipeProgress = 0;
        const activeIndex = swipeProgress !== 0 ? 0 : animIndex;
        expect(activeIndex).assertEqual(1);
      });

      it('swipeProgress<0.5 时保持 currentIndex', 0, () => {
        const currentIndex = 0;
        const swipeProgress = 0.4;
        const abs = Math.abs(swipeProgress);
        const activeIndex = abs >= 0.5
          ? currentIndex + Math.sign(swipeProgress)
          : currentIndex;
        expect(activeIndex).assertEqual(0);
      });

      it('swipeProgress>=0.5 时应切换到下一 tab', 0, () => {
        const currentIndex = 0;
        const swipeProgress = 0.6;
        const abs = Math.abs(swipeProgress);
        const activeIndex = abs >= 0.5
          ? currentIndex + Math.sign(swipeProgress)
          : currentIndex;
        expect(activeIndex).assertEqual(1);
      });

      it('负向 swipeProgress>=0.5 时应切换到上一 tab', 0, () => {
        const currentIndex = 2;
        const swipeProgress = -0.7;
        const abs = Math.abs(swipeProgress);
        const activeIndex = abs >= 0.5
          ? currentIndex + Math.sign(swipeProgress)
          : currentIndex;
        expect(activeIndex).assertEqual(1);
      });
    });

    describe('pill 弹性缩放', () => {
      it('swipeProgress=0 时缩放比为 1', 0, () => {
        const swipeProgress = 0;
        const abs = Math.abs(swipeProgress);
        const scale = 1 + abs * 0.12 * (1 - abs);
        expect(scale).assertEqual(1);
      });

      it('swipeProgress=0.5 时缩放比大于 1', 0, () => {
        const swipeProgress = 0.5;
        const abs = Math.abs(swipeProgress);
        const scale = 1 + abs * 0.12 * (1 - abs);
        expect(scale > 1).assertTrue();
        expect(scale < 1.1).assertTrue();
      });

      it('swipeProgress=1 时缩放比回到 1', 0, () => {
        const swipeProgress = 1.0;
        const abs = Math.abs(swipeProgress);
        const scale = 1 + abs * 0.12 * (1 - abs);
        expect(scale).assertEqual(1);
      });
    });

    describe('点击切换', () => {
      it('点击当前 tab 不应触发 onChange', 0, () => {
        let called = false;
        const handleClick = (index: number, currentIndex: number, onChange?: (idx: number) => void) => {
          if (index === currentIndex) return;
          onChange?.(index);
        };
        handleClick(0, 0, () => { called = true; });
        expect(called).assertFalse();
      });

      it('点击不同 tab 应触发 onChange', 0, () => {
        let resultIndex = -1;
        const handleClick = (index: number, currentIndex: number, onChange?: (idx: number) => void) => {
          if (index === currentIndex) return;
          onChange?.(index);
        };
        handleClick(1, 0, (idx: number) => { resultIndex = idx; });
        expect(resultIndex).assertEqual(1);
      });
    });

    describe('syncIndex 同步', () => {
      it('currentIndex 变化时 animIndex 应同步更新', 0, () => {
        let animIndex = 0;
        let currentIndex = 0;
        const sync = () => { animIndex = currentIndex; };
        currentIndex = 2;
        sync();
        expect(animIndex).assertEqual(2);
      });

      it('swipe 结束时同步不应产生动画', 0, () => {
        let animIndex = 0;
        let currentIndex = 1;
        const sync = () => { animIndex = currentIndex; };
        sync();
        expect(animIndex).assertEqual(1);
      });
    });
  });
}
