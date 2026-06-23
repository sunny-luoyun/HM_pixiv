import { curves } from '@kit.ArkUI';

@Component
export struct SegmentedTabBar {
  private tabs: string[] = [];
  @Prop @Watch('syncIndex') currentIndex: number = 0;
  @Prop swipeProgress: number = 0;
  onChange?: (index: number) => void;

  @State private animIndex: number = 0;
  @State private pillWidth: number = 0;

  aboutToAppear() {
    this.animIndex = this.currentIndex;
  }

  syncIndex() {
    this.animIndex = this.currentIndex;
  }

  handleClick(index: number) {
    if (index === this.currentIndex) return;
    animateTo({ curve: curves.springMotion(0.4, 0.8) }, () => {
      this.animIndex = index;
    });
    this.onChange?.(index);
  }

  private getPillOffset(): number {
    if (this.swipeProgress !== 0) {
      const maxIndex = this.tabs.length - 1;
      const raw = this.currentIndex + this.swipeProgress;
      const clamped = Math.max(0, Math.min(raw, maxIndex));
      return clamped * this.pillWidth;
    }
    return this.animIndex * this.pillWidth;
  }

  private getPillScale(): number {
    if (this.swipeProgress === 0) return 1;
    const abs = Math.abs(this.swipeProgress);
    return 1 + abs * 0.12 * (1 - abs);
  }

  private getActiveTextIndex(): number {
    if (this.swipeProgress !== 0) {
      return Math.abs(this.swipeProgress) >= 0.5
        ? this.currentIndex + Math.sign(this.swipeProgress)
        : this.currentIndex;
    }
    return this.animIndex;
  }

  build() {
    Stack() {
      Row() {
        Column()
          .width(this.getPillOffset())
        Column()
          .width(this.pillWidth * this.getPillScale())
          .height('100%')
          .backgroundColor($r('app.color.pill_bg'))
          .border({ width: 1, color: $r('app.color.pill_stroke'), radius: 14 })
          .shadow({ radius: 8, color: $r('app.color.card_shadow'), offsetY: 2 })
      }
      .width('100%')
      .height('100%')

      Row() {
        ForEach(this.tabs, (tab: string, index: number) => {
          Text(tab)
            .fontSize(14)
            .fontWeight(this.getActiveTextIndex() === index ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.getActiveTextIndex() === index
              ? $r('app.color.tab_selected')
              : $r('app.color.text_secondary'))
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .onClick(() => this.handleClick(index))
        }, (tab: string) => tab)
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height(32)
    .backgroundColor($r('app.color.surface_secondary'))
    .borderRadius(16)
    .padding(2)
    .align(Alignment.TopStart)
    .onAreaChange((_old: Area, area: Area) => {
      this.pillWidth = ((area.width as number) - 4) / this.tabs.length;
    })
  }
}
