import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { CertificatePreviewPeekCarousel } from '../../components/certificate/CertificatePreviewPeekCarousel';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  createEmptyHonorCertificateData,
  createEmptyShameCertificateData,
  HonorCertificateData,
  isDuoHonorCertificate,
  ShameCertificateData
} from '../../models/CertificateModel';
import { backRoute, PageRoutes, pushRoute } from '../../router/PageRoutes';
import {
  captureComponentSnapshot,
  CERTIFICATE_SNAPSHOT_ID,
  formatSaveError,
  saveCertificateSnapshot
} from '../../services/CertificateImageService';
import {
  buildStatsShareCachePath,
  formatShareError,
  shareStatsImageFile,
  writePixelMapToFile,
} from '../../services/StatsShareService';
import { StoreKeys } from '../../stores/StoreKeys';
import {
  CERTIFICATE_DESIGN_WIDTH,
  CERTIFICATE_TEMPLATES,
  certificateTemplateLabel,
  peekCarouselCardWidth,
} from '../../utils/CertificateTemplate';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct CertificatePreviewPage {
  @State kind: string = 'honor';
  @State honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @State shameData: ShameCertificateData = createEmptyShameCertificateData();
  @State busy: string = '';
  @State templateStyle: string = 'classic';
  @State @Watch('onTemplateIndexChanged') templateIndex: number = 0;
  @State @Watch('onViewportWidthChanged') viewportWidth: number = 0;

  onTemplateIndexChanged(): void {
    const next = CERTIFICATE_TEMPLATES[this.templateIndex];
    if (next !== undefined && next.length > 0) {
      this.templateStyle = next;
    }
  }

  aboutToAppear(): void {
    this.reloadCertificate();
  }

  onPageShow(): void {
    this.reloadCertificate();
  }

  private reloadCertificate(): void {
    this.kind = AppStorage.get<string>(StoreKeys.CertificateKind) ?? 'honor';
    this.honorData = AppStorage.get<HonorCertificateData>(StoreKeys.CertificateHonor) ?? createEmptyHonorCertificateData();
    this.shameData = AppStorage.get<ShameCertificateData>(StoreKeys.CertificateShame) ?? createEmptyShameCertificateData();
  }

  private recordId(): string {
    if (this.kind === 'shame') {
      return this.shameData.recordId;
    }
    return this.honorData.recordId;
  }

  private getPageTitle(): string {
    if (this.kind === 'shame') {
      return this.shameData.cardTitle.length > 0 ? this.shameData.cardTitle : '违约耻辱证';
    }
    if (isDuoHonorCertificate(this.honorData)) {
      return this.honorData.cardTitle.length > 0 ? this.honorData.cardTitle : '神仙搭子证';
    }
    return this.honorData.cardTitle.length > 0 ? this.honorData.cardTitle : '守约荣誉证';
  }

  private cardWidth(): number {
    const base = this.viewportWidth > 0 ? this.viewportWidth : 390;
    return peekCarouselCardWidth(base);
  }

  private posterHeight(): number {
    return Math.round(this.cardWidth() * 1448 / 1086);
  }

  private syncCertificateScale(): void {
    const width = this.cardWidth();
    if (width <= 0) {
      return;
    }
    AppStorage.setOrCreate(StoreKeys.CertificateScale, width / CERTIFICATE_DESIGN_WIDTH);
  }

  private onViewportWidthChanged(): void {
    this.syncCertificateScale();
  }

  private snapshotIdFor(style: string): string {
    return `${CERTIFICATE_SNAPSHOT_ID}_${style}`;
  }

  private async handleSave(): Promise<void> {
    if (this.busy.length > 0) {
      return;
    }
    this.busy = 'save';
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await saveCertificateSnapshot(this.getUIContext(), hostContext, this.snapshotIdFor(this.templateStyle));
      showToast('证书已保存到相册', this.getUIContext());
    } catch (error) {
      const message = formatSaveError(error as BusinessError);
      showErrorToast(message, this.getUIContext());
    } finally {
      this.busy = '';
    }
  }

  private async handleShare(): Promise<void> {
    if (this.busy.length > 0) {
      return;
    }
    this.busy = 'share';
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      const pixelMap = await captureComponentSnapshot(
        this.getUIContext(),
        this.snapshotIdFor(this.templateStyle),
        { scale: 1, waitUntilRenderFinished: true },
      );
      const cachePath = buildStatsShareCachePath(hostContext);
      await writePixelMapToFile(pixelMap, cachePath);
      const shareTitle = this.kind === 'shame' ? '违约证书' : '荣誉证书';
      await shareStatsImageFile(hostContext, cachePath, shareTitle, '专注契约证书');
    } catch (error) {
      showErrorToast(formatShareError(error as BusinessError), this.getUIContext());
    } finally {
      this.busy = '';
    }
  }

  private openAdjust(): void {
    if (this.recordId().length === 0) {
      return;
    }
    pushRoute(PageRoutes.CertificateAdjust);
  }

  @Builder
  private buildPeekCarousel(): void {
    CertificatePreviewPeekCarousel({
      kind: this.kind,
      honorData: this.honorData,
      shameData: this.shameData,
      activeIndex: $templateIndex,
      viewportWidth: $viewportWidth,
    })
  }

  @Builder
  private buildBottomActions(): void {
    Row({ space: 12 }) {
      Row() {
        if (this.busy === 'save') {
          LoadingProgress().width(22).height(22).color(AppTheme.colors.textPrimary)
        } else {
          Text('保存到相册')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
        }
      }
      .layoutWeight(1)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .borderRadius(24)
      .border({ width: 1, color: AppTheme.colors.text3 })
      .onClick(() => {
        void this.handleSave();
      })

      Row() {
        if (this.busy === 'share') {
          LoadingProgress().width(22).height(22).color('#FFFFFF')
        } else {
          Text('分享')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
      }
      .layoutWeight(1)
      .height(48)
      .justifyContent(FlexAlign.Center)
      .borderRadius(24)
      .backgroundColor(AppTheme.colors.primary)
      .onClick(() => {
        void this.handleShare();
      })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 12 })
  }

  @Builder
  private buildContent(): void {
    Column() {
      Column() {
        this.buildPeekCarousel()

        Text(`风格：${certificateTemplateLabel(this.templateStyle)}`)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .margin({ top: 26 })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 12 })

      this.buildBottomActions()
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        showAction: this.recordId().length > 0,
        actionIcon: $r('sys.symbol.square_and_pencil'),
        showActionIcon: true,
        usePageScroll: false,
        horizontalPadding: 0,
        bottomSpacerHeight: 0,
        onBack: () => {
          backRoute();
        },
        onAction: () => {
          this.openAdjust();
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
