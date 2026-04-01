// entry/src/main/ets/pages/home/HomePage.ets
@Component
export struct HomePage {
  build() {
    Column() {
      Text('主页内容')
        .fontSize(20)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}