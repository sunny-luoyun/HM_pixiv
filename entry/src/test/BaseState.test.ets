import { describe, it, expect } from '@ohos/hypium';
import { BaseState } from '../main/ets/viewmodel/BaseState';

export default function baseStateTest() {
  describe('BaseState', () => {
    it('可实例化', 0, () => {
      const state = new BaseState();
      expect(state !== null).assertTrue();
    });

    it('instanceof 正确', 0, () => {
      const state = new BaseState();
      expect(state instanceof BaseState).assertTrue();
    });
  });
}
