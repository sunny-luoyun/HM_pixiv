export interface SortOption {
  label: string;       // 显示文本，如 '缓存时间'
  value: string;       // 排序字段标识，如 'cachedAt'
}

@Component
export struct SortPopupMenu {
  @Prop visible: boolean = false;
  @Prop sortOptions: SortOption[] = [];
  @Prop currentSort: string = '';
  @Prop sortAscending: boolean = true;
  onSelect: (value: string) => void = () => {};
  onToggleDirection: () => void = () => {};
  onDismiss: () => void = () => {};

  build() {
    if (this.visible) {
      Column() {
        // 半透明遮罩
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick(() => { this.onDismiss(); })

        // 底部弹出面板
        Column() {
          // 标题栏
          Row() {
            Text('排序方式')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.user_name'))
            Blank()
            Text(this.sortAscending ? '↑ 升序' : '↓ 降序')
              .fontSize(13)
              .fontColor($r('app.color.tab_selected'))
              .onClick(() => { this.onToggleDirection(); })
          }
          .width('100%')
          .padding({ left: 20, right: 20, top: 16, bottom: 12 })

          Divider().color($r('app.color.divider'))

          // 选项列表
          ForEach(this.sortOptions, (option: SortOption) => {
            Row() {
              Text(option.label)
                .fontSize(15)
                .fontColor(this.currentSort === option.value
                  ? $r('app.color.tab_selected')
                  : $r('app.color.user_name'))
                .fontWeight(this.currentSort === option.value ? FontWeight.Medium : FontWeight.Normal)
              Blank()
              if (this.currentSort === option.value) {
                Text('●')
                  .fontSize(14)
                  .fontColor($r('app.color.tab_selected'))
              }
            }
            .width('100%')
            .height(48)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              this.onSelect(option.value);
              this.onDismiss();
            })
          }, (option: SortOption): string => option.value)

          // 底部安全区
          Column()
            .height(20)
        }
        .width('100%')
        .backgroundColor($r('app.color.card_bg'))
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
      .width('100%')
      .height('100%')
    }
  }
}
