export interface AnimateCallback {
  animation?: (transitionProxy: NavigationTransitionProxy) => void;
  timeout?: number;
  onInteractiveFinish?: () => void;
  onInteractive?: () => void;
}

const customTransitionMap: Map<string, AnimateCallback> = new Map();

export class CustomTransition {
  static delegate = new CustomTransition();
  isInteractive: boolean = false;
  proxy?: NavigationTransitionProxy = undefined;
  operation: NavigationOperation = NavigationOperation.PUSH;

  static getInstance(): CustomTransition {
    return CustomTransition.delegate;
  }

  registerNavParam(name: string, timeout: number,
    animation?: (transitionProxy: NavigationTransitionProxy) => void,
    onInteractiveFinish?: () => void,
    onInteractive?: () => void): void {
    if (customTransitionMap.has(name)) {
      const param = customTransitionMap.get(name)!;
      param.animation = animation;
      param.timeout = timeout;
      param.onInteractiveFinish = onInteractiveFinish;
      param.onInteractive = onInteractive;
      return;
    }
    customTransitionMap.set(name, {
      animation,
      timeout,
      onInteractiveFinish,
      onInteractive
    });
  }

  unRegisterNavParam(name: string): void {
    customTransitionMap.delete(name);
  }

  getAnimateParam(name: string): AnimateCallback {
    const result = customTransitionMap.get(name);
    if (result) {
      return result;
    }
    return {};
  }
}
