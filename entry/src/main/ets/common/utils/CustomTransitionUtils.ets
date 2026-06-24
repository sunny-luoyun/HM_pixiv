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

  updateProgress(progress: number): void {
    if (!this.proxy?.updateTransition) {
      return;
    }
    progress = this.operation === NavigationOperation.PUSH ? 1 - progress : progress;
    this.proxy?.updateTransition(progress);
  }

  cancelTransition(): void {
    if (this.proxy?.cancelTransition) {
      this.proxy.cancelTransition();
    }
  }

  recoverState(): void {
    if (!this.proxy?.from.navDestinationId || !this.proxy?.to.navDestinationId) {
      return;
    }
    const fromParam = customTransitionMap.get(this.proxy.from.navDestinationId);
    if (fromParam?.onInteractiveFinish) {
      fromParam.onInteractiveFinish();
    }
    const toParam = customTransitionMap.get(this.proxy.to.navDestinationId);
    if (toParam?.onInteractiveFinish) {
      toParam.onInteractiveFinish();
    }
  }

  finishInteractiveAnimation(rate: number): void {
    if (this.operation === NavigationOperation.PUSH) {
      if (rate > 0.5) {
        if (this.proxy?.cancelTransition) {
          this.proxy.cancelTransition();
        }
      } else {
        this.proxy?.finishTransition();
      }
    } else {
      if (rate > 0.5) {
        this.proxy?.finishTransition();
      } else {
        if (this.proxy?.cancelTransition) {
          this.proxy.cancelTransition();
        }
      }
    }
  }
}
