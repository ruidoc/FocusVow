@Component
export struct SettingsActionRow {
  @Prop title: string = '';
  @Prop value: string = '';
  onPress?: () => void;

  build() {
    Button() {
      Row() {
        Text(this.title)
          .fontSize(16)
          .fontColor('#111827')
        Blank()
        Text(this.value)
          .fontSize(13)
          .fontColor('#6B7280')
      }
      .width('100%')
    }
    .width('100%')
    .height(52)
    .type(ButtonType.Capsule)
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .padding({ left: 16, right: 16 })
    .onClick(() => {
      this.onPress?.();
    })
  }
}
