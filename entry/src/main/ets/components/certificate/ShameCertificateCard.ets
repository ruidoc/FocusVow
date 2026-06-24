import { ShameCertificateData, createEmptyShameCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CertificateQrFooter } from './CertificateQrFooter';

const WARNING_ASPECT_RATIO: number = 1086 / 1448;
const SEAL_SIZE: number = 126;

@Component
export struct ShameCertificateCard {
  @Prop data: ShameCertificateData = createEmptyShameCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;

  @Builder
  private buildBody(): void {
    Column({ space: 12 }) {
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
          .padding({ right: SEAL_SIZE + 8 })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.temp_warning'))
        .width('100%')
        .aspectRatio(WARNING_ASPECT_RATIO)
        .objectFit(ImageFit.Cover)

      Column() {
        this.buildBody()

        CertificateQrFooter({
          qrContent: this.data.qrContent,
          footerSlogan: this.data.footerSlogan,
          darkTheme: true
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 28, right: 28, top: 72, bottom: 44 })

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fail'))
          .width(SEAL_SIZE)
          .height(SEAL_SIZE)
          .objectFit(ImageFit.Contain)
          .margin({ right: 20, bottom: 30 })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .aspectRatio(WARNING_ASPECT_RATIO)
    .borderRadius(12)
    .clip(true)
    .id(this.snapshotId)
  }
}
