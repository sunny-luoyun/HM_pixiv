import { describe, it, expect } from '@ohos/hypium';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    it('assertContain 基本断言可用', 0, () => {
      let a = 'abc';
      let b = 'b';
      expect(a).assertContain(b);
      expect(a).assertEqual(a);
    });

    it('expect 基本类型断言', 0, () => {
      expect(1 + 1).assertEqual(2);
      expect(true).assertTrue();
      expect(false).assertFalse();
    });
  });
}
