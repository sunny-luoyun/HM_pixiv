import { curves } from '@kit.ArkUI';
import { UgoiraFrame } from '../models/PixivModels';
import { UgoiraExtractor } from '../services/UgoiraExtractor';

@Component
export struct UgoiraPlayer {
  @Prop @Require illustId: string;
  @Prop @Require frames: UgoiraFrame[];
  @Prop @Require zipUrl: string;
  @Prop illustWidth: number = 0;
  @Prop illustHeight: number = 0;
  @State private localFrameUris: string[] = [];
  @State private currentFrameIndex: number = 0;
  @State private isLoading: boolean = true;
  @State private isPlaying: boolean = true;
  @State private errorMsg: string = '';
  private frameTimer: number = -1;

  get ratio(): number {
    if (this.illustWidth > 0 && this.illustHeight > 0) {
      return this.illustWidth / this.illustHeight;
    }
    return 1;
  }

  async aboutToAppear() {
    await this.loadFrames();
  }

  aboutToDisappear() {
    this.clearTimer();
    this.isPlaying = false;
    this.localFrameUris = [];
  }

  private clearTimer(): void {
    if (this.frameTimer !== -1) {
      clearTimeout(this.frameTimer);
      this.frameTimer = -1;
    }
  }

  private async loadFrames(): Promise<void> {
    this.isLoading = true;
    this.errorMsg = '';
    try {
      const entries = await UgoiraExtractor.extractUgoiraFrames(
        this.illustId, this.zipUrl, this.frames
      );
      if (entries.length === 0) {
        this.errorMsg = '动图加载失败';
        this.isLoading = false;
        return;
      }
      const uris: string[] = [];
      for (let i: number = 0; i < entries.length; i++) {
        uris.push(entries[i].localUri);
      }
      this.localFrameUris = uris;
      this.currentFrameIndex = 0;
      this.isLoading = false;
      this.isPlaying = true;
      this.startAnimation();
    } catch (err) {
      this.errorMsg = '动图加载失败: ' + String(err);
      this.isLoading = false;
    }
  }

  private startAnimation(): void {
    this.clearTimer();
    if (!this.isPlaying || this.localFrameUris.length === 0) {
      return;
    }
    const delay: number = this.frames[this.currentFrameIndex]?.delay ?? 125;
    this.frameTimer = setTimeout(() => {
      this.frameTimer = -1;
      if (this.isPlaying && this.localFrameUris.length > 0) {
        const next: number = (this.currentFrameIndex + 1) % this.localFrameUris.length;
        this.currentFrameIndex = next;
        this.startAnimation();
      }
    }, delay);
  }

  private togglePlay(): void {
    this.isPlaying = !this.isPlaying;
    if (this.isPlaying) {
      this.startAnimation();
    } else {
      this.clearTimer();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.isLoading) {
        Column({ space: 8 }) {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(Color.White)
          Text('正在加载动图...')
            .fontSize(13)
            .fontColor(Color.White)
            .opacity(0.7)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      } else if (this.errorMsg) {
        Text(this.errorMsg)
          .fontSize(14)
          .fontColor(Color.White)
      } else if (this.localFrameUris.length > 0) {
        Image(this.localFrameUris[this.currentFrameIndex])
          .objectFit(ImageFit.Contain)
          .width('100%')
          .height('100%')
          .aspectRatio(this.ratio)

        Column() {
          Text(this.isPlaying ? '⏸' : '▶')
            .fontSize(16)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor($r('app.color.overlay_light'))
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
        .position({ bottom: 16, right: 16 })
        .onClick(() => {
          this.togglePlay();
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
