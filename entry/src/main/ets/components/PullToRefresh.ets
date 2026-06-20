import { curves } from '@kit.ArkUI';

@Component
export struct PullToRefresh {
  @Link @Watch('onRefreshingChange') refreshing: boolean;
  onRefresh: () => void = () => {};
  @BuilderParam content: () => void;
  @State private refreshState: 'idle' | 'refreshing' | 'complete' = 'idle';
  private refreshWatcher: number = -1;

  onRefreshingChange(): void {
    if (!this.refreshing && this.refreshState === 'refreshing') {
      animateTo({ curve: curves.springMotion(0.45, 0.7) }, () => {
        this.refreshState = 'complete';
      });
      if (this.refreshWatcher !== -1) {
        clearTimeout(this.refreshWatcher);
      }
      this.refreshWatcher = setTimeout(() => {
        animateTo({ curve: curves.springMotion(0.55, 0.75) }, () => {
          this.refreshState = 'idle';
        });
      }, 1200);
    }
  }

  aboutToDisappear() {
    if (this.refreshWatcher !== -1) {
      clearTimeout(this.refreshWatcher);
    }
  }

  build() {
    Refresh({ refreshing: $$this.refreshing, builder: this.RefreshHeaderBuilder }) {
      this.content()
    }
    .onRefreshing(() => {
      animateTo({ curve: curves.springMotion(0.55, 0.75) }, () => {
        this.refreshState = 'refreshing';
      });
      this.onRefresh();
    })
  }

  @Builder
  RefreshHeaderBuilder() {
    Row() {
      if (this.refreshState === 'complete') {
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
