import { router } from '@kit.ArkUI';
import { LegalWebView } from '../../components/common/LegalWebView';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { LegalUrls } from '../../constants/LegalUrls';
import { backRoute } from '../../router/PageRoutes';

interface WebViewRouteParams {
  url?: string;
  title?: string;
}

@Entry
@Component
struct WebViewPage {
  @State pageUrl: string = LegalUrls.PRIVACY;
  @State pageTitle: string = '详情';

  aboutToAppear(): void {
    const params = router.getParams() as WebViewRouteParams;
    if (params?.url && params.url.length > 0) {
      this.pageUrl = params.url;
    }
    if (params?.title && params.title.length > 0) {
      this.pageTitle = params.title;
    }
  }

  @Builder
  private buildWebContent(): void {
    LegalWebView({ url: this.pageUrl })
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.pageTitle,
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
