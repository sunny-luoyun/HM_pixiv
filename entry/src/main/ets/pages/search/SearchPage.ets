// entry/src/main/ets/pages/search/SearchPage.ets
@Component
export struct SearchPage {
  build() {
    Column() {
      Text('搜索页面内容')
        .fontSize(20)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}