export enum ScrollHeaderAction {
  NONE = 0,
  SHOW = 1,
  HIDE = 2
}

export class ScrollHeaderManager {
  private readonly hideDeltaThreshold: number = 12;
  private readonly showDeltaThreshold: number = 15;
  private readonly scrollDeadZone: number = 20;
  private readonly cooldownMs: number = 350;
  private readonly reachStartCooldownMs: number = 500;
  private readonly reachStartLastYGuard: number = 50;

  private tabLastY: number[] = [];
  private lastShowTime: number = 0;
  private lastHideTime: number = 0;

  onScroll(tabIndex: number, yOffset: number, isHeaderVisible: boolean): ScrollHeaderAction {
    this.ensureTab(tabIndex);
    const delta = yOffset - this.tabLastY[tabIndex];
    this.tabLastY[tabIndex] = yOffset;

    const now = Date.now();

    if (delta > this.hideDeltaThreshold && isHeaderVisible && yOffset > this.scrollDeadZone) {
      if (now - this.lastShowTime < this.cooldownMs) {
        return ScrollHeaderAction.NONE;
      }
      this.lastHideTime = now;
      return ScrollHeaderAction.HIDE;
    }

    if (delta < -this.showDeltaThreshold && !isHeaderVisible && yOffset > this.scrollDeadZone) {
      if (now - this.lastHideTime < this.cooldownMs) {
        return ScrollHeaderAction.NONE;
      }
      this.lastShowTime = now;
      return ScrollHeaderAction.SHOW;
    }

    return ScrollHeaderAction.NONE;
  }

  onReachStart(isHeaderVisible: boolean): ScrollHeaderAction {
    if (isHeaderVisible) {
      return ScrollHeaderAction.NONE;
    }
    for (let i = 0; i < this.tabLastY.length; i++) {
      if (this.tabLastY[i] > this.reachStartLastYGuard) {
        return ScrollHeaderAction.NONE;
      }
    }
    const now = Date.now();
    if (now - this.lastShowTime < this.reachStartCooldownMs) {
      return ScrollHeaderAction.NONE;
    }
    if (now - this.lastHideTime < this.reachStartCooldownMs) {
      return ScrollHeaderAction.NONE;
    }
    this.lastShowTime = now;
    return ScrollHeaderAction.SHOW;
  }

  onTabChange(newTabIndex: number): void {
    this.ensureTab(newTabIndex);
    this.tabLastY[newTabIndex] = 0;
  }

  private ensureTab(tabIndex: number): void {
    while (this.tabLastY.length <= tabIndex) {
      this.tabLastY.push(0);
    }
  }
}
