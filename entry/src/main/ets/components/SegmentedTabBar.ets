@Component
export struct SegmentedTabBar {
  private tabs: string[] = [];
  @Prop @Watch('onIndexChange') currentIndex: number = 0;
  onChange?: (index: number) => void;

  @State private animIndex: number = 0;
  @State private pillWidth: number = 0;
  private updatingFromClick: boolean = false;

  aboutToAppear() {
    this.animIndex = this.currentIndex;
  }

  onIndexChange() {
    if (this.updatingFromClick) {
      this.updatingFromClick = false;
      return;
    }
    animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
      this.animIndex = this.currentIndex;
    });
  }

  handleClick(index: number) {
    if (index === this.animIndex) return;
    this.updatingFromClick = true;
    animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
      this.animIndex = index;
    });
    this.onChange?.(index);
  }

  build() {
    Stack() {
      Row() {
        Column()
          .width(this.animIndex * this.pillWidth)
        Column()
          .width(this.pillWidth)
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
            .fontWeight(this.animIndex === index ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.animIndex === index
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
