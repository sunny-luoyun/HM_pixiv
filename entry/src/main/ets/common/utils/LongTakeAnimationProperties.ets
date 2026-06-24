import { ComponentAttrUtils } from './ComponentAttrUtils';

@Observed
export class LongTakeAnimationProperties {
  public scaleValue: number = 1;
  public translateX: number = 0;
  public translateY: number = 0;
  public clipWidth: Dimension = '100%';
  public clipHeight: Dimension = '100%';
  public radius: number = 12;
  public snapOpacity: number = 0;
  public contentOpacity: number = 1;
  public snapShotPositionX: number = 0;
  public snapShotPositionY: number = 0;
  public snapShotWidth: number = 0;
  public snapShotHeight: number = 0;

  private initScale: number = 1;
  private initTranslateX: number = 0;
  private initTranslateY: number = 0;
  private initClipWidth: Dimension = '100%';
  private initClipHeight: Dimension = '100%';
  private initSnapX: number = 0;
  private initSnapY: number = 0;
  private initSnapW: number = 0;
  private initSnapH: number = 0;

  private hasValidCard: boolean = false;
  private recoverPrePage: () => void = () => {};
  private animCount: number = 0;
  private screenW: number = 0;
  private screenH: number = 0;

  init(cardId: string, recoverFn: () => void, uiCtx: UIContext,
    screenWidthVp: number, screenHeightVp: number): void {
    this.recoverPrePage = recoverFn;
    this.screenW = screenWidthVp;
    this.screenH = screenHeightVp;
    try {
      const info = ComponentAttrUtils.getRectInfoById(uiCtx, cardId);
      if (info && info.width > 0 && info.height > 0) {
        const cardX = uiCtx.px2vp(info.left);
        const cardY = uiCtx.px2vp(info.top);
        const cardW = uiCtx.px2vp(info.width);
        const cardH = uiCtx.px2vp(info.height);

        this.initScale = cardW / screenWidthVp;
        this.initTranslateX = cardX - (screenWidthVp - cardW) / 2;
        this.initClipWidth = '100%';
        this.initClipHeight = cardH / this.initScale;
        this.initTranslateY = cardY - (uiCtx.px2vp(info.height / this.initScale) - cardH) / 2;

        this.initSnapX = 0;
        this.initSnapY = 0;
        this.initSnapW = cardW / this.initScale;
        this.initSnapH = uiCtx.px2vp(info.height / this.initScale);

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
      this.setFinalStatus();
      transitionProxy.finishTransition();
      return;
    }

    this.scaleValue = this.initScale;
    this.translateX = this.initTranslateX;
    this.translateY = this.initTranslateY;
    this.clipWidth = this.initClipWidth;
    this.clipHeight = this.initClipHeight;
    this.radius = 12;
    this.snapOpacity = 1;
    this.contentOpacity = 0;
    this.snapShotPositionX = this.initSnapX;
    this.snapShotPositionY = this.initSnapY;
    this.snapShotWidth = this.initSnapW;
    this.snapShotHeight = this.initSnapH;

    const id = ++this.animCount;
    const uiCtx = AppStorage.get<UIContext>('uiContext');
    if (!uiCtx) {
      this.setFinalStatus();
      transitionProxy.finishTransition();
      return;
    }

    uiCtx.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        if (id === this.animCount) {
          this.radius = 0;
        }
        transitionProxy.finishTransition();
      }
    }, () => {
      this.scaleValue = 1;
      this.translateX = 0;
      this.translateY = 0;
      this.clipWidth = '100%';
      this.clipHeight = '100%';
      this.radius = 34;
    });

    uiCtx.animateTo({
      delay: 50,
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.snapOpacity = 0;
    });

    uiCtx.animateTo({
      duration: 100,
      curve: Curve.Sharp
    }, () => {
      this.contentOpacity = 1;
    });
  }

  doBackAnimation(transitionProxy?: NavigationTransitionProxy): void {
    if (!this.hasValidCard) {
      this.snapOpacity = 0;
      this.contentOpacity = 1;
      this.recoverPrePage();
      transitionProxy?.finishTransition();
      return;
    }

    this.snapShotPositionX = this.initSnapX;
    this.snapShotPositionY = this.initSnapY;
    this.snapShotWidth = this.initSnapW;
    this.snapShotHeight = this.initSnapH;

    ++this.animCount;
    const uiCtx = AppStorage.get<UIContext>('uiContext');
    if (!uiCtx) {
      this.recoverPrePage();
      transitionProxy?.finishTransition();
      return;
    }

    uiCtx.animateTo({
      duration: 350,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.recoverPrePage();
        transitionProxy?.finishTransition();
      }
    }, () => {
      this.scaleValue = this.initScale;
      this.translateX = this.initTranslateX;
      this.translateY = this.initTranslateY;
      this.clipWidth = this.initClipWidth;
      this.clipHeight = this.initClipHeight;
      this.radius = 12;
    });

    uiCtx.animateTo({
      duration: 50,
      delay: 150,
      curve: Curve.Friction
    }, () => {
      this.snapOpacity = 1;
    });

    uiCtx.animateTo({
      duration: 50,
      delay: 200,
      curve: Curve.Friction
    }, () => {
      this.contentOpacity = 0;
    });
  }

  setFinalStatus(): void {
    this.scaleValue = 1;
    this.translateX = 0;
    this.translateY = 0;
    this.clipWidth = '100%';
    this.clipHeight = '100%';
    this.radius = 0;
    this.snapOpacity = 0;
    this.contentOpacity = 1;
  }
}
