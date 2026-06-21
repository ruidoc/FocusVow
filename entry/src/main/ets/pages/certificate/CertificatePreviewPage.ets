import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { HonorCertificateCard } from '../../components/certificate/HonorCertificateCard';
import { ShameCertificateCard } from '../../components/certificate/ShameCertificateCard';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  createEmptyHonorCertificateData,
  createEmptyShameCertificateData,
  HonorCertificateData,
  ShameCertificateData
} from '../../models/CertificateModel';
import { backRoute } from '../../router/PageRoutes';
import {
  CERTIFICATE_SNAPSHOT_ID,
  formatSaveError,
  saveCertificateSnapshot
} from '../../services/CertificateImageService';
import { StoreKeys } from '../../stores/StoreKeys';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct CertificatePreviewPage {
  @State kind: string = 'honor';
  @State honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @State shameData: ShameCertificateData = createEmptyShameCertificateData();
  @State isSaving: boolean = false;
  @State qrReady: boolean = false;

  aboutToAppear(): void {
    this.kind = AppStorage.get<string>(StoreKeys.CertificateKind) ?? 'honor';
    this.honorData = AppStorage.get<HonorCertificateData>(StoreKeys.CertificateHonor) ?? createEmptyHonorCertificateData();
    this.shameData = AppStorage.get<ShameCertificateData>(StoreKeys.CertificateShame) ?? createEmptyShameCertificateData();
    setTimeout(() => {
      this.qrReady = true;
    }, 320);
  }

  private getPageTitle(): string {
    return this.kind === 'shame' ? '违约耻辱证' : '履约荣誉证';
  }

  private async handleSave(): Promise<void> {
    if (this.isSaving || !this.qrReady) {
      return;
    }
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await saveCertificateSnapshot(this.getUIContext(), hostContext, CERTIFICATE_SNAPSHOT_ID);
      showToast('证书已保存到相册', this.getUIContext());
    } catch (error) {
      const message = formatSaveError(error as BusinessError);
      showErrorToast(message, this.getUIContext());
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private buildCertificate(): void {
    if (this.kind === 'shame') {
      ShameCertificateCard({ data: this.shameData })
    } else {
      HonorCertificateCard({ data: this.honorData })
    }
  }

  @Builder
  private buildSaveButton(): void {
    if (this.isSaving) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.arrow_down'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor([AppTheme.colors.primary])

        Text('保存中...')
          .fontSize(15)
          .fontColor(AppTheme.colors.primary)
      }
      .width('100%')
      .height(50)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(AppTheme.colors.primarySoft)
      .opacity(0.7)
      .borderRadius(AppTheme.radius.pill)
    } else {
      SaveButton({
        icon: SaveIconStyle.FULL_FILLED,
        text: SaveDescription.SAVE_TO_GALLERY,
        buttonType: ButtonType.Capsule
      })
        .width('100%')
        .height(50)
        .fontSize(15)
        .fontColor(AppTheme.colors.primary)
        .iconColor(AppTheme.colors.primary)
        .iconSize(18)
        .textIconSpace(8)
        .layoutDirection(SecurityComponentLayoutDirection.HORIZONTAL)
        .backgroundColor(AppTheme.colors.primarySoft)
        .enabled(this.qrReady)
        .onClick(async (_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            await this.handleSave();
          } else {
            showErrorToast('未获得相册保存授权', this.getUIContext());
          }
        })
    }
  }

  @Builder
  private buildContent(): void {
    Column({ space: 18 }) {
      this.buildCertificate()

      this.buildSaveButton()

      if (!this.qrReady) {
        Text('正在生成证书二维码...')
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildContent();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
