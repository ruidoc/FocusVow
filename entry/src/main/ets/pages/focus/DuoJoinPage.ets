import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { PageRoutes, backRoute, pushRoute, navigateToMainTab } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization,
  requestScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService, extractDuoInviteToken } from '../../services/DuoInviteClipboardService';
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus
} from '../../services/DuoInstantLockService';
import { markGuardSyncIssue, syncGuardForSession } from '../../services/ScheduledCovenantService';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
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
  @State isLoadingPreview: boolean = false;
  @State isSubmitting: boolean = false;

  aboutToDisappear(): void {
    const token = extractDuoInviteToken(this.tokenInput);
    if (token.length > 0) {
      DuoInviteClipboardService.dismissToken(token);
    }
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

  private async pasteInvite(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const data = await systemPasteboard.getData();
      const text = data.getPrimaryText() ?? '';
      if (text.trim().length === 0) {
        this.toastError('剪贴板里没有可用口令');
        return;
      }
      this.tokenInput = text;
      await this.loadPreview();
    } catch (error) {
      this.toastError(`读取剪贴板失败：${String(error)}`);
    }
  }

  private async loadPreview(): Promise<void> {
    if (this.isLoadingPreview) {
      return;
    }
    const token = extractDuoInviteToken(this.tokenInput);
    if (token.length === 0) {
      this.toastError('未找到有效口令');
      return;
    }
    this.isLoadingPreview = true;
    const response = await DuoApiService.getByToken(token);
    this.preview = DuoApiService.parseSession(response);
    if (!this.preview) {
      this.toastError(response.message ?? '无法识别口令');
    }
    this.isLoadingPreview = false;
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

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (this.preview.type === 'scheduled') {
      const auth = await ensureScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, auth.ok, auth.message);
      if (!auth.ok) {
        this.toastError(auth.message);
        return;
      }
    } else if (!this.hasAuthorized) {
      const auth = await requestScreenTimeAuthorization(hostContext);
      SettingsStore.updateAuthorization(hostContext, auth.ok, auth.message);
      if (!auth.ok) {
        this.toastError(auth.message);
        return;
      }
    }

    this.isSubmitting = true;
    const token = extractDuoInviteToken(this.tokenInput);
    const response = this.preview.type === 'scheduled'
      ? await DuoApiService.scheduledJoin(token, [...this.selectedTokens])
      : await DuoApiService.instantJoin(token, this.selectedTokens.length);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      this.toastError(response.message ?? '加入失败');
      this.isSubmitting = false;
      return;
    }

    if (session.type === 'scheduled') {
      const guardResult = await syncGuardForSession(hostContext, session);
      if (!guardResult.ok) {
        const warningMessage = '已加入定时契约，但本机屏时策略注册失败，请到计划页重试';
        markGuardSyncIssue(hostContext, session, warningMessage);
        SettingsStore.updateStatusMessage(hostContext, warningMessage);
        DuoInviteClipboardService.dismissToken(token);
        void DuoInviteClipboardService.clearInviteClipboard();
        ScheduledListStore.markDirty();
        ScheduledListStore.setFilter('joined');
        this.toastError(warningMessage);
        this.isSubmitting = false;
        navigateToMainTab('plans');
        return;
      }
      DuoInviteClipboardService.dismissToken(token);
      void DuoInviteClipboardService.clearInviteClipboard();
      showToast('已加入定时契约，屏时策略已注册', this.getUIContext());
      ScheduledListStore.markDirty();
      ScheduledListStore.setFilter('joined');
      this.isSubmitting = false;
      navigateToMainTab('plans');
      return;
    }

    const lockOptions: DuoInstantLockOptions = {
      navigateHome: true,
      clearWait: false,
      alignToServerEnd: false
    };
    const lockResult = await startOrAlignInstantDuoFocus(
      hostContext,
      session,
      this.selectedTokens,
      lockOptions
    );
    if (!lockResult.ok) {
      SettingsStore.updateStatusMessage(hostContext, '已加入互督，但本机限制未成功开启，请返回首页重试');
      this.toastError('已加入互督，但本机限制未成功开启，请返回首页重试');
      this.isSubmitting = false;
      return;
    }

    DuoInviteClipboardService.dismissToken(token);
    void DuoInviteClipboardService.clearInviteClipboard();
    this.isSubmitting = false;
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

        Text(this.preview.type === 'scheduled'
          ? '定时契约 · 到点一起履约'
          : `时长 ${this.preview.duration_min} 分钟 · 白名单模式`)
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
      Text('粘贴或输入搭子的口令，确认契约信息后加入')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width('100%')

      Column({ space: 12 }) {
        TextInput({ text: this.tokenInput, placeholder: '粘贴口令，例如 $12345678$' })
          .width('100%')
          .height(44)
          .onChange((value: string) => {
            this.tokenInput = value;
            this.preview = null;
          })

        Row({ space: 12 }) {
          Button('粘贴口令')
            .layoutWeight(1)
            .height(44)
            .type(ButtonType.Capsule)
            .backgroundColor(AppTheme.colors.surfaceRaised)
            .fontColor(AppTheme.colors.textPrimary)
            .border({ width: 1, color: AppTheme.colors.border })
            .onClick(() => {
              void this.pasteInvite();
            })

          Button(this.isLoadingPreview ? '识别中...' : '识别口令')
            .layoutWeight(1)
            .height(44)
            .type(ButtonType.Capsule)
            .backgroundColor(AppTheme.colors.primary)
            .fontColor('#FFFFFF')
            .enabled(!this.isLoadingPreview)
            .opacity(this.isLoadingPreview ? 0.55 : 1)
            .onClick(() => {
              void this.loadPreview();
            })
        }
        .width('100%')
      }
      .width('100%')

      this.buildPreviewCard()
      this.buildAppCard()

      if (this.preview !== null && this.preview.type !== 'scheduled') {
        Text('建议确认发起人已打开 App 后再加入，以便同时开始。')
          .fontSize(13)
          .fontColor(AppTheme.colors.warning)
          .width('100%')
      }

      Button(this.preview?.type === 'scheduled' ? '确认加入' : '确认加入并开始')
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
        title: '加入互督',
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
