@Component
export struct CertificateInfoSection {
  @Prop userName: string = '';
  @Prop partnerName: string = '';
  @Prop datetimeLabel: string = '';
  @Prop darkTheme: boolean = false;

  private getPrimaryColor(): string {
    return this.darkTheme ? '#F2D0D0' : '#3D3424';
  }

  private getSecondaryColor(): string {
    return this.darkTheme ? '#E8CACA' : '#5A4F3A';
  }

  build() {
    Column({ space: 6 }) {
      Text(`我：${this.userName}`)
        .fontSize(13)
        .fontColor(this.getPrimaryColor())
        .lineHeight(22)
        .width('100%')

      if (this.partnerName.length > 0) {
        Text(`搭子：${this.partnerName}`)
          .fontSize(13)
          .fontColor(this.getPrimaryColor())
          .lineHeight(22)
          .width('100%')
      }

      if (this.datetimeLabel.length > 0) {
        Text(`时间：${this.datetimeLabel}`)
          .fontSize(13)
          .fontColor(this.getSecondaryColor())
          .lineHeight(22)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
