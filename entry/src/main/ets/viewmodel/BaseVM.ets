import { BaseState } from './BaseState';
import { LoadingModel } from '../models/LoadingModel';

/**
 * ViewModel 事件基类
 */
export class BaseVMEvent {
  type: string;
  param?: object;

  constructor(type: string, param?: object) {
    this.type = type;
    this.param = param;
  }
}

/**
 * ViewModel 抽象基类
 * T: State 类型，必须继承 BaseState
 */
export abstract class BaseVM<T extends BaseState> {
  protected state: T;
  loadState: LoadingModel = new LoadingModel();

  constructor(state: T) {
    this.state = state;
  }

  getState(): T {
    return this.state;
  }

  abstract sendEvent(event: BaseVMEvent): void | Promise<void>;
}
