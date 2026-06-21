import { LegalWebView } from '../../components/common/LegalWebView';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { LegalUrls } from '../../constants/LegalUrls';
import { backRoute } from '../../router/PageRoutes';

@Entry
@Component
struct PrivacyPolicyPage {
  @Builder
  private buildWebContent(): void {
    LegalWebView({ url: LegalUrls.PRIVACY })
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '隐私政策',
        showBack: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bottomSpacerHeight: 0,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildWebContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
