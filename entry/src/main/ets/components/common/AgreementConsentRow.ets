import { AppTheme } from "../../constants/Theme";
import { pushPrivacyPolicy } from "../../router/PageRoutes";

/**
 * 对齐 RN Privicy：短文案「已阅读并同意《隐私政策》」，默认水平居中。
 */
@Component
export struct AgreementConsentRow {
  @Prop agreed: boolean = false;
  @Prop centered: boolean = true;
  onAgreedChange?: (agreed: boolean) => void;

  private setAgreed(agreed: boolean): void {
    this.onAgreedChange?.(agreed);
  }

  build() {
    Row({ space: 4 }) {
      Checkbox()
        .select(this.agreed)
        .selectedColor(AppTheme.colors.primary)
        .width(15)
        .height(15)
        .onChange((checked: boolean) => {
          this.setAgreed(checked);
        })
      Text("已阅读并同意")
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .onClick(() => {
          this.setAgreed(!this.agreed);
        })
      Text("《隐私政策》")
        .fontSize(14)
        .fontColor(AppTheme.colors.primary)
        .onClick(() => {
          pushPrivacyPolicy();
        })
    }
    .width('100%')
    .justifyContent(this.centered ? FlexAlign.Center : FlexAlign.Start)
    .alignItems(VerticalAlign.Center);
  }
}
