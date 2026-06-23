import { CustomTransition } from './CustomTransitionUtils';
import { BusinessError } from '@kit.BasicServicesKit';

@Observed
export class LongTakeAnimationProperties {
  // UI bindable state
  public containerWidth: number = 0;
  public containerHeight: number = 0;
  public positionX: number = 0;
  public positionY: number = 0;
  public snapOpacity: number = 1;
  public contentOpacity: number = 0;
  public radius: number = 12;

  // Internal initial values (card position/size in vp)
  private initW: number = 0;
  private initH: number = 0;
  private initX: number = 0;
  private initY: number = 0;
  private screenW: number = 0;
  private screenH: number = 0;
  private hasValidCard: boolean = false;
  private recoverPrePage: () => void = () => {};
  private animCount: number = 0;

  init(cardId: string, recoverFn: () => void, uiCtx: UIContext,
    screenWidthVp: number, screenHeightVp: number): void {
    this.recoverPrePage = recoverFn;
    this.screenW = screenWidthVp;
    this.screenH = screenHeightVp;
    try {
      const info = uiCtx.getComponentUtils().getRectangleById(cardId);
      if (info) {
        this.initX = uiCtx.px2vp(info.screenOffset.x + info.translate.x);
        this.initY = uiCtx.px2vp(info.screenOffset.y + info.translate.y);
        this.initW = uiCtx.px2vp(info.size.width);
        this.initH = uiCtx.px2vp(info.size.height);
        this.hasValidCard = true;
        return;
      }
    } catch (err) {
      console.error('LongTakeAnimationProperties init error:', err);
    }
    this.hasValidCard = false;
  }

  doEnterAnimation(transitionProxy: NavigationTransitionProxy): void {
    if (!this.hasValidCard) {
      transitionProxy.finishTransition();
      return;
    }

    this.containerWidth = this.initW;
    this.containerHeight = this.initH;
    this.positionX = this.initX;
    this.positionY = this.initY;
    this.snapOpacity = 1;
    this.contentOpacity = 0;
    this.radius = 12;

    const id = ++this.animCount;
    const uiCtx = AppStorage.get<UIContext>('uiContext');
    if (!uiCtx) {
      this.setFinalStatus();
      transitionProxy.finishTransition();
      return;
    }

    uiCtx.animateTo({
      duration: 350,
      curve: Curve.Friction,
      onFinish: () => {
        this.setFinalStatus();
        transitionProxy.finishTransition();
      }
    }, () => {
      this.containerWidth = this.screenW;
      this.containerHeight = this.screenH;
      this.positionX = 0;
      this.positionY = 0;
      this.radius = 0;
      this.snapOpacity = 0;
      this.contentOpacity = 1;
    });
  }

  doBackAnimation(transitionProxy?: NavigationTransitionProxy): void {
    if (!this.hasValidCard) {
      this.recoverPrePage();
      transitionProxy?.finishTransition();
      return;
    }

    ++this.animCount;
    const uiCtx = AppStorage.get<UIContext>('uiContext');
    if (!uiCtx) {
      this.recoverPrePage();
      transitionProxy?.finishTransition();
      return;
    }

    uiCtx.animateTo({
      duration: 300,
      curve: Curve.Friction,
      onFinish: () => {
        this.recoverPrePage();
        transitionProxy?.finishTransition();
      }
    }, () => {
      this.containerWidth = this.initW;
      this.containerHeight = this.initH;
      this.positionX = this.initX;
      this.positionY = this.initY;
      this.radius = 12;
      this.snapOpacity = 1;
      this.contentOpacity = 0;
    });
  }

  setFinalStatus(): void {
    this.containerWidth = this.screenW;
    this.containerHeight = this.screenH;
    this.positionX = 0;
    this.positionY = 0;
    this.radius = 0;
    this.snapOpacity = 0;
    this.contentOpacity = 1;
  }
}
