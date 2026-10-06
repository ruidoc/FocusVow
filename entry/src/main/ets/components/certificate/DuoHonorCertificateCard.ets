import { HonorCertificateData, createEmptyHonorCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { honorCertificateBackground, isCertificateDarkTheme } from '../../utils/CertificateTemplate';
import { CertificateContractBody } from './CertificateContractBody';
import { CertificateFooter } from './CertificateFooter';

const HONOR_ASPECT_RATIO: number = 1086 / 1448;
const SEAL_SIZE: number = 126;
const CARD_PADDING_H: number = 26;
const CARD_PADDING_TOP: number = 58;
const CARD_PADDING_BOTTOM: number = 38;

@Component
export struct DuoHonorCertificateCard {
  @Prop data: HonorCertificateData = createEmptyHonorCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;
  @Prop templateStyle: string = 'classic';

  @Builder
  private buildBody(): void {
    CertificateContractBody({
      kind: 'duo',
      templateStyle: this.templateStyle,
      title: this.data.cardTitle,
      datetime: this.data.footerDatetime,
      userName: this.data.userName,
      partnerName: this.data.partnerName,
      contractTitle: this.data.contractTitle,
      minutes: this.data.durationMinutes
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(honorCertificateBackground(this.templateStyle))
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
          darkTheme: isCertificateDarkTheme('honor', this.templateStyle)
        })
          .margin({ left: 36, bottom: 40 })
      }
      .width('100%')
      .height('100%')
      .zIndex(5)

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fulfill'))
          .width(SEAL_SIZE)
          .height(SEAL_SIZE)
          .objectFit(ImageFit.Contain)
          .margin({ right: 22, bottom: 38 })
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
