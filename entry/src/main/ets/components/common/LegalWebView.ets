import { webview } from '@kit.ArkWeb';

@Component
export struct LegalWebView {
  @Prop url: string = '';

  private controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Web({ src: this.url, controller: this.controller })
      .width('100%')
      .height('100%')
      .domStorageAccess(true)
      .javaScriptAccess(true)
  }
}
