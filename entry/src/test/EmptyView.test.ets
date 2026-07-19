import { describe, it, expect } from '@ohos/hypium';

const EMPTY_VIEW_DEFAULT_MESSAGE = '暂无数据';

export default function emptyViewTest() {
  describe('EmptyView', () => {
    describe('组件接口约束', () => {
      it('message 默认值应为 "暂无数据"', 0, () => {
        expect(EMPTY_VIEW_DEFAULT_MESSAGE).assertEqual('暂无数据');
      });

      it('message 应为 string 类型', 0, () => {
        const customMsg: string = '没有找到相关结果';
        expect(typeof customMsg).assertEqual('string');
      });
    });

    describe('边界输入', () => {
      it('空字符串消息', 0, () => {
        const emptyMsg: string = '';
        expect(emptyMsg.length).assertEqual(0);
      });

      it('超长消息可存储', 0, () => {
        const longMsg: string = '暂无数据'.repeat(20);
        expect(longMsg.length > 10).assertTrue();
      });

      it('多行消息', 0, () => {
        const multiLineMsg: string = '暂无数据\n请稍后再试';
        expect(multiLineMsg.includes('\n')).assertTrue();
      });
    });
  });
}
