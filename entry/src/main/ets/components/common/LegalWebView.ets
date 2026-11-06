import { webview } from '@kit.ArkWeb';
import { pushUserProfile } from '../../router/PageRoutes';

function nativeProfileId(url: string): string {
  const matched = url.match(/\/user\/([a-fA-F0-9]{16,})(?:[/?#]|$)/);
  if (!matched || matched.length < 2) {
    return '';
  }
  return matched[1];
}

@Component
export struct LegalWebView {
  @Prop url: string = '';
  /** 挑战页里头像跳 /user/:id 时，改走原生个人中心 */
  @Prop openNativeProfile: boolean = false;

  private controller: webview.WebviewController = new webview.WebviewController();

  private openProfileFromUrl(url: string): boolean {
    if (!this.openNativeProfile) {
      return false;
    }
    const userId = nativeProfileId(url);
    if (userId.length === 0) {
      return false;
    }
    pushUserProfile(userId);
    return true;
  }

  build() {
    Web({ src: this.url, controller: this.controller })
      .width('100%')
      .height('100%')
      .domStorageAccess(true)
      .javaScriptAccess(true)
      .onOverrideUrlLoading((request: WebResourceRequest): boolean => {
        return this.openProfileFromUrl(request.getRequestUrl());
      })
  }
}
