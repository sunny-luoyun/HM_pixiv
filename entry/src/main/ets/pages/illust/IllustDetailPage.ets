import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import promptAction from '@ohos.promptAction';
import { common } from '@kit.AbilityKit';
import { curves, display } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { PixivService } from '../../services/PixivService';
import { IllustDetailBody, BrowseHistoryRecord, UgoiraMetaBody, UgoiraFrame } from '../../models/PixivModels';
import { ILLUST_TYPE_UGOIRA } from '../../models/UgoiraModels';
import { UgoiraPlayer } from '../../components/UgoiraPlayer';
import { GifEncoder } from '../../services/GifEncoder';
import { UgoiraExtractor } from '../../services/UgoiraExtractor';
import fileIo from '@ohos.file.fs';
import { pixivCacheDB } from '../../database/PixivCacheDB';
import { PageContext } from '../../common/utils/PageContext';
import { toLocalISODateTime } from '../../common/utils/TimeUtils';
import { PageEnum } from '../../common/constants/PageEnum';
import { IllustCommentsParam } from '../../common/constants/PageParamTypes';
import { SnapShotImage } from '../../common/utils/SnapShotImage';
import { LongTakeAnimationProperties } from '../../common/utils/LongTakeAnimationProperties';
import { CustomTransition } from '../../common/utils/CustomTransitionUtils';

interface ImageRenderSize {
  width: number;
  height: number;
}

@Component
struct IllustDetailPage {
  @State navParams: Record<string, Object> = {};
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
  @State isUgoira: boolean = false;
  @State ugoiraMeta: UgoiraMetaBody | null = null;

  @State isBookmarked: boolean = false;
  @State isBookmarkLoading: boolean = false;
  @State bookmarkScale: number = 1;
  @State scaleValue: number = 1;
  @State translateX: number = 0;
  @State imageOpacityArray: number[] = [];
  @State imageRenderSizes: ImageRenderSize[] = [];
  @State backgroundImageUrl: string = '';
  @State backgroundOpacity: number = 0;
  @State dominantColor: string = '';
  @State bgColor: string = '#000000';
  @State translateY: number = 0;
  @State private screenWidth: number = 0;
  @State private screenHeight: number = 0;
  @State longTakeAnim: LongTakeAnimationProperties = new LongTakeAnimationProperties();
  @State snapPixelMap: image.PixelMap | undefined = undefined;
  private navDestId: string = '';
  private clickedCardId: string = '';
  private recoverPrePage: () => void = () => {};
  private baseScale: number = 1;
  private baseTranslateX: number = 0;
  private baseTranslateY: number = 0;
  private lastTouchX: number = -1;
  private lastTouchY: number = -1;
  private lastPanTime: number = 0;
  private swiperController: SwiperController = new SwiperController();
  private bookmarkAnimTimer: number = -1;
  private bgTransitionTimer: number = -1;

  get pageCount(): number {
    return this.detail?.pageCount ?? 1;
  }

  async aboutToAppear() {
    this.isActive = true;
    const defaultDisplay = display.getDefaultDisplaySync();
    this.screenWidth = px2vp(defaultDisplay.width);
    this.screenHeight = px2vp(defaultDisplay.height);
  }

  aboutToDisappear() {
    this.isActive = false;
    PixivService.cancelDownloadGroup(`detail_${this.illustId}`);
    if (this.navDestId) {
      CustomTransition.getInstance().unRegisterNavParam(this.navDestId);
    }
    SnapShotImage.pixelMap = undefined;
    this.recoverPrePage();
    if (this.bookmarkAnimTimer !== -1) {
      clearTimeout(this.bookmarkAnimTimer);
      this.bookmarkAnimTimer = -1;
    }
    if (this.bgTransitionTimer !== -1) {
      clearTimeout(this.bgTransitionTimer);
      this.bgTransitionTimer = -1;
    }
  }

