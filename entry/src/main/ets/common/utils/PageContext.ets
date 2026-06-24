/**
 * NavPathStack 封装，替代 router.pushUrl/replaceUrl/back
 * 配合 Navigation 组件使用
 */
export class PageContext {
  private pathStack: NavPathStack;

  constructor(stack: NavPathStack) {
    this.pathStack = stack;
  }

  openPage(name: string, param?: Object, animated: boolean = true): void {
    this.pathStack.pushPath({ name, param } as NavPathInfo, animated);
    this.syncStackSize();
  }

  popPage(animated: boolean = true): void {
    this.pathStack.pop(animated);
    this.syncStackSize();
  }

  replacePage(name: string, param?: Object, animated: boolean = true): void {
    this.pathStack.replacePath({ name, param } as NavPathInfo, animated);
    this.syncStackSize();
  }

  popToRoot(animated: boolean = true): void {
    this.pathStack.clear(animated);
    this.syncStackSize();
  }

  getNavPathStack(): NavPathStack {
    return this.pathStack;
  }

  private syncStackSize(): void {
    AppStorage.setOrCreate('navStackSize', this.pathStack.size());
  }
}
