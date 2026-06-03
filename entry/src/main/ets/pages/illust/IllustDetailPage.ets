import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { PixivService, IllustDetailBody } from '../../services/PixivService';

@Entry
@Component
struct IllustDetailPage {
  @State illustId: string = '';
  @State thumbnailLocalUrl: string = '';
  @State detail: IllustDetailBody | null = null;
  @State isLoading: boolean = true;
  @State errorMsg: string = '';
  @State localImageUrls: string[] = [];
  @State currentIndex: number = 0;
  @State pageRegularUrls: string[] = [];
  @State isDownloading: boolean = false;
  @State downloadSuccess: boolean = false;
  @State downloadFail: boolean = false;
  @State illustPageCount: number = 1;
  @State isActive: boolean = false;

  @State isBookmarked: boolean = false;
  @State isBookmarkLoading: boolean = false;
  @State scaleValue: number = 1;
  @State translateX: number = 0;
  @State translateY: number = 0;
  @State private screenWidth: number = 0;
  @State private screenHeight: number = 0;
  private baseScale: number = 1;
  private baseTranslateX: number = 0;
  private baseTranslateY: number = 0;
  private lastTouchX: number = -1;
  private lastTouchY: number = -1;
  private swiperController: SwiperController = new SwiperController();

  get pageCount(): number {
    return this.detail?.pageCount ?? 1;
  }

  async aboutToAppear() {
    this.isActive = true;
    const params = router.getParams() as Record<string, Object>;
    this.illustId = params['id'] as string;
    this.thumbnailLocalUrl = params['thumbnailLocalUrl'] as string || '';
    if (!this.illustId) {
      this.errorMsg = '缺少插图ID';
      this.isLoading = false;
      return;
    }
    if (this.thumbnailLocalUrl) {
      this.localImageUrls = [this.thumbnailLocalUrl];
      this.illustPageCount = 1;
    }
    const defaultDisplay = display.getDefaultDisplaySync();
    this.screenWidth = px2vp(defaultDisplay.width);
    this.screenHeight = px2vp(defaultDisplay.height);
    await this.loadDetail();
  }

  aboutToDisappear() {
    this.isActive = false;
    PixivService.cancelDownloadGroup(`detail_${this.illustId}`);
  }

  async loadDetail() {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const res = await PixivService.getIllustDetail(this.illustId);
      if (!this.isActive) return;
      if (!res.error && res.body) {
        this.detail = res.body;
        this.isBookmarked = !!res.body.bookmarkData;
        const pageCount = res.body.pageCount;
        this.illustPageCount = pageCount;
        const urls = PixivService.generatePageUrls(res.body.urls.regular, pageCount);
        this.pageRegularUrls = urls;

        const newUrls = new Array<string>(pageCount).fill('');
        if (this.thumbnailLocalUrl) {
          newUrls[0] = this.thumbnailLocalUrl;
        }
        this.localImageUrls = newUrls;
        this.isLoading = false;

        const illustId = res.body.illustId;
        const groupId = `detail_${illustId}`;
        urls.forEach((url, i) => {
          PixivService.cacheImage(url, `illust_${illustId}_pg${i}.jpg`, groupId)
            .then((path) => {
              if (this.isActive && path) {
                const updated = [...this.localImageUrls];
                updated[i] = path;
                this.localImageUrls = updated;
              }
            })
            .catch(() => {});
        });
      } else {
        this.errorMsg = res.message || '获取详情失败';
        this.isLoading = false;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('获取插画详情失败:', err);
      this.errorMsg = '加载失败，请检查网络';
      this.isLoading = false;
    }
  }

