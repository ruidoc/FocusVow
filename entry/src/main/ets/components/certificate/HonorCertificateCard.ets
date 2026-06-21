import { HonorCertificateData, createEmptyHonorCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CertificateQrFooter } from './CertificateQrFooter';

@Component
export struct HonorCertificateCard {
  @Prop data: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;

  @Builder
  private buildBorderLine(): void {
    Text('★ ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ── ★')
      .fontSize(11)
      .fontColor('#B8943F')
      .width('100%')
      .textAlign(TextAlign.Center)
  }

  @Builder
  private buildStamp(): void {
    Column() {
      Text('获准上岸印')
        .fontSize(10)
        .fontColor('#B42318')
        .fontWeight(FontWeight.Medium)
    }
    .width(88)
    .height(88)
    .justifyContent(FlexAlign.Center)
    .border({ width: 2, color: '#B42318' })
    .borderRadius(44)
    .rotate({ angle: -12 })
    .opacity(0.82)
  }

  build() {
    Column({ space: 14 }) {
      this.buildBorderLine()

      Text('履  约  荣  誉  证')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3B1F')
        .letterSpacing(4)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text('HONOR CERTIFICATE')
        .fontSize(11)
        .fontColor('#9A8458')
        .letterSpacing(1)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(`兹证明 考生 [ ${this.data.userName} ] 于 ${this.data.dateLabel}`)
        .fontSize(13)
        .fontColor('#3D3424')
        .lineHeight(22)
        .width('100%')

      Text(`在「${this.data.contractTitle}」${this.data.modeLabel}中，坚守本心，枯坐 ${this.data.durationMinutes} 分钟。`)
        .fontSize(13)
        .fontColor('#3D3424')
        .lineHeight(22)
        .width('100%')

      Column({ space: 6 }) {
        Text('行为判定：')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4A3B1F')
          .width('100%')
        Text(this.data.behaviorVerdict)
          .fontSize(13)
          .fontColor('#3D3424')
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Text(this.data.closingRemark)
        .fontSize(13)
        .fontColor('#3D3424')
        .lineHeight(22)
        .width('100%')

      Column({ space: 8 }) {
        Text('【 专注契约公证处 】')
          .fontSize(13)
          .fontColor('#4A3B1F')
          .width('100%')
          .textAlign(TextAlign.End)
        Text(`日期：${this.data.issuedAt}`)
          .fontSize(12)
          .fontColor('#7A6A4A')
          .width('100%')
          .textAlign(TextAlign.End)
        Row() {
          Blank()
          this.buildStamp()
        }
        .width('100%')
      }
      .width('100%')

      this.buildBorderLine()

      CertificateQrFooter({
        qrContent: this.data.qrContent,
        footerSlogan: this.data.footerSlogan,
        darkTheme: false
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFBF4')
    .border({ width: 2, color: '#C9A84C' })
    .borderRadius(12)
    .id(this.snapshotId)
  }
}
