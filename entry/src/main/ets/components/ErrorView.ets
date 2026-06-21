@Component
export struct ErrorView {
  private message: string = ''
  private onRetry?: () => void

  build() {
    Column() {
      Text(this.message)
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .textAlign(TextAlign.Center)
        .maxLines(3)

      if (this.onRetry !== undefined) {
        Button('重试')
          .fontSize(13)
          .height(36)
          .padding({ left: 20, right: 20 })
          .fontColor(Color.White)
          .backgroundColor($r('app.color.tab_selected'))
          .borderRadius(8)
          .margin({ top: 12 })
          .onClick(() => { this.onRetry!() })
      }
    }
    .width('100%')
    .padding(24)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
