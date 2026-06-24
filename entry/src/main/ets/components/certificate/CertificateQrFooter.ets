import { BusinessError } from '@kit.BasicServicesKit';
import { generateBarcode, scanCore } from '@kit.ScanKit';
import { image } from '@kit.ImageKit';

@Component
export struct CertificateQrFooter {
  @Prop qrContent: string = 'FocusVow';
  @Prop footerSlogan: string = '';
  @Prop darkTheme: boolean = false;
  @State private qrPixelMap: image.PixelMap | undefined = undefined;

  aboutToAppear(): void {
    void this.loadQrCode();
  }

  private async loadQrCode(): Promise<void> {
    const content = this.qrContent.length > 0 ? this.qrContent : 'FocusVow';
    const options: generateBarcode.CreateOptions = {
      scanType: scanCore.ScanType.QR_CODE,
      width: 120,
      height: 120
    };
    try {
      this.qrPixelMap = await generateBarcode.createBarcode(content, options);
    } catch (error) {
      const err = error as BusinessError;
      console.error(`generate QR failed: ${err.code} ${err.message}`);
    }
  }

  @Builder
  private buildQrCode(): void {
    if (this.qrPixelMap) {
      Image(this.qrPixelMap)
        .width(56)
        .height(56)
        .backgroundColor('#FFFFFF')
        .padding(4)
        .borderRadius(6)
    } else {
      Column() {
        Text('QR')
          .fontSize(10)
          .fontColor(this.darkTheme ? '#D8A0A0' : '#7A6A4A')
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.darkTheme ? '#2A1414' : '#FFFFFF')
      .border({ width: 1, color: this.darkTheme ? '#6A3030' : '#D8C8A0' })
      .borderRadius(6)
    }
  }

  build() {
    Row({ space: 12 }) {
      this.buildQrCode()

      Text(this.footerSlogan)
        .fontSize(11)
        .fontColor(this.darkTheme ? '#D8A0A0' : '#7A6A4A')
        .lineHeight(18)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 4 })
    .alignItems(VerticalAlign.Center)
  }
}
