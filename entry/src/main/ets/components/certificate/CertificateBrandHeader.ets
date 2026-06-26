@Component
export struct CertificateBrandHeader {
  @Prop certificateNo: string = '';
  @Prop darkTheme: boolean = false;

  build() {
    Row() {
      Text('FocusVow © 2026')
        .fontSize(10)
        .fontColor(this.darkTheme ? '#8A7070' : '#9A8458')
        .letterSpacing(0.5)

      Blank()

      if (this.certificateNo.length > 0) {
        Text(this.certificateNo)
          .fontSize(10)
          .fontColor(this.darkTheme ? '#8A7070' : '#9A8458')
          .letterSpacing(0.5)
      }
    }
    .width('100%')
    .margin({ bottom: 8 })
  }
}
