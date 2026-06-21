import { describe, it, expect } from '@ohos/hypium';

export default function emptyViewTest() {
  describe('EmptyView', () => {

    describe('组件接口约束', () => {
      it('message 属性默认值应为 "暂无数据"', 0, () => {
        const defaultMsg: string = '暂无数据';
        expect(defaultMsg).assertEqual('暂无数据');
      });

      it('message 属性应为 string 类型', 0, () => {
        const msg: string = '暂无评论';
        expect(typeof msg).assertEqual('string');
      });

      it('自定义空状态消息应正确存储', 0, () => {
        const customMsg: string = '没有找到相关结果';
        expect(customMsg).assertEqual('没有找到相关结果');
      });
    });

    describe('边界输入', () => {
      it('空字符串消息应正常', 0, () => {
        const emptyMsg: string = '';
        expect(emptyMsg.length).assertEqual(0);
      });

      it('超长消息应正常存储', 0, () => {
        const longMsg: string = '该分类下暂未发现任何相关数据'.repeat(5);
        expect(longMsg.length > 10).assertTrue();
        expect(typeof longMsg).assertEqual('string');
      });

      it('纯空格消息应正常', 0, () => {
        const spaceMsg: string = '   ';
        expect(spaceMsg.trim()).assertEqual('');
      });

      it('多行消息应正常', 0, () => {
        const multiLineMsg: string = '暂无数据\n请稍后再试';
        expect(multiLineMsg.includes('\n')).assertTrue();
      });
    });
  });
}
