import { ShameCertificateData, createEmptyShameCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { shameCertificateBackground, isCertificateDarkTheme } from '../../utils/CertificateTemplate';
import { CertificateContractBody } from './CertificateContractBody';
import { CertificateFooter } from './CertificateFooter';

const WARNING_ASPECT_RATIO: number = 1086 / 1448;
const SEAL_SIZE: number = 126;
const CARD_PADDING_H: number = 26;
const CARD_PADDING_TOP: number = 50;
const CARD_PADDING_BOTTOM: number = 38;

@Component
export struct VictimShameCertificateCard {
  @Prop data: ShameCertificateData = createEmptyShameCertificateData();
  @Prop snapshotId: string = CERTIFICATE_SNAPSHOT_ID;
  @Prop templateStyle: string = 'classic';

  @Builder
  private buildBody(): void {
    CertificateContractBody({
      kind: 'victim',
      templateStyle: this.templateStyle,
      title: this.data.cardTitle,
      datetime: this.data.footerDatetime,
      userName: this.data.userName,
      partnerName: this.data.counterpartName,
      contractTitle: this.data.contractTitle,
      totalMinutes: this.data.totalMinutes,
      actualMinutes: this.data.actualMinutes
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Image(shameCertificateBackground(this.templateStyle))
        .width('100%')
        .aspectRatio(WARNING_ASPECT_RATIO)
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
          darkTheme: isCertificateDarkTheme('shame', this.templateStyle)
        })
          .margin({ left: 36, bottom: 40 })
      }
      .width('100%')
      .height('100%')
      .zIndex(5)

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fail'))
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
    .aspectRatio(WARNING_ASPECT_RATIO)
    .id(this.snapshotId)
  }
}
