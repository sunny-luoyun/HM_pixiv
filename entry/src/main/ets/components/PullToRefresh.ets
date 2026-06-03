@Component
export struct PullToRefresh {
  @Link refreshing: boolean;
  onRefresh: () => void = () => {};
  @BuilderParam content: () => void;
  @State private showComplete: boolean = false;
  private refreshWatcher: number = -1;

  aboutToDisappear() {
    if (this.refreshWatcher !== -1) {
      clearTimeout(this.refreshWatcher);
    }
  }

  build() {
    Refresh({ refreshing: $$this.refreshing }) {
      Column() {
        if (this.refreshing || this.showComplete) {
          this.IndicatorBar()
        }
        this.content()
      }
      .width('100%')
    }
    .onRefreshing(() => {
      this.onRefresh();
    })
    .onStateChange((state: RefreshStatus) => {
      if (state === RefreshStatus.Refresh && !this.refreshing) {
        this.refreshing = true;
      }
      if (state === RefreshStatus.Done && !this.refreshing && !this.showComplete) {
        this.showComplete = true;
        this.refreshWatcher = setTimeout(() => {
          this.showComplete = false;
        }, 1200);
      }
    })
  }

  @Builder
  IndicatorBar() {
    Row() {
      if (this.showComplete) {
        Text('✓')
          .fontSize(16)
          .fontColor(Color.White)
          .width(24).height(24)
          .backgroundColor($r('app.color.success'))
          .borderRadius(12)
          .textAlign(TextAlign.Center)
          .lineHeight(24)
          .margin({ right: 8 })
        Text('刷新完成')
          .fontSize(13)
          .fontColor($r('app.color.success'))
          .fontWeight(FontWeight.Medium)
      } else {
        LoadingProgress()
          .width(18).height(18)
          .color($r('app.color.tab_selected'))
          .margin({ right: 8 })
        Text('刷新中...')
          .fontSize(13)
          .fontColor($r('app.color.tab_selected'))
          .fontWeight(FontWeight.Medium)
      }
    }
    .width('100%')
    .height(40)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
  }
}
