// entry/src/main/ets/pages/setting/SettingPage.ets
@Component
export struct SettingPage {
  build() {
    Column() {
      Text('设置页面内容')
        .fontSize(20)
        .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_background'))
  }
}