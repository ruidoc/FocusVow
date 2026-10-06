import { common } from '@kit.AbilityKit';
import { showErrorToast } from '../../common/Toast';
import { AppTheme } from '../../constants/Theme';
import {
  CertificatePendingSnapshot,
  clearPendingCertificate,
  getPendingCertificate,
} from '../../services/CertificatePendingService';
import {
  buildHonorCertificateFromLock,
  buildShameCertificateFromLock,
} from '../../services/CertificateCopyService';
import {
  openHonorCertificatePreview,
  openShameCertificatePreview,
} from '../../services/CertificateNavigationService';
import { onCertificateGuideDismissed } from '../../services/GuestSoloFocusService';
import { WeComCustomerService } from '../../services/WeComCustomerService';
import { UserStore } from '../../stores/UserStore';
import { PageRoutes, pushRoute, returnToMainTab } from '../../router/PageRoutes';
import { bootstrapStores } from '../../stores/StoreBootstrap';

bootstrapStores();

@Entry
@Component
struct FocusResultPage {
  @State pending: CertificatePendingSnapshot | null = null;
  @State loggedIn: boolean = false;

  aboutToAppear(): void {
    this.pending = getPendingCertificate();
    this.loggedIn = UserStore.isLoggedIn();
    if (!this.pending) {
      returnToMainTab('focus');
    }
  }

  private isSuccess(): boolean {
    return this.pending !== null && this.pending.kind === 'honor';
  }

  private planTitle(): string {
    const title = this.pending?.lock.title?.trim() ?? '';
    return title.length > 0 ? title : '专注契约';
  }

  private actualMinutes(): number {
    if (!this.pending || this.pending.lock.startedAt <= 0) {
      return 0;
    }
    const seconds = Math.max(0, Math.floor((this.pending.endedAt - this.pending.lock.startedAt) / 1000));
    return Math.floor(seconds / 60);
  }

  private openCertificate(): void {
    const pending = this.pending;
    if (!pending || !this.loggedIn) {
      return;
    }
    const user = UserStore.getUserInfo();
    clearPendingCertificate();
    if (pending.kind === 'honor') {
      openHonorCertificatePreview(buildHonorCertificateFromLock(pending.lock, user, pending.endedAt));
      return;
    }
    openShameCertificatePreview(buildShameCertificateFromLock(
      pending.lock,
      user,
      pending.endedAt,
      pending.breachRole,
      pending.failedReason,
    ));
  }

  private goHome(): void {
    clearPendingCertificate();
    onCertificateGuideDismissed(this.getUIContext());
    returnToMainTab('focus');
  }

  private async onContactSupport(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const errorMessage = await WeComCustomerService.open(hostContext, 'focus_result');
    if (errorMessage !== null) {
      showErrorToast(errorMessage, this.getUIContext());
    }
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        SymbolGlyph(this.isSuccess() ? $r('sys.symbol.checkmark_circle_fill') : $r('sys.symbol.exclamationmark_circle_fill'))
          .fontSize(72)
          .fontColor([this.isSuccess() ? AppTheme.colors.success : AppTheme.colors.warning])
        Text(this.isSuccess() ? '契约履行完成' : '违约耻辱证已生成')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
        Text(this.isSuccess() ? '契约已履行，继续保持' : '本次未守完全程')
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 120 })

      Column({ space: 12 }) {
        Row() {
          Text('契约')
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Blank()
          Text(this.planTitle())
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '70%' })
        }
        .width('100%')
        if (this.actualMinutes() > 0) {
          Row() {
            Text('专注时长')
              .fontSize(14)
              .fontColor(AppTheme.colors.textSecondary)
            Blank()
            Text(`${this.actualMinutes()} 分钟`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.textPrimary)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .margin({ top: 28 })
      .borderRadius(16)
      .backgroundColor(AppTheme.colors.surface)

      Blank()

      if (this.loggedIn) {
        Button(this.isSuccess() ? '查看履约证' : '查看违约记录')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            this.openCertificate();
          })
        Button('回到首页')
          .width('100%')
          .height(48)
          .margin({ top: 10 })
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .onClick(() => {
            this.goHome();
          })
      } else {
        Text('登录同步本次专注')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text('记录已暂存本机，登录后自动同步到账号')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ top: 6, bottom: 12 })
        Button('去登录')
          .width('100%')
          .height(48)
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            clearPendingCertificate();
            pushRoute(PageRoutes.Login);
          })
        Button('稍后再说')
          .width('100%')
          .height(48)
          .margin({ top: 10 })
          .backgroundColor(AppTheme.colors.surface)
          .fontColor(AppTheme.colors.textPrimary)
          .onClick(() => {
            this.goHome();
          })
      }

      Row() {
        Text('发现问题？请立即反馈')
          .fontSize(14)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            pushRoute(PageRoutes.Feedback);
          })
        Text('，')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
        Text('或联系客服')
          .fontSize(14)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            void this.onContactSupport();
          })
      }
      .margin({ top: 12 })
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, bottom: 32 })
    .backgroundColor(AppTheme.colors.background)
  }
}
