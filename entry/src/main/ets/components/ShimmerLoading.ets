@Component
export struct ShimmerLoading {
  @State shimmerX: number = -200
  private shimmerInterval: number = -1
  private shimmerForward: boolean = true

  aboutToAppear() {
    this.startShimmer()
  }

  aboutToDisappear() {
    this.stopShimmer()
  }

  startShimmer() {
    if (this.shimmerInterval !== -1) {
      return
    }
    this.shimmerInterval = setInterval(() => {
      this.shimmerForward = !this.shimmerForward
      animateTo({ duration: 800, curve: Curve.Linear }, () => {
        this.shimmerX = this.shimmerForward ? 400 : -200
      })
    }, 800)
  }

  stopShimmer() {
    if (this.shimmerInterval !== -1) {
      clearInterval(this.shimmerInterval)
      this.shimmerInterval = -1
    }
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
    .onVisibleAreaChange([0.0, 1.0], (isVisible: boolean, _currentRatio: number) => {
      if (isVisible) {
        this.startShimmer()
      } else {
        this.stopShimmer()
      }
    })
  }
}
