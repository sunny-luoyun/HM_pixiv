import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { CustomTransition } from '../main/ets/common/utils/CustomTransitionUtils';
import { SnapShotImage } from '../main/ets/common/utils/SnapShotImage';

export default function customTransitionTest() {
  describe('CustomTransition', () => {
    it('getInstance_should_return_same_instance', 0, () => {
      const instance1 = CustomTransition.getInstance();
      const instance2 = CustomTransition.getInstance();
      expect(instance1 === instance2).assertTrue();
    });

    it('register_and_get_animate_param', 0, () => {
      const ct = CustomTransition.getInstance();
      const mockFn = () => {};
      ct.registerNavParam('testPage', 1000, mockFn);
      const param = ct.getAnimateParam('testPage');
      expect(param.animation === mockFn).assertTrue();
      expect(param.timeout).assertEqual(1000);
      ct.unRegisterNavParam('testPage');
    });

    it('unregister_should_remove_param', 0, () => {
      const ct = CustomTransition.getInstance();
      ct.registerNavParam('testPage2', 500);
      ct.unRegisterNavParam('testPage2');
      const param = ct.getAnimateParam('testPage2');
      expect(param.animation === undefined).assertTrue();
    });

    it('register_update_existing_param', 0, () => {
      const ct = CustomTransition.getInstance();
      const fn1 = () => {};
      const fn2 = () => {};
      ct.registerNavParam('testPage3', 500, fn1);
      ct.registerNavParam('testPage3', 1000, fn2);
      const param = ct.getAnimateParam('testPage3');
      expect(param.animation === fn2).assertTrue();
      expect(param.timeout).assertEqual(1000);
      ct.unRegisterNavParam('testPage3');
    });

    it('get_unregistered_name_should_return_empty_object', 0, () => {
      const ct = CustomTransition.getInstance();
      const param = ct.getAnimateParam('nonexistent');
      expect(param.animation === undefined).assertTrue();
      expect(param.timeout === undefined).assertTrue();
    });
  });

  describe('SnapShotImage', () => {
    it('pixelMap_should_be_undefined_initially', 0, () => {
      expect(SnapShotImage.pixelMap === undefined).assertTrue();
    });
  });
}
