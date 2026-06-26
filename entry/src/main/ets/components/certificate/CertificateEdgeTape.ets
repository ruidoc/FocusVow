@Component
export struct CertificateEdgeTape {
  @Prop label: string = '';
  @Prop darkTheme: boolean = false;

  build() {
    Text(this.label)
      .fontSize(9)
      .fontColor(this.darkTheme ? '#6A4040' : '#9A8458')
      .letterSpacing(1)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Clip })
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 6, bottom: 6 })
      .opacity(0.85)
  }
}