  goBack() {
    const ctx = AppStorage.get<PageContext>('rootPageContext');
    if (ctx) { ctx.popPage(); }
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
        this.isUgoira = (res.body.illustType === ILLUST_TYPE_UGOIRA);
        const pageCount = res.body.pageCount;
        this.illustPageCount = pageCount;

        if (this.isUgoira) {
          this.isLoading = false;
          this.loadUgoiraMeta(res.body.illustId);
        } else {
          const urls = PixivService.generatePageUrls(res.body.urls.regular, pageCount);
          this.pageRegularUrls = urls;

          const newUrls = new Array<string>(pageCount).fill('');
          if (this.thumbnailLocalUrl) {
            newUrls[0] = this.thumbnailLocalUrl;
          }
          this.localImageUrls = newUrls;
          this.imageOpacityArray = new Array<number>(pageCount).fill(0);
          this.imageRenderSizes = new Array(pageCount);
          this.isLoading = false;

          if (this.thumbnailLocalUrl) {
            PixivService.extractDominantColor(this.thumbnailLocalUrl)
              .then((color: string) => {
                if (this.isActive) {
                  const c = color || '#1a1a2e';
                  this.dominantColor = c;
                  animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
                    this.bgColor = c;
                  });
                }
              });
          }

          const illustId = res.body.illustId;
          const groupId = `detail_${illustId}`;
          urls.forEach((url, i) => {
            PixivService.cacheImage(url, `illust_${illustId}_pg${i}.jpg`, groupId)
              .then((path) => {
                if (this.isActive && path) {
                  const updated = [...this.localImageUrls];
                  updated[i] = path;
                  this.localImageUrls = updated;
                  const opacityUpdated = [...this.imageOpacityArray];
                  opacityUpdated[i] = 0;
                  this.imageOpacityArray = opacityUpdated;
                }
              })
              .catch(() => {});
          });
        }
        this.saveIllustHistory(res.body);
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

  private async loadUgoiraMeta(illustId: string): Promise<void> {
    try {
      const res = await PixivService.getUgoiraMeta(illustId);
      if (!this.isActive) return;
      if (!res.error && res.body) {
        this.ugoiraMeta = res.body;
      }
    } catch (err) {
      if (!this.isActive) return;
      console.error('获取动图元数据失败:', err);
    }
  }

  private async handleUgoiraDownload(): Promise<void> {
    if (!this.detail || !this.ugoiraMeta || this.isDownloading) {
      return;
    }
    this.isDownloading = true;
    this.downloadSuccess = false;
    this.downloadFail = false;
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const atManager = abilityAccessCtrl.createAtManager();
      const permissions: Array<Permissions> = ['ohos.permission.WRITE_IMAGEVIDEO'];
      const dt0: number = Date.now();
      const result = await atManager.requestPermissionsFromUser(ctx, permissions);
      console.info(`[DL] permission request: ${Date.now() - dt0}ms`);
      const granted = result.authResults.every(r => r === 0);
      if (!granted) {
        console.error('用户未授予相册写入权限');
        this.downloadFail = true;
        this.isDownloading = false;
        return;
      }
      promptAction.showToast({ message: '正在生成动图...' });
      const gifPath: string = ctx.filesDir + '/temp_ugoira_' + this.illustId + '.gif';
      const t0: number = Date.now();
      const entries = await UgoiraExtractor.extractUgoiraFrames(
        this.illustId, this.ugoiraMeta.src, this.ugoiraMeta.frames,
      );
      const t1: number = Date.now();
      console.info(`[DL] extractUgoiraFrames: ${entries.length} entries in ${t1 - t0}ms`);
      const framePaths: string[] = [];
      const delays: number[] = [];
      for (let i: number = 0; i < entries.length; i++) {
        let p: string = entries[i].localUri;
        if (p.startsWith('file://')) {
          p = p.slice(7);
        }
        framePaths.push(p);
        delays.push(entries[i].delay);
      }
      const ok: boolean = await GifEncoder.createGifFromFramePaths(
        framePaths, delays, gifPath, this.detail.width, this.detail.height,
      );
      const t2: number = Date.now();
      console.info(`[DL] createGif done: ${Date.now() - t1}ms`);
      if (!ok) {
        this.downloadFail = true;
        this.isDownloading = false;
        return;
      }
      const saved: boolean = await PixivService.saveImageToGallery(
        ctx,
        'file://' + gifPath,
        'ugoira_' + this.illustId + '.gif',
      );
      const t3: number = Date.now();
      console.info(`[DL] saveImageToGallery: ${t3 - t2}ms`);
      if (saved) {
        this.downloadSuccess = true;
        promptAction.showToast({ message: '动图已保存到相册' });
      } else {
        this.downloadFail = true;
      }
      try { fileIo.unlinkSync(gifPath); } catch (_) {}
      console.info(`[DL] total download: ${Date.now() - t0}ms`);
    } catch (err) {
      console.error('动图下载失败:', err);
      this.downloadFail = true;
    }
    this.isDownloading = false;
  }

  private async saveIllustHistory(detail: IllustDetailBody): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const tagNames: string[] = [];
      for (let i = 0; i < detail.tags.tags.length; i++) {
        tagNames.push(detail.tags.tags[i].tag);
      }
      const record: BrowseHistoryRecord = {
        id: 'illust_' + detail.illustId,
        contentType: 'illust',
        contentId: detail.illustId,
        title: detail.illustTitle,
        coverUrl: detail.urls.regular,
        userId: detail.userId,
        userName: detail.userName,
        pageCount: detail.pageCount,
        tags: tagNames,
        bookmarkCount: detail.bookmarkCount,
        wordCount: 0,
        seriesId: '',
        seriesTitle: '',
        createDate: detail.createDate,
        updateDate: '',
        viewedAt: toLocalISODateTime(new Date())
      };
      await pixivCacheDB.saveBrowseHistory(record, ctx);
    } catch (err) {
      console.error('保存插画浏览历史失败:', err);
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
    animateTo({ curve: Curve.FastOutSlowIn, duration: 250 }, () => {
      this.bookmarkScale = 1.35;
    });
    this.bookmarkAnimTimer = setTimeout(() => {
      this.bookmarkAnimTimer = -1;
      animateTo({ curve: curves.springMotion(0.55, 0.65) }, () => {
        this.bookmarkScale = 1;
      });
    }, 280);
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
    const size = this.imageRenderSizes[this.currentIndex];
    const imgW = size?.width || this.screenWidth;
    const imgH = size?.height || this.screenHeight;
    const maxX = (this.scaleValue - 1) * imgW / 2;
    const maxY = (this.scaleValue - 1) * imgH / 2;
    this.translateX = Math.max(-maxX, Math.min(maxX, this.translateX));
    this.translateY = Math.max(-maxY, Math.min(maxY, this.translateY));
  }

  build() {
    NavDestination() {
    Column() {
      if (this.errorMsg) {
        Column() {
          Text(this.errorMsg).fontSize(14).fontColor($r('app.color.text_secondary'))
          Button('重试').margin({ top: 12 }).onClick(() => this.loadDetail())
          Button('返回').margin({ top: 8 }).onClick(() => { const ctx = AppStorage.get<PageContext>('rootPageContext'); if (ctx) { ctx.popPage(); } })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.isUgoira && this.ugoiraMeta) {
        Stack({ alignContent: Alignment.TopStart }) {
          Stack({ alignContent: Alignment.TopStart }) {
            UgoiraPlayer({
              illustId: this.illustId,
              frames: this.ugoiraMeta.frames,
              zipUrl: this.ugoiraMeta.src,
              illustWidth: this.detail?.width ?? 0,
              illustHeight: this.detail?.height ?? 0,
            })
          }
          .width('100%')
          .height('100%')
          .opacity(this.longTakeAnim.contentOpacity)

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
              .onClick(() => this.goBack())

              Blank()

              Text('动图')
                .fontSize(13)
                .fontColor(Color.White)
                .backgroundColor($r('app.color.overlay_medium'))
                .borderRadius(10)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })

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
                .onClick(() => {
                  this.handleUgoiraDownload();
                })
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
                  .scale({ x: this.bookmarkScale, y: this.bookmarkScale })
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
              Text(`评论 (${this.detail.commentCount ?? 0})`)
                .fontSize(12)
                .fontColor('#66FFFFFF')
                .margin({ top: 4 })
                .onClick(() => {
                  const pageCtx = AppStorage.get<PageContext>('rootPageContext');
                  if (pageCtx) {
                    const params: IllustCommentsParam = {
                      illustId: this.illustId
                    };
                    pageCtx.openPage(PageEnum.ILLUST_COMMENTS, params as Object);
                  }
                })
            }
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
          .position({ bottom: 0 })
          .backgroundColor($r('app.color.overlay_heavy'))
          .hitTestBehavior(HitTestMode.Transparent)
        }
        .width(this.longTakeAnim.clipWidth)
        .height(this.longTakeAnim.clipHeight)
        .borderRadius(this.longTakeAnim.radius)
        .backgroundColor(this.bgColor)
        .clip(true)
      } else if (this.thumbnailLocalUrl || (this.detail && this.localImageUrls.length > 0)) {
        Stack({ alignContent: Alignment.TopStart }) {
          Stack({ alignContent: Alignment.TopStart }) {
            if (this.backgroundImageUrl) {
              Image(this.backgroundImageUrl)
                .width('100%')
                .height('100%')
                .objectFit(ImageFit.Cover)
                .blur(40)
                .scale({ x: 1.1, y: 1.1 })
                .opacity(this.backgroundOpacity)
            }
            Swiper(this.swiperController) {
              ForEach(this.localImageUrls, (url: string, index: number) => {
                if (url) {
                  Stack() {
                    Image(url)
                      .width(this.imageRenderSizes[index]?.width || '100%')
                      .height(this.imageRenderSizes[index]?.height || '100%')
                      .objectFit(ImageFit.Contain)
                      .opacity(this.imageOpacityArray[index] ?? 0)
                      .onComplete((info) => {
                        const updated = [...this.imageOpacityArray];
                        updated[index] = 1;
                        animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
                          this.imageOpacityArray = updated;
                        });
                        if (info && info.width > 0 && info.height > 0 && this.screenWidth > 0) {
                          const nativeRatio = info.width / info.height;
                          const containerRatio = this.screenWidth / this.screenHeight;
                          const sizes: ImageRenderSize[] = [...this.imageRenderSizes];
                          if (nativeRatio > containerRatio) {
                            sizes[index] = { width: this.screenWidth, height: this.screenWidth / nativeRatio } as ImageRenderSize;
                          } else {
                            sizes[index] = { width: this.screenHeight * nativeRatio, height: this.screenHeight } as ImageRenderSize;
                          }
                          this.imageRenderSizes = sizes;
                        }
                      })
                      .scale({ x: this.scaleValue, y: this.scaleValue })
                      .translate({ x: this.translateX, y: this.translateY })
                  }
                  .width('100%')
                  .height('100%')
                  .alignContent(Alignment.Center)
                  .gesture(
                    GestureGroup(GestureMode.Parallel,
                      PinchGesture()
                        .onActionStart(() => {
                          this.baseScale = this.scaleValue;
                        })
                        .onActionUpdate((event: PinchGestureEvent) => {
                          this.scaleValue = Math.max(1, Math.min(5, this.baseScale * event.scale));
                          this.clampTranslate();
                        })
                        .onActionEnd(() => {
                          animateTo({ curve: curves.springMotion() }, () => {
                            this.clampTranslate();
                          });
                        }),
                      TapGesture({ count: 2 })
                        .onAction(() => {
                          if (this.scaleValue > 1) {
                            animateTo({ curve: curves.springMotion() }, () => {
                              this.scaleValue = 1;
                              this.translateX = 0;
                              this.translateY = 0;
                            });
                          } else {
                            animateTo({ curve: curves.springMotion() }, () => {
                              this.scaleValue = 2.5;
                            });
                          }
                        })
                    )
                  )
                  .onTouch((event: TouchEvent) => {
                    if (this.scaleValue <= 1) return;
                    const now = Date.now();
                    if (now - this.lastPanTime < 16) return;
                    this.lastPanTime = now;
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
                      const size = this.imageRenderSizes[this.currentIndex];
                      const imgW = size?.width || this.screenWidth;
                      const imgH = size?.height || this.screenHeight;
                      const maxX = (this.scaleValue - 1) * imgW / 2;
                      const maxY = (this.scaleValue - 1) * imgH / 2;
                      this.translateX = Math.max(-maxX, Math.min(maxX, this.translateX + dx * speed));
                      this.translateY = Math.max(-maxY, Math.min(maxY, this.translateY + dy * speed));
                    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                      this.lastTouchX = -1;
                      this.lastTouchY = -1;
                    }
                  })
                } else if (index === 0 && this.thumbnailLocalUrl) {
                  Stack() {
                    Image(this.thumbnailLocalUrl)
                      .width(this.imageRenderSizes[index]?.width || '100%')
                      .height(this.imageRenderSizes[index]?.height || '100%')
                      .objectFit(ImageFit.Contain)
                      .onComplete((info) => {
                        if (info && info.width > 0 && info.height > 0 && this.screenWidth > 0) {
                          const nativeRatio = info.width / info.height;
                          const containerRatio = this.screenWidth / this.screenHeight;
                          const sizes: ImageRenderSize[] = [...this.imageRenderSizes];
                          if (nativeRatio > containerRatio) {
                            sizes[index] = { width: this.screenWidth, height: this.screenWidth / nativeRatio } as ImageRenderSize;
                          } else {
                            sizes[index] = { width: this.screenHeight * nativeRatio, height: this.screenHeight } as ImageRenderSize;
                          }
                          this.imageRenderSizes = sizes;
                        }
                      })
                  }
                  .width('100%')
                  .height('100%')
                  .alignContent(Alignment.Center)
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
            .cachedCount(1)
            .onChange((index: number) => {
              this.currentIndex = index;
              this.resetZoom();
              this.downloadSuccess = false;
              this.downloadFail = false;
              const bgUrl = this.localImageUrls[index];
              if (bgUrl && bgUrl !== this.backgroundImageUrl) {
                animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
                  this.backgroundOpacity = 0;
                });
                this.bgTransitionTimer = setTimeout(() => {
                  this.bgTransitionTimer = -1;
                  this.backgroundImageUrl = bgUrl;
                  animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
                    this.backgroundOpacity = 0.5;
                  });
                }, 200);
              }
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
                .onClick(() => this.goBack())

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
                    .scale({ x: this.bookmarkScale, y: this.bookmarkScale })
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
                Text(`评论 (${this.detail.commentCount ?? 0})`)
                  .fontSize(12)
                  .fontColor('#66FFFFFF')
                  .margin({ top: 4 })
                  .onClick(() => {
                    const pageCtx = AppStorage.get<PageContext>('rootPageContext');
                    if (pageCtx) {
                      const params: IllustCommentsParam = {
                        illustId: this.illustId
                      };
                      pageCtx.openPage(PageEnum.ILLUST_COMMENTS, params as Object);
                    }
                  })
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
          .opacity(this.longTakeAnim.contentOpacity)

          if (this.snapPixelMap && this.longTakeAnim.snapOpacity > 0) {
            Image(this.snapPixelMap)
              .position({
                x: this.longTakeAnim.snapShotPositionX,
                y: this.longTakeAnim.snapShotPositionY
              })
              .size({
                width: this.longTakeAnim.snapShotWidth,
                height: this.longTakeAnim.snapShotHeight
              })
              .objectFit(ImageFit.Auto)
              .syncLoad(true)
              .opacity(this.longTakeAnim.snapOpacity)
          }
        }
        .scale({ x: this.longTakeAnim.scaleValue, y: this.longTakeAnim.scaleValue })
        .translate({ x: this.longTakeAnim.translateX, y: this.longTakeAnim.translateY })
        .width(this.longTakeAnim.clipWidth)
        .height(this.longTakeAnim.clipHeight)
        .borderRadius(this.longTakeAnim.radius)
        .backgroundColor(this.bgColor)
        .clip(true)
      } else if (this.isLoading) {
        LoadingProgress().width(40).height(40)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
    }
    .onReady((ctx: NavDestinationContext) => {
      this.navParams = ctx.pathInfo.param as Record<string, Object> ?? {};
      const id = this.navParams['id'] as string;
      if (!id) {
        this.errorMsg = '缺少插图ID';
        this.isLoading = false;
        return;
      }
      this.illustId = id;
      this.thumbnailLocalUrl = (this.navParams['thumbnailLocalUrl'] as string) || '';
      if (this.thumbnailLocalUrl) {
        this.localImageUrls = [this.thumbnailLocalUrl];
        this.imageOpacityArray = [0];
        this.backgroundImageUrl = this.thumbnailLocalUrl;
        this.illustPageCount = 1;
        animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
          this.backgroundOpacity = 0.5;
        });
      }
      this.loadDetail();

      const clickedComponentId = this.navParams['clickedComponentId'] as string | undefined;
      const doTransition = this.navParams['doDefaultTransition'] as (() => void) | undefined;
      if (clickedComponentId && SnapShotImage.pixelMap && doTransition && ctx.navDestinationId) {
        this.snapPixelMap = SnapShotImage.pixelMap;
        this.clickedCardId = clickedComponentId;
        this.recoverPrePage = doTransition;
        this.navDestId = ctx.navDestinationId;
        this.longTakeAnim.init(this.clickedCardId, this.recoverPrePage,
          this.getUIContext(), this.screenWidth, this.screenHeight);
        CustomTransition.getInstance().registerNavParam(this.navDestId, 2000,
          (transitionProxy: NavigationTransitionProxy) => {
            if (CustomTransition.getInstance().operation === NavigationOperation.PUSH) {
              this.longTakeAnim.doEnterAnimation(transitionProxy);
            } else {
              this.longTakeAnim.doBackAnimation(transitionProxy);
            }
          });
      }
    })
    .onBackPressed(() => {
      this.goBack();
      return true;
    })
    .hideTitleBar(true)
  }
}

@Builder
export function IllustDetailBuilder(): void {
  IllustDetailPage()
}
