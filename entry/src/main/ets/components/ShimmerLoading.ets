@Component
export struct ShimmerLoading {
  @State shimmerX: number = -200
  private timer: number = -1

  aboutToAppear() {
    this.startShimmer()
  }

  aboutToDisappear() {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }

  startShimmer() {
    animateTo({ duration: 800, curve: Curve.Linear }, () => {
      this.shimmerX = 400
    })
    this.timer = setTimeout(() => {
      this.shimmerX = -200
      this.startShimmer()
    }, 800)
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor($r('app.color.loading_card'))

      Column()
        .width(160)
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Right,
          colors: [
            ['rgba(255,255,255,0)', 0],
            ['rgba(255,255,255,0.4)', 0.4],
            ['rgba(255,255,255,0.6)', 0.5],
            ['rgba(255,255,255,0.4)', 0.6],
            ['rgba(255,255,255,0)', 1]
          ]
        })
        .translate({ x: this.shimmerX })
    }
    .clip(true)
  }
}
