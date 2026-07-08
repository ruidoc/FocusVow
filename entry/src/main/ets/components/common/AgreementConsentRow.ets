import { AppTheme } from "../../constants/Theme";
import { pushPrivacyPolicy, pushUserAgreement } from "../../router/PageRoutes";
@Component
export struct AgreementConsentRow {
  @Prop agreed: boolean = false;
  onAgreedChange?: (agreed: boolean) => void;

  private setAgreed(agreed: boolean): void {
    this.onAgreedChange?.(agreed);
  }

  build() {
    Row({ space: 3 }) {
      Checkbox()
        .select(this.agreed)
        .selectedColor(AppTheme.colors.primary)
        .width(15)
        .height(15)
        .onChange((checked: boolean) => {
          this.setAgreed(checked);
        })
      Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
        Text("我已阅读并同意")
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .onClick(() => {
            this.setAgreed(!this.agreed);
          })
        Text("《隐私政策》")
          .fontSize(12)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            pushPrivacyPolicy();
          })
        Text("和")
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .onClick(() => {
            this.setAgreed(!this.agreed);
          })
        Text("《用户协议》")
          .fontSize(12)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            pushUserAgreement();
          })
      }
      .layoutWeight(1)
      .margin({ top: 1 })
    }
    .width("100%")
    .alignItems(VerticalAlign.Center);
  }
}
