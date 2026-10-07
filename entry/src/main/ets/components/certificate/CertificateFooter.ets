import { CONTRACT_FONT } from '../../utils/CertificateTemplate';
import { StoreKeys } from '../../stores/StoreKeys';

@Component
export struct CertificateFooter {
  @Prop footerBrand: string = '专注契约';
  @Prop footerDatetime: string = '';
  @Prop adSlogan: string = '';
  @Prop darkTheme: boolean = false;
  @StorageLink(StoreKeys.CertificateScale) certScale: number = 1;

  private fs(value: number): number {
    const scale = this.certScale > 0 ? this.certScale : 1;
    return Math.round(value * scale * 10) / 10;
  }

  build() {
    Column({ space: 4 }) {
      Text('专注契约公证处公证')
        .fontSize(this.fs(14))
        .fontFamily(CONTRACT_FONT)
        .letterSpacing(1)
        .fontColor(this.darkTheme ? 'rgba(242, 208, 208, 0.95)' : '#3E2A12')
        .margin({ bottom: 5 })
      if (this.footerDatetime.length > 0) {
        Text(this.footerDatetime)
          .fontSize(this.fs(13))
          .fontFamily(CONTRACT_FONT)
          .letterSpacing(0.5)
          .fontColor(this.darkTheme ? 'rgba(216, 175, 175, 0.85)' : 'rgba(92, 70, 32, 0.85)')
      }
      Text(`—— ${this.footerBrand}APP`)
        .fontSize(this.fs(15))
        .fontFamily(CONTRACT_FONT)
        .letterSpacing(0.8)
        .fontColor(this.darkTheme ? 'rgba(242, 208, 208, 0.95)' : '#3E2A12')
        .margin({ left: 6, top: 30, bottom: 18 })
    }
    .alignItems(HorizontalAlign.Start)
    .constraintSize({ maxWidth: '65%' })
  }
}
