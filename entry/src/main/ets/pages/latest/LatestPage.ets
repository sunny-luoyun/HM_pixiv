// entry/src/main/ets/pages/latest/LatestPage.ets
@Component
export struct LatestPage {
  build() {
    Column() {
      Text('最新动态内容')
        .fontSize(20)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}