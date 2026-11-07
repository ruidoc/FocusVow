import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { image } from '@kit.ImageKit';
import { router } from '@kit.ArkUI';
import { showErrorToast, showToast } from '../../common/Toast';
import { GallerySaveButton } from '../../components/common/GallerySaveButton';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { LegalUrls } from '../../constants/LegalUrls';
import { backRoute } from '../../router/PageRoutes';
import { savePixelMapToGallery } from '../../services/CertificateImageService';
import { WeComCustomerService } from '../../services/WeComCustomerService';

const WECHAT_ACCENT: string = '#07C160';
const ADMIN_QR_SIZE: number = 220;

function readEntrySource(): string {
  try {
    const params = router.getParams() as Record<string, Object> | undefined;
    const raw = params?.['entrySource'];
    if (typeof raw === 'string' && raw.trim().length > 0) {
      return raw.trim();
    }
  } catch (_e) {
  }
  return 'contact_page';
}

async function loadAdminQrPixelMap(): Promise<image.PixelMap> {
  const client = http.createHttp();
  try {
    const response = await client.request(LegalUrls.ADMIN_WECHAT_QR, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: 12000,
      readTimeout: 20000,
    });
    if (response.responseCode !== 200 || !(response.result instanceof ArrayBuffer)) {
      throw new Error('download failed');
    }
    const source = image.createImageSource(response.result as ArrayBuffer);
    try {
      return await source.createPixelMap();
    } finally {
      await source.release();
    }
  } finally {
    client.destroy();
  }
}

@Entry
@Component
struct ContactPage {
  @State entrySource: string = 'contact_page';
  @State savingQr: boolean = false;

  aboutToAppear(): void {
    this.entrySource = readEntrySource();
  }

  private async openWecom(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const errorMessage = await WeComCustomerService.open(hostContext, this.entrySource);
    if (errorMessage !== null) {
      showErrorToast(errorMessage, this.getUIContext());
    }
  }

  private async saveAdminQr(): Promise<void> {
    if (this.savingQr) {
      return;
    }
    this.savingQr = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const pixelMap = await loadAdminQrPixelMap();
      await savePixelMapToGallery(hostContext, pixelMap);
      showToast('已保存到相册', this.getUIContext());
    } catch (_error) {
      showErrorToast('保存失败，请重试', this.getUIContext());
    } finally {
      this.savingQr = false;
    }
  }

  @Builder
  private buildWecomCard(): void {
    Column({ space: 12 }) {
      Text('在线客服')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
      Text('优先尝试在线客服；若无法连接，请使用下方二维码')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Button('联系在线客服')
        .width('100%')
        .height(48)
        .type(ButtonType.Normal)
        .borderRadius(AppTheme.radius.button)
        .backgroundColor(WECHAT_ACCENT)
        .fontColor('#FFFFFF')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          void this.openWecom();
        })
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  @Builder
  private buildAdminCard(): void {
    Column({ space: 12 }) {
      Text('添加管理员微信')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
      Text('保存二维码后，打开微信扫一扫添加')
        .fontSize(14)
        .lineHeight(20)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')
      Image(LegalUrls.ADMIN_WECHAT_QR)
        .width(ADMIN_QR_SIZE)
        .height(ADMIN_QR_SIZE)
        .borderRadius(12)
        .objectFit(ImageFit.Contain)
        .alignSelf(ItemAlign.Center)
        .margin({ top: 8, bottom: 8 })
      Row() {
        GallerySaveButton({
          saving: this.savingQr,
          onSave: () => {
            void this.saveAdminQr();
          },
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
  }

  @Builder
  private buildContent(): void {
    Column({ space: 16 }) {
      this.buildWecomCard()
      this.buildAdminCard()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '联系客服',
        showBack: true,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildContent();
        },
      })
    }
    .width('100%')
    .height('100%')
  }
}
