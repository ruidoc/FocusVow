@Component
export struct CertificateFooter {
  @Prop footerBrand: string = '专注契约';
  @Prop footerDatetime: string = '';
  @Prop adSlogan: string = '';
  @Prop darkTheme: boolean = false;

  build() {
    Column({ space: 6 }) {
      Text(this.footerBrand)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.darkTheme ? '#E8CACA' : '#4A3B1F')
        .textAlign(TextAlign.Start)

      if (this.footerDatetime.length > 0) {
        Text(this.footerDatetime)
          .fontSize(12)
          .fontColor(this.darkTheme ? '#B08A8A' : '#7A6A4A')
          .textAlign(TextAlign.Start)
      }

      if (this.adSlogan.length > 0) {
        Text(this.adSlogan)
          .fontSize(11)
          .fontColor(this.darkTheme ? '#D8A0A0' : '#9A8458')
          .lineHeight(18)
          .textAlign(TextAlign.Start)
          .padding({ top: 4 })
      }
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: '72%' })
  }
}
