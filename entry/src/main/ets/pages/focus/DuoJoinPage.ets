import { common } from '@kit.AbilityKit';
import { showErrorToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { QuickFocusOptions } from '../../models/ActiveLockModel';
import { PageRoutes, backRoute, pushRoute, replaceRoute } from '../../router/PageRoutes';
import {
  applyScreenRestriction,
  chooseRestrictedApps,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService, extractDuoInviteToken } from '../../services/DuoInviteClipboardService';
import { LockStore } from '../../stores/LockStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

@Entry
@Component
struct DuoJoinPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State tokenInput: string = '';
  @State preview: DuoSessionView | null = null;
  @State isSubmitting: boolean = false;

  aboutToDisappear(): void {
    DuoInviteClipboardService.clearJoinFlow();
  }

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    if (!UserStore.isLoggedIn()) {
      pushRoute(PageRoutes.Login);
      return;
    }

    const stashedToken = DuoInviteClipboardService.consumeJoinToken();
    if (stashedToken.length > 0) {
      this.tokenInput = stashedToken;
      void this.loadPreview();
    }
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private async loadPreview(): Promise<void> {
    const token = extractDuoInviteToken(this.tokenInput);
    if (token.length === 0) {
      this.toastError('未找到有效口令');
      return;
    }
    const response = await DuoApiService.getByToken(token);
    this.preview = DuoApiService.parseSession(response);
    if (!this.preview) {
      this.toastError(response.message ?? '无法识别口令');
    }
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!this.hasAuthorized) {
      const auth = await requestScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, auth.ok, auth.message);
      if (!auth.ok) {
        this.toastError(auth.message);
        return;
      }
    }
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      return;
    }
    this.toastError(result.message);
  }

  private async confirmJoin(): Promise<void> {
    if (this.isSubmitting || !this.preview) {
      return;
    }
    if (this.selectedTokens.length === 0) {
      this.toastError('请先选择至少 1 个应用');
      return;
    }

    this.isSubmitting = true;
    const token = extractDuoInviteToken(this.tokenInput);
    const response = await DuoApiService.instantJoin(token, this.selectedTokens.length);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      this.toastError(response.message ?? '加入失败');
      this.isSubmitting = false;
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const lockResult = await applyScreenRestriction(this.selectedTokens, 'allow');
    if (!lockResult.ok) {
      this.toastError(lockResult.message);
      this.isSubmitting = false;
      return;
    }

    const focusOptions: QuickFocusOptions = {
      title: session.title,
      duoSessionId: session.session_id,
      recordId: session.record_id || session.my_record_id || '',
      participationMode: 'duo'
    };
    LockStore.startQuickFocus(hostContext, this.selectedTokens, session.duration_min, 'allow', focusOptions);
    this.isSubmitting = false;
    replaceRoute(PageRoutes.FocusHome);
  }

  @Builder
  private buildPreviewCard(): void {
    if (this.preview !== null) {
      Column({ space: 10 }) {
        Text('契约信息')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text(this.preview.title)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        Text(`时长 ${this.preview.duration_min} 分钟 · 白名单模式`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')

        if (this.preview.initiator) {
          Text(`发起人：${this.preview.initiator.nickname}`)
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
        }
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)
    }
  }

  @Builder
  private buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text('要放行的应用')
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)

        Text('+ 选择')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            void this.chooseApps();
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.selectedAppCount === 0) {
        Text('未选择应用')
          .fontSize(15)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
      } else {
        Text(`已选 ${this.selectedAppCount} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
      }
    }
    .width('100%')
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg)
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 18 }) {
      Text('选择要放行的应用，确认后将与搭子同时开始锁机。')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      this.buildPreviewCard()
      this.buildAppCard()

      Button('确认加入并开始')
        .width('100%')
        .height(52)
        .type(ButtonType.Capsule)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .enabled(!this.isSubmitting && this.preview !== null)
        .opacity(!this.isSubmitting && this.preview !== null ? 1 : 0.55)
        .onClick(() => {
          void this.confirmJoin();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      SystemNavPage({
        title: '加入连坐',
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildPageBody();
        }
      })
    }
    .width('100%')
    .height('100%')
  }
}
