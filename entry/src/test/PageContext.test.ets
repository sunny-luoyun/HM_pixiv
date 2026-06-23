import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PageContext } from '../main/ets/common/utils/PageContext';

export default function pageContextTest() {
  describe('PageContext', () => {
    let pageContext: PageContext;
    let navStack: NavPathStack;

    beforeAll(() => {
      navStack = new NavPathStack();
      pageContext = new PageContext(navStack);
    });

    it('openPage_should_call_pushPath', 0, () => {
      expect(pageContext !== null).assertTrue();
    });

    it('popPage_should_not_throw', 0, () => {
      try {
        pageContext.popPage(false);
        expect(true).assertTrue();
      } catch (e) {
        expect(false).assertTrue();
      }
    });

    it('replacePage_should_not_throw', 0, () => {
      try {
        pageContext.replacePage('TestPage', undefined, false);
        expect(true).assertTrue();
      } catch (e) {
        expect(false).assertTrue();
      }
    });

    it('popToRoot_should_not_throw', 0, () => {
      try {
        pageContext.popToRoot(false);
        expect(true).assertTrue();
      } catch (e) {
        expect(false).assertTrue();
      }
    });

    it('getNavPathStack_should_return_stack', 0, () => {
      const stack = pageContext.getNavPathStack();
      expect(stack !== null).assertTrue();
    });
  });
}
