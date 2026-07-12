import { ImageCacheService } from '../services/ImageCacheService';
import { ShimmerLoading } from './ShimmerLoading';

/**
 * 统一图片组件，封装网络/本地图片加载、占位图、失败兜底
 * 使用 @Reusable 实现组件复用优化
 */
@Reusable
@Component
export struct ImageComponent {
  @Prop @Require @Watch('onSrcChange') src: string;
  @Prop objectFit: ImageFit = ImageFit.Cover;
  @Prop imgBorderRadius: number = 0;
  @Prop showLoading: boolean = true;
  @State localSrc: string = '';
  @State isLoading: boolean = true;
  @State hasError: boolean = false;

  aboutToAppear(): void {
    this.loadImage();
  }

  aboutToReuse(params: Record<string, Object | null | undefined>): void {
    this.src = params.src as string;
    this.objectFit = (params.objectFit as ImageFit) ?? ImageFit.Cover;
    this.imgBorderRadius = (params.imgBorderRadius as number) ?? 0;
    this.showLoading = (params.showLoading as boolean) ?? true;
    this.localSrc = '';
    this.isLoading = true;
    this.hasError = false;
    this.loadImage();
  }

  onSrcChange(): void {
    if (this.src === this.localSrc) return;
    this.localSrc = '';
    this.isLoading = true;
    this.hasError = false;
    this.loadImage();
  }

  private async loadImage(): Promise<void> {
    if (!this.src) {
      this.isLoading = false;
      this.hasError = true;
      return;
    }

    if (this.src.startsWith('file://')) {
      this.localSrc = this.src;
      this.isLoading = false;
      return;
    }

    if (!this.src.startsWith('http')) {
      this.localSrc = this.src;
      this.isLoading = false;
      return;
    }

    try {
      const cached = await ImageCacheService.cacheImage(
        this.src,
        this.generateFileName(this.src)
      );
      if (cached) {
        this.localSrc = cached;
        this.isLoading = false;
      } else {
        this.hasError = true;
        this.isLoading = false;
      }
    } catch (_) {
      this.hasError = true;
      this.isLoading = false;
    }
  }

  private generateFileName(url: string): string {
    const parts = url.split('/');
    const raw = parts[parts.length - 1] || 'image.jpg';
    const last = raw.split('?')[0]; // 去掉查询参数（如 ?20180605）
    const hash = this.simpleHash(url);
    return `img_${hash}_${last}`;
  }

  private simpleHash(str: string): string {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash |= 0;
    }
    return Math.abs(hash).toString(16);
  }

  build() {
    Stack() {
      if (this.isLoading && this.showLoading) {
        ShimmerLoading()
          .width('100%')
          .height('100%')
          .borderRadius(this.imgBorderRadius)
      } else if (this.hasError || !this.localSrc) {
        Column() {
          Text('🖼')
            .fontSize(32)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.page_background'))
        .borderRadius(this.imgBorderRadius)
      } else {
        Image(this.localSrc)
          .width('100%')
          .height('100%')
          .objectFit(this.objectFit)
          .borderRadius(this.imgBorderRadius)
      }
    }
    .width('100%')
    .height('100%')
  }
}
