import { getAppVersion } from '../../common/AppInfo';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { LegalUrls } from '../../constants/LegalUrls';
import { backRoute, pushWebView } from '../../router/PageRoutes';

@Entry
@Component
struct AboutPage {
  @State appVersion: string = '';

  aboutToAppear(): void {
    void getAppVersion().then((version: string) => {
      this.appVersion = version;
    });
  }

  @Builder
  private buildBrandSection(): void {
    Column({ space: 8 }) {
      Image($r('app.media.background'))
        .width(130)
        .height(130)
        .objectFit(ImageFit.Contain)

      Text('专注契约')
        .fontSize(24)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .letterSpacing(2)

      if (this.appVersion.length > 0) {
        Text(`版本 v${this.appVersion}`)
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildFooterLinks(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text('京ICP备2024096030号-1A')
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            pushWebView(LegalUrls.ICP_BEIAN, '备案信息');
          })

        Text('《隐私政策》')
          .fontSize(13)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            pushWebView(LegalUrls.PRIVACY, '隐私政策');
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Text('北京自由岸科技 ©️版权所有')
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 24, bottom: 8 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildContent(): void {
    Column() {
      Blank()
        .layoutWeight(1)

      this.buildBrandSection()

      Blank()
        .layoutWeight(1)

      this.buildFooterLinks()
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '关于我们',
        showBack: true,
        usePageScroll: false,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
