import { HonorCertificateData, createEmptyHonorCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CertificateQrFooter } from './CertificateQrFooter';

const HONOR_ASPECT_RATIO: number = 1086 / 1448;
const SEAL_SIZE: number = 126;

@Component
export struct HonorCertificateCard {
  @Prop data: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;

  @Builder
  private buildBody(): void {
    Column({ space: 12 }) {
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
          .padding({ right: SEAL_SIZE + 8 })
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.temp_honor'))
        .width('100%')
        .aspectRatio(HONOR_ASPECT_RATIO)
        .objectFit(ImageFit.Cover)

      Column() {
        this.buildBody()

        CertificateQrFooter({
          qrContent: this.data.qrContent,
          footerSlogan: this.data.footerSlogan,
          darkTheme: false
        })
      }
      .width('100%')
      .height('100%')
      .padding({ left: 28, right: 28, top: 72, bottom: 44 })

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fulfill'))
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
    .aspectRatio(HONOR_ASPECT_RATIO)
    .borderRadius(12)
    .clip(true)
    .id(this.snapshotId)
  }
}
