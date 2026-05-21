import router from '@ohos.router';
import abilityAccessCtrl, { Permissions } from '@ohos.abilityAccessCtrl';
import { common } from '@kit.AbilityKit';
import { PixivService, IllustDetailBody } from '../../services/PixivService';

@Entry
@Component
struct IllustDetailPage {
  @State illustId: string = '';
  @State detail: IllustDetailBody | null = null;
  @State isLoading: boolean = true;
  @State errorMsg: string = '';
  @State localImageUrl: string = '';
  @State isDownloading: boolean = false;
  @State downloadSuccess: boolean = false;
  @State downloadFail: boolean = false;

  @State scaleValue: number = 1;
  @State translateX: number = 0;
  @State translateY: number = 0;
  private baseScale: number = 1;
  private baseTranslateX: number = 0;
  private baseTranslateY: number = 0;

  async aboutToAppear() {
    const params = router.getParams() as Record<string, Object>;
    this.illustId = params['id'] as string;
    if (!this.illustId) {
      this.errorMsg = '缺少插图ID';
      this.isLoading = false;
      return;
    }
    await this.loadDetail();
  }

  async loadDetail() {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const res = await PixivService.getIllustDetail(this.illustId);
      if (!res.error && res.body) {
        this.detail = res.body;
        const path = await PixivService.cacheImage(res.body.urls.regular, `illust_${res.body.illustId}_detail.jpg`);
        if (path) {
          this.localImageUrl = path;
        }
      } else {
        this.errorMsg = res.message || '获取详情失败';
      }
    } catch (err) {
      console.error('获取插画详情失败:', err);
      this.errorMsg = '加载失败，请检查网络';
    }
    this.isLoading = false;
  }

  async handleDownload() {
    if (!this.detail || this.isDownloading) return;
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
      const ok = await PixivService.saveImageToGallery(
        ctx,
        this.detail.urls.original,
        `illust_${this.detail.illustId}_original.jpg`
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
      } else if (this.detail && this.localImageUrl) {
        Stack() {
          Image(this.localImageUrl)
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
                PanGesture()
                  .onActionStart(() => {
                    this.baseTranslateX = this.translateX;
                    this.baseTranslateY = this.translateY;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    if (this.scaleValue > 1) {
                      this.translateX = this.baseTranslateX + event.offsetX;
                      this.translateY = this.baseTranslateY + event.offsetY;
                    }
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
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })
            .height(52)

            Blank()

            Column() {
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
            .backgroundColor('#80000000')
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.SpaceBetween)
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
