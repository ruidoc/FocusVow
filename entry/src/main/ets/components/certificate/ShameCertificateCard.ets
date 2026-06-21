import { ShameCertificateData, createEmptyShameCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CertificateQrFooter } from './CertificateQrFooter';

@Component
export struct ShameCertificateCard {
  @Prop data: ShameCertificateData = createEmptyShameCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;

  @Builder
  private buildBorderLine(): void {
    Text('❌ ─────────────────────────────────────────────── ❌')
      .fontSize(11)
      .fontColor('#8B3030')
      .width('100%')
      .textAlign(TextAlign.Center)
  }

  @Builder
  private buildStamp(): void {
    Column() {
      Text('耻辱作废印')
        .fontSize(10)
        .fontColor('#D64545')
        .fontWeight(FontWeight.Medium)
    }
    .width(88)
    .height(88)
    .justifyContent(FlexAlign.Center)
    .border({ width: 2, color: '#D64545' })
    .borderRadius(44)
    .rotate({ angle: 10 })
    .opacity(0.82)
  }

  build() {
    Column({ space: 14 }) {
      this.buildBorderLine()

      Text('违  约  耻  辱  证')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F2D0D0')
        .letterSpacing(4)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text('BREACH OF CONTRACT NOTICE')
        .fontSize(11)
        .fontColor('#B07A7A')
        .letterSpacing(1)
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(`警告：考生 [ ${this.data.userName} ] 于 ${this.data.datetimeLabel}`)
        .fontSize(13)
        .fontColor('#E8CACA')
        .lineHeight(22)
        .width('100%')

      Text(this.data.breachNarrative)
        .fontSize(13)
        .fontColor('#E8CACA')
        .lineHeight(22)
        .width('100%')

      Column({ space: 6 }) {
        Text('行为判定：')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2D0D0')
          .width('100%')
        Text(this.data.behaviorVerdict)
          .fontSize(13)
          .fontColor('#E8CACA')
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Text('惩罚附赠：')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2D0D0')
          .width('100%')
        Text(this.data.punishmentLabel)
          .fontSize(13)
          .fontColor('#E8CACA')
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      Column({ space: 8 }) {
        Text('【 灵魂拷问法庭 】')
          .fontSize(13)
          .fontColor('#F2D0D0')
          .width('100%')
          .textAlign(TextAlign.End)
        Row() {
          Blank()
          this.buildStamp()
        }
        .width('100%')
      }
      .width('100%')

      Text('────────────────────────────────')
        .fontSize(11)
        .fontColor('#6A3030')
        .width('100%')
        .textAlign(TextAlign.Center)

      CertificateQrFooter({
        qrContent: this.data.qrContent,
        footerSlogan: this.data.footerSlogan,
        darkTheme: true
      })
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#1A0A0A')
    .border({ width: 2, color: '#8B3030' })
    .borderRadius(12)
    .id(this.snapshotId)
  }
}
