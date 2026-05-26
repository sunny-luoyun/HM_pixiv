import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { PixivService, IllustDetailBody } from '../../services/PixivService';

@Entry
@Component
struct IllustDetailPage {
  @State illustId: string = '';
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
  private baseScale: number = 1;
  private baseTranslateX: number = 0;
  private baseTranslateY: number = 0;
  private swiperController: SwiperController = new SwiperController();

  get pageCount(): number {
    return this.detail?.pageCount ?? 1;
  }

  async aboutToAppear() {
    this.isActive = true;
    const params = router.getParams() as Record<string, Object>;
    this.illustId = params['id'] as string;
    if (!this.illustId) {
      this.errorMsg = '缺少插图ID';
      this.isLoading = false;
      return;
    }
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
      if (!res.error && res.body) {
        this.detail = res.body;
        this.isBookmarked = !!res.body.bookmarkData;
        const pageCount = res.body.pageCount;
        this.illustPageCount = pageCount;
        const urls = PixivService.generatePageUrls(res.body.urls.regular, pageCount);
        this.pageRegularUrls = urls;

        this.localImageUrls = new Array<string>(pageCount).fill('');
        this.isLoading = false;

        if (!this.isActive) return;

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

  build() {
    Column() {
      if (this.isLoading) {
        LoadingProgress().width(40).height(40)
      } else if (this.errorMsg) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button('重试').margin({ top: 12 }).onClick(() => this.loadDetail())
          Button('返回').margin({ top: 8 }).onClick(() => router.back())
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.detail && this.localImageUrls.length > 0) {
        Stack() {
          Swiper(this.swiperController) {
            ForEach(this.localImageUrls, (url: string, index: number) => {
              if (url) {
                Image(url)
                  .width('100%')
                  .height('100%')
                  .objectFit(ImageFit.Contain)
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
              } else {
                Stack() {
                  LoadingProgress().width(30).height(30).color('#66FFFFFF')
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
              .backgroundColor('#33FFFFFF')
              .onClick(() => router.back())

              Blank()

              if (this.illustPageCount > 1) {
                Text(`${this.currentIndex + 1} / ${this.illustPageCount}`)
                  .fontSize(13)
                  .fontColor(Color.White)
                  .backgroundColor('#66000000')
                  .borderRadius(10)
                  .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              }

              Blank()

              if (this.isDownloading) {
                LoadingProgress().width(20).height(20).color(Color.White)
              } else if (this.downloadSuccess) {
                Text('✓ 已保存').fontSize(12).fontColor('#52C41A')
              } else {
                Button({ type: ButtonType.Circle }) {
                  Text('↓')
                    .fontSize(18)
                    .fontColor(Color.White)
                }
                .width(40).height(40)
                .backgroundColor('#33FFFFFF')
                .onClick(() => this.handleDownload())
              }

              if (this.isBookmarkLoading) {
                LoadingProgress()
                  .width(22).height(22)
                  .color('#FF4D4F')
                  .margin({ left: 12 })
              } else {
                Text(this.isBookmarked ? '❤' : '♡')
                  .fontSize(22)
                  .fontColor(this.isBookmarked ? '#FF4D4F' : Color.White)
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
              Text('保存失败').fontSize(12).fontColor('#FF4D4F').margin({ top: 4 })
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
          .position({ bottom: 0 })
          .backgroundColor('#80000000')
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Color.Black)
        .clip(true)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
  }
}