  async handleDownload() {
    if (!this.detail || this.isDownloading) return;
    if (this.currentIndex >= this.pageRegularUrls.length) {
      console.error('handleDownload: 页码超出范围');
      this.downloadFail = true;
      return;
    }
    this.isDownloading = true;
    this.downloadSuccess = false;
    this.downloadFail = false;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.WRITE_IMAGEVIDEO'];
      const result = await atManager.requestPermissionsFromUser(ctx, permissions);
      const granted = result.authResults.every(r => r === 0);
      if (!granted) {
        console.error('用户未授予相册写入权限');
        this.downloadFail = true;
        this.isDownloading = false;
        return;
      }
      const localUrl = this.localImageUrls[this.currentIndex];
      const ok = await PixivService.saveImageToGallery(
        ctx,
        localUrl,
        `illust_${this.detail.illustId}_p${this.currentIndex}.jpg`
      );
      if (ok) {
        this.downloadSuccess = true;
      } else {
        this.downloadFail = true;
      }
    } catch (err) {
      console.error('下载失败:', err);
      this.downloadFail = true;
    }
    this.isDownloading = false;
  }

  async toggleBookmark() {
    if (this.isBookmarkLoading) return;
    this.isBookmarkLoading = true;
    try {
      if (this.isBookmarked) {
        await PixivService.deleteIllustBookmark(this.illustId);
        this.isBookmarked = false;
      } else {
        await PixivService.addIllustBookmark(this.illustId, 'public', []);
        this.isBookmarked = true;
      }
    } catch (err) {
      promptAction.showToast({ message: '操作失败: ' + String(err) });
    }
    this.isBookmarkLoading = false;
  }

  resetZoom() {
    this.scaleValue = 1;
    this.translateX = 0;
    this.translateY = 0;
  }

  clampTranslate() {
    if (this.scaleValue <= 1) {
      this.translateX = 0;
      this.translateY = 0;
      return;
    }
    const maxX = (this.scaleValue - 1) * this.screenWidth / 2;
    const maxY = (this.scaleValue - 1) * this.screenHeight / 2;
    this.translateX = Math.max(-maxX, Math.min(maxX, this.translateX));
    this.translateY = Math.max(-maxY, Math.min(maxY, this.translateY));
  }

  build() {
    Column() {
      if (this.errorMsg) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button('重试').margin({ top: 12 }).onClick(() => this.loadDetail())
          Button('返回').margin({ top: 8 }).onClick(() => router.back())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.thumbnailLocalUrl || (this.detail && this.localImageUrls.length > 0)) {
        Stack() {
          Swiper(this.swiperController) {
            ForEach(this.localImageUrls, (url: string, index: number) => {
              if (url) {
                Image(url)
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
                  .sharedTransition(index === 0 ? 'illust_' + this.illustId : '', {
                    duration: 350,
                    curve: Curve.Friction
                  })
                  .scale({ x: this.scaleValue, y: this.scaleValue })
                  .translate({ x: this.translateX, y: this.translateY })
                  .gesture(
                    GestureGroup(GestureMode.Parallel,
                      PinchGesture()
                        .onActionStart(() => {
                          this.baseScale = this.scaleValue;
                        })
                        .onActionUpdate((event: PinchGestureEvent) => {
                          this.scaleValue = Math.max(1, Math.min(5, this.baseScale * event.scale));
                          this.clampTranslate();
                        }),
                      TapGesture({ count: 2 })
                        .onAction(() => {
                          if (this.scaleValue > 1) {
                            this.scaleValue = 1;
                            this.translateX = 0;
                            this.translateY = 0;
                          } else {
                            this.scaleValue = 2.5;
                          }
                        })
                    )
                  )
                  .onTouch((event: TouchEvent) => {
                    if (this.scaleValue <= 1) return;
                    if (event.type === TouchType.Down && event.touches.length === 1) {
                      this.baseTranslateX = this.translateX;
                      this.baseTranslateY = this.translateY;
                      this.lastTouchX = event.touches[0].x;
                      this.lastTouchY = event.touches[0].y;
                    } else if (event.type === TouchType.Move && event.touches.length === 1 && this.lastTouchX >= 0) {
                      const dx = event.touches[0].x - this.lastTouchX;
                      const dy = event.touches[0].y - this.lastTouchY;
                      this.lastTouchX = event.touches[0].x;
                      this.lastTouchY = event.touches[0].y;
                      const speed = this.scaleValue * 0.6 + 0.4;
                      const maxX = (this.scaleValue - 1) * this.screenWidth / 2;
                      const maxY = (this.scaleValue - 1) * this.screenHeight / 2;
                      this.translateX = Math.max(-maxX, Math.min(maxX, this.translateX + dx * speed));
                      this.translateY = Math.max(-maxY, Math.min(maxY, this.translateY + dy * speed));
                    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                      this.lastTouchX = -1;
                      this.lastTouchY = -1;
                    }
                  })
              } else if (index === 0 && this.thumbnailLocalUrl) {
                Image(this.thumbnailLocalUrl)
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
                  .sharedTransition('illust_' + this.illustId, {
                    duration: 350,
                    curve: Curve.Friction
                  })
              } else {
                Stack() {
                  LoadingProgress().width(30).height(30).color(Color.White)
                }
                .width('100%')
                .height('100%')
                .backgroundColor(Color.Black)
                .alignContent(Alignment.Center)
              }
            }, (url: string, index: number) => `${index}_${url}`)
          }
          .index(this.currentIndex)
          .autoPlay(false)
          .loop(false)
          .indicator(false)
          .onChange((index: number) => {
            this.currentIndex = index;
            this.resetZoom();
            this.downloadSuccess = false;
            this.downloadFail = false;
          })

          // Top bar
          Column() {
            Row() {
              Button({ type: ButtonType.Circle }) {
                Text('←')
                  .fontSize(20)
                  .fontColor(Color.White)
              }
              .width(40).height(40)
              .backgroundColor($r('app.color.overlay_light'))
              .onClick(() => router.back())

              Blank()

              if (this.illustPageCount > 1) {
                Text(`${this.currentIndex + 1} / ${this.illustPageCount}`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .backgroundColor($r('app.color.overlay_medium'))
                  .borderRadius(10)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              }

              Blank()

              if (this.isDownloading) {
                LoadingProgress().width(20).height(20).color(Color.White)
              } else if (this.downloadSuccess) {
                Text('✓ 已保存').fontSize(12).fontColor($r('app.color.success'))
              } else {
                Button({ type: ButtonType.Circle }) {
                  Text('↓')
                    .fontSize(18)
                    .fontColor(Color.White)
                }
                .width(40).height(40)
                .backgroundColor($r('app.color.overlay_light'))
                .onClick(() => this.handleDownload())
              }

              if (this.isBookmarkLoading) {
                LoadingProgress()
                  .width(22).height(22)
                  .color($r('app.color.danger'))
                  .margin({ left: 12 })
              } else {
                Text(this.isBookmarked ? '❤' : '♡')
                  .fontSize(22)
                  .fontColor(this.isBookmarked ? $r('app.color.danger') : Color.White)
                  .margin({ left: 12 })
                  .onClick(() => this.toggleBookmark())
              }
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
            .height(52)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .position({ top: 0 })
          .hitTestBehavior(HitTestMode.Transparent)

          // Bottom info bar
          Column() {
            if (this.detail) {
              if (this.illustPageCount > 1) {
                Row() {
                  ForEach(Array.from<undefined, number>({ length: this.illustPageCount }, (_, i) => i), (index: number) => {
                    Circle()
                      .width(6).height(6)
                      .fill(index === this.currentIndex ? Color.White : '#66FFFFFF')
                      .margin({ left: 3, right: 3 })
                  }, (index: number) => String(index))
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding({ bottom: 8 })
              }

              Text(this.detail.illustTitle)
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.detail.userName)
                .fontSize(12)
                .fontColor(Color.White)
                .maxLines(1)
                .margin({ top: 2 })
              if (this.downloadFail) {
                Text('保存失败').fontSize(12).fontColor($r('app.color.danger')).margin({ top: 4 })
              }
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
          .position({ bottom: 0 })
          .backgroundColor($r('app.color.overlay_heavy'))
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .clip(true)
      } else if (this.isLoading) {
        LoadingProgress().width(40).height(40)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
