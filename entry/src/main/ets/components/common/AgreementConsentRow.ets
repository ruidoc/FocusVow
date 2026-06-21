import { AppTheme } from '../../constants/Theme';
import { pushPrivacyPolicy, pushUserAgreement } from '../../router/PageRoutes';

@Component
export struct AgreementConsentRow {
  build() {
    Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
      Text('登录即表示已阅读并同意')
        .fontSize(12)
        .fontColor(AppTheme.colors.textSecondary)

      Text('《隐私政策》')
        .fontSize(12)
        .fontColor(AppTheme.colors.primary)
        .onClick(() => {
          pushPrivacyPolicy();
        })

      Text('和')
        .fontSize(12)
        .fontColor(AppTheme.colors.textSecondary)

      Text('《用户协议》')
        .fontSize(12)
        .fontColor(AppTheme.colors.primary)
        .onClick(() => {
          pushUserAgreement();
        })
    }
    .width('100%')
  }
}
