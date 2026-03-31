@Component
export struct HomeNavButton {
  @Prop title: string = '';
  @Prop description: string = '';
  onPress?: () => void;

  build() {
    Button() {
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text(this.title)
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#111827')

          Text(this.description)
            .fontSize(13)
            .fontColor('#6B7280')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('进入')
          .fontSize(13)
          .fontColor('#2563EB')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height(72)
    .type(ButtonType.Capsule)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .padding({ left: 18, right: 18 })
    .onClick(() => {
      this.onPress?.();
    })
  }
}
