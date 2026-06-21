@Component
export struct LoadingView {
  private message: string = ''

  build() {
    Column() {
      LoadingProgress()
        .width(36)
        .height(36)
        .color($r('app.color.tab_selected'))
      if (this.message) {
        Text(this.message)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
