import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { DuoHonorCertificateCard } from '../../components/certificate/DuoHonorCertificateCard';
import { HonorCertificateCard } from '../../components/certificate/HonorCertificateCard';
import { ShameCertificateCard } from '../../components/certificate/ShameCertificateCard';
import { TraitorShameCertificateCard } from '../../components/certificate/TraitorShameCertificateCard';
import { VictimShameCertificateCard } from '../../components/certificate/VictimShameCertificateCard';
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
  CERTIFICATE_SNAPSHOT_ID,
  formatSaveError,
  saveCertificateSnapshot
} from '../../services/CertificateImageService';
import { StoreKeys } from '../../stores/StoreKeys';
import {
  CERTIFICATE_TEMPLATES,
  certificateTemplateLabel,
} from '../../utils/CertificateTemplate';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct CertificatePreviewPage {
  @State kind: string = 'honor';
  @State honorData: HonorCertificateData = createEmptyHonorCertificateData();
  @State shameData: ShameCertificateData = createEmptyShameCertificateData();
  @State isSaving: boolean = false;
  @State templateStyle: string = 'classic';
  @State templateIndex: number = 0;
  @State posterWidth: number = 320;

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

  private posterHeight(): number {
    const width = this.posterWidth > 0 ? this.posterWidth : 320;
    return Math.round(width * 1448 / 1086);
  }

  private snapshotIdFor(style: string): string {
    return `${CERTIFICATE_SNAPSHOT_ID}_${style}`;
  }

  private async handleSave(): Promise<void> {
    if (this.isSaving) {
      return;
    }
    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      await saveCertificateSnapshot(this.getUIContext(), hostContext, this.snapshotIdFor(this.templateStyle));
      showToast('证书已保存到相册', this.getUIContext());
    } catch (error) {
      const message = formatSaveError(error as BusinessError);
      showErrorToast(message, this.getUIContext());
    } finally {
      this.isSaving = false;
    }
  }

  @Builder
  private buildCertificate(style: string): void {
    if (this.kind === 'shame') {
      if (this.shameData.shameVariant === 'victim') {
        VictimShameCertificateCard({
          data: this.shameData,
          templateStyle: style,
          snapshotId: this.snapshotIdFor(style)
        })
      } else if (this.shameData.shameVariant === 'violator') {
        TraitorShameCertificateCard({
          data: this.shameData,
          templateStyle: style,
          snapshotId: this.snapshotIdFor(style)
        })
      } else {
        ShameCertificateCard({
          data: this.shameData,
          templateStyle: style,
          snapshotId: this.snapshotIdFor(style)
        })
      }
    } else if (isDuoHonorCertificate(this.honorData)) {
      DuoHonorCertificateCard({
        data: this.honorData,
        templateStyle: style,
        snapshotId: this.snapshotIdFor(style)
      })
    } else {
      HonorCertificateCard({
        data: this.honorData,
        templateStyle: style,
        snapshotId: this.snapshotIdFor(style)
      })
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
    Column() {
      Column() {
        Swiper() {
          ForEach(CERTIFICATE_TEMPLATES, (style: string) => {
            Column() {
              this.buildCertificate(style)
            }
            .width('100%')
            .height(this.posterHeight())
          }, (style: string) => style)
        }
        .width('100%')
        .height(this.posterHeight())
        .index(this.templateIndex)
        .loop(false)
        .indicator(false)
        .onChange((index: number) => {
          this.templateIndex = index;
          const next = CERTIFICATE_TEMPLATES[index];
          if (next !== undefined && next.length > 0) {
            this.templateStyle = next;
          }
        })

        Row({ space: 6 }) {
          ForEach(CERTIFICATE_TEMPLATES, (style: string) => {
            Column()
              .width(this.templateStyle === style ? 16 : 6)
              .height(6)
              .borderRadius(3)
              .backgroundColor(this.templateStyle === style ? AppTheme.colors.textPrimary : AppTheme.colors.text3)
          }, (style: string) => `dot_${style}`)
        }
        .margin({ top: 14 })
        .justifyContent(FlexAlign.Center)

        Text(`风格：${certificateTemplateLabel(this.templateStyle)}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .margin({ top: 26 })
      }
      .width('100%')
      .layoutWeight(1)
      .constraintSize({ maxWidth: AppTheme.certificateMaxWidth })
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 12 })
      .onAreaChange((_old: Area, area: Area) => {
        const next = area.width as number;
        if (next > 0 && Math.abs(next - this.posterWidth) > 1) {
          this.posterWidth = next;
          const scale = next / 340;
          AppStorage.setOrCreate(StoreKeys.CertificateScale, scale > 0 ? scale : 1);
        }
      })

      Column({ space: 10 }) {
        if (this.recordId().length > 0) {
          Text('编辑记录')
            .fontSize(15)
            .fontColor(AppTheme.colors.primary)
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .onClick(() => {
              pushRoute(PageRoutes.CertificateAdjust);
            })
        }
        this.buildSaveButton()
      }
      .width('100%')
      .constraintSize({ maxWidth: AppTheme.certificateMaxWidth })
      .padding({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        usePageScroll: false,
        bottomSpacerHeight: 0,
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
