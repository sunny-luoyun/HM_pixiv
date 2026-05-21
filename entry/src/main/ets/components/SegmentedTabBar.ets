@Component
export struct SegmentedTabBar {
  private tabs: string[] = [];
  @Prop currentIndex: number = 0;
  onChange?: (index: number) => void;

  @State private animIndex: number = 0;
  @State private containerWidth: number = 0;

  aboutToAppear() {
    this.animIndex = this.currentIndex;
  }

  aboutToUpdate() {
    this.animIndex = this.currentIndex;
  }

  get pillWidth(): number {
    if (this.containerWidth <= 4) return 0;
    return (this.containerWidth - 4) / this.tabs.length;
  }

  get pillTranslateX(): number {
    return this.animIndex * this.pillWidth;
  }

  handleClick(index: number) {
    if (index === this.animIndex) return;
    this.animIndex = index;
    this.onChange?.(index);
  }

  build() {
    Stack() {
      Column()
        .width(this.pillWidth)
        .height('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius(14)
        .shadow({ radius: 4, color: $r('app.color.card_shadow'), offsetY: 1 })
        .translate({ x: this.pillTranslateX })
        .animation({ duration: 250, curve: Curve.Friction })

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
      this.containerWidth = area.width as number;
    })
  }
}
