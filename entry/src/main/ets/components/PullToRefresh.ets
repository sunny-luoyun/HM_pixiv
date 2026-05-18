@Component
export struct PullToRefresh {
  @Link refreshing: boolean;
  onRefresh: () => void = () => {};
  @BuilderParam content: () => void;

  build() {
    Refresh({ refreshing: $$this.refreshing }) {
      this.content()
    }
    .onRefreshing(() => {
      this.onRefresh();
    })
  }
}
