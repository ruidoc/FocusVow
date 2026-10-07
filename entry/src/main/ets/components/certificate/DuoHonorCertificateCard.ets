import { HonorCertificateData, createEmptyHonorCertificateData } from '../../models/CertificateModel';
import { CERTIFICATE_SNAPSHOT_ID } from '../../services/CertificateImageService';
import { honorCertificateBackground, isCertificateDarkTheme } from '../../utils/CertificateTemplate';
import { StoreKeys } from '../../stores/StoreKeys';
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
  @StorageLink(StoreKeys.CertificateScale) certScale: number = 1;

  private fs(value: number): number {
    const scale = this.certScale > 0 ? this.certScale : 1;
    return Math.round(value * scale * 10) / 10;
  }

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
        left: this.fs(CARD_PADDING_H),
        right: this.fs(CARD_PADDING_H),
        top: this.fs(CARD_PADDING_TOP),
        bottom: this.fs(CARD_PADDING_BOTTOM + 72)
      })
      .zIndex(1)

      Stack({ alignContent: Alignment.BottomStart }) {
        CertificateFooter({
          footerBrand: this.data.footerBrand,
          footerDatetime: this.data.footerDatetime,
          adSlogan: this.data.adSlogan,
          darkTheme: isCertificateDarkTheme('honor', this.templateStyle)
        })
          .margin({ left: this.fs(36), bottom: this.fs(40) })
      }
      .width('100%')
      .height('100%')
      .zIndex(5)

      Stack({ alignContent: Alignment.BottomEnd }) {
        Image($r('app.media.seal_fulfill'))
          .width(this.fs(SEAL_SIZE))
          .height(this.fs(SEAL_SIZE))
          .objectFit(ImageFit.Contain)
          .margin({ right: this.fs(22), bottom: this.fs(38) })
      }
      .width('100%')
      .height('100%')
      .zIndex(10)
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .aspectRatio(HONOR_ASPECT_RATIO)
    .id(this.snapshotId)
  }
}
