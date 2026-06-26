import { HonorCertificateData, createEmptyHonorCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { CertificateFooter } from './CertificateFooter';
import { CertificateInfoSection } from './CertificateInfoSection';

const HONOR_ASPECT_RATIO: number = 1086 / 1448;
const SEAL_SIZE: number = 126;
const CARD_PADDING_H: number = 28;
const CARD_PADDING_TOP: number = 64;
const CARD_PADDING_BOTTOM: number = 44;

@Component
export struct DuoHonorCertificateCard {
  @Prop data: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;

  @Builder
  private buildBody(): void {
    Column({ space: 14 }) {
      Text(this.data.modeLabel)
        .fontSize(11)
        .fontColor('#9A8458')
        .width('100%')
        .textAlign(TextAlign.Center)

      Text(this.data.cardTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#4A3B1F')
        .letterSpacing(4)
        .width('100%')
        .textAlign(TextAlign.Center)

      CertificateInfoSection({
        userName: this.data.userName,
        partnerName: this.data.partnerName,
        datetimeLabel: this.data.footerDatetime,
        darkTheme: false
      })

      Column({ space: 4 }) {
        Text(`${this.data.durationMinutes} 分钟`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#6B4F1F')
          .width('100%')
          .textAlign(TextAlign.Center)
        Text(this.data.contractTitle)
          .fontSize(13)
          .fontColor('#4A3B1F')
          .width('100%')
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .padding({ top: 10, bottom: 10 })
      .border({ width: 1, color: '#D8C8A0' })
      .borderRadius(8)

      Text(this.data.resultNarrative)
        .fontSize(13)
        .fontColor('#3D3424')
        .lineHeight(22)
        .width('100%')
    }
    .width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image($r('app.media.temp_honor'))
        .width('100%')
        .aspectRatio(HONOR_ASPECT_RATIO)
        .objectFit(ImageFit.Cover)

      Column() {
        this.buildBody()
      }
      .width('100%')
      .height('100%')
      .padding({
        left: CARD_PADDING_H,
        right: CARD_PADDING_H,
        top: CARD_PADDING_TOP,
        bottom: CARD_PADDING_BOTTOM + 72
      })
      .zIndex(1)

      Stack({ alignContent: Alignment.BottomStart }) {
        CertificateFooter({
          footerBrand: this.data.footerBrand,
          footerDatetime: this.data.footerDatetime,
          adSlogan: this.data.adSlogan,
          darkTheme: false
        })
          .margin({ left: CARD_PADDING_H, bottom: CARD_PADDING_BOTTOM })
      }
      .width('100%')
      .height('100%')
      .zIndex(5)

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fulfill'))
          .width(SEAL_SIZE)
          .height(SEAL_SIZE)
          .objectFit(ImageFit.Contain)
          .margin({ right: 20, bottom: 30 })
      }
      .width('100%')
      .height('100%')
      .zIndex(10)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .aspectRatio(HONOR_ASPECT_RATIO)
    .borderRadius(12)
    .clip(true)
    .id(this.snapshotId)
  }
}
