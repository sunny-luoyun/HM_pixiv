import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { BaseVM, BaseVMEvent } from '../main/ets/viewmodel/BaseVM';
import { BaseState } from '../main/ets/viewmodel/BaseState';
import { LoadingModel } from '../main/ets/models/LoadingModel';

class TestState extends BaseState {
  value: number = 0;
}

interface SetValueParam {
  value: number;
}

class TestVM extends BaseVM<TestState> {
  eventReceived: string = '';

  constructor() {
    super(new TestState());
  }

  sendEvent(event: BaseVMEvent): void {
    this.eventReceived = event.type;
    if (event.type === 'SET_VALUE') {
      const p = event.param as Record<string, number>;
      this.state.value = p['value'] ?? 0;
    }
  }
}

export default function baseVMTest() {
  describe('BaseVM', () => {
    let vm: TestVM;

    beforeEach(() => {
      vm = new TestVM();
    });

    it('getState_should_return_state', 0, () => {
      const state = vm.getState();
      expect(state !== null).assertTrue();
      expect(state.value).assertEqual(0);
    });

    it('sendEvent_should_dispatch_event', 0, () => {
      const param: SetValueParam = { value: 42 };
      vm.sendEvent(new BaseVMEvent('SET_VALUE', param));
      expect(vm.eventReceived).assertEqual('SET_VALUE');
      expect(vm.getState().value).assertEqual(42);
    });

    it('should_have_loadState', 0, () => {
      expect(vm.loadState !== null).assertTrue();
    });
  });
}
