import { common } from '@kit.AbilityKit';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import { DuoSessionView } from '../../models/DuoModel';
import { PageRoutes, backRoute, pushRoute, navigateToMainTab } from '../../router/PageRoutes';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { DuoApiService } from '../../services/DuoApiService';
import { DuoInviteClipboardService, extractDuoInviteToken } from '../../services/DuoInviteClipboardService';
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus
} from '../../services/DuoInstantLockService';
import { syncGuardForSession } from '../../services/ScheduledCovenantService';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

const CODE_LENGTH: number = 6;

@Entry
@Component
struct DuoJoinPage {
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State code: string = '';
  @State preview: DuoSessionView | null = null;
  @State myTitle: string = '';
  @State isLoadingPreview: boolean = false;
  @State isSubmitting: boolean = false;

  aboutToDisappear(): void {
    const token = this.code.replace(/\D/g, '').slice(0, CODE_LENGTH);
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
      const digits = extractDuoInviteToken(stashedToken).replace(/\D/g, '').slice(0, CODE_LENGTH);
      if (digits.length === CODE_LENGTH) {
        this.code = digits;
        void this.loadPreview();
      }
    }
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private normalizeCode(raw: string): string {
    return raw.replace(/\D/g, '').slice(0, CODE_LENGTH);
  }

  private async loadPreview(): Promise<void> {
    if (this.isLoadingPreview) {
      return;
    }
    const token = this.normalizeCode(this.code);
    if (token.length !== CODE_LENGTH) {
      return;
    }
    this.isLoadingPreview = true;
    const response = await DuoApiService.getByToken(token);
    this.preview = DuoApiService.parseSession(response);
    if (!this.preview) {
      this.toastError(response.message ?? '口令无效');
      this.code = '';
      this.myTitle = '';
    } else {
      this.myTitle = '';
    }
    this.isLoadingPreview = false;
  }

  private resetInput(): void {
    this.preview = null;
    this.code = '';
    this.myTitle = '';
  }

  private onCodeChange(value: string): void {
    if (this.isLoadingPreview) {
      return;
    }
    this.code = this.normalizeCode(value);
    this.preview = null;
    this.myTitle = '';
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const authResult = await ensureScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
    if (!authResult.ok) {
      if (authResult.message.length > 0) {
        this.toastError(authResult.message);
      }
      return;
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

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const authResult = await ensureScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
    if (!authResult.ok) {
      if (authResult.message.length > 0) {
        this.toastError(authResult.message);
      }
      return;
    }

    this.isSubmitting = true;
    const token = this.normalizeCode(this.code);
    const joinTitle = this.myTitle.trim();
    const response = this.preview.type === 'scheduled'
      ? await DuoApiService.scheduledJoin(
        token,
        [...this.selectedTokens],
        joinTitle.length > 0 ? joinTitle : undefined
      )
      : await DuoApiService.instantJoin(
        token,
        this.selectedTokens.length,
        joinTitle.length > 0 ? joinTitle : undefined
      );
    const session = DuoApiService.parseSession(response);
    if (!session) {
      this.toastError(response.message ?? '加入失败');
      this.isSubmitting = false;
      return;
    }

    if (session.type === 'scheduled') {
      await syncGuardForSession(hostContext, session);
      DuoInviteClipboardService.dismissToken(token);
      void DuoInviteClipboardService.clearInviteClipboard();
      ScheduledListStore.markDirty();
      ScheduledListStore.setFilter('joined');
      showToast('已加入定时契约', this.getUIContext());
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
  private buildDigitBox(index: number): void {
    Column() {
      Text(index < this.code.length ? this.code[index] : '')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
    }
    .width(44)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({
      width: this.code.length === index ? 2 : 1,
      color: this.code.length === index
        ? AppTheme.colors.primary
        : (index < this.code.length ? AppTheme.colors.primarySoft : AppTheme.colors.border)
    })
    .borderRadius(16)
  }

  @Builder
  private buildCodeInput(): void {
    Column({ space: 20 }) {
      Text('输入搭子分享的 6 位口令')
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)
        .width('100%')

      Stack() {
        Row({ space: 10 }) {
          ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
            this.buildDigitBox(index)
          })
        }
        .justifyContent(FlexAlign.Center)
        .opacity(this.isLoadingPreview ? 0.7 : 1)

        TextInput({ text: this.code, placeholder: '' })
          .width(314)
          .height(48)
          .opacity(0.02)
          .caretColor(Color.Transparent)
          .maxLength(CODE_LENGTH)
          .type(InputType.Number)
          .enabled(!this.isLoadingPreview)
          .onChange((value: string) => {
            this.onCodeChange(value);
          })
      }
      .width(314)
      .height(48)
      .alignContent(Alignment.Center)

      Button(this.isLoadingPreview ? '识别中' : '识别口令')
        .width(280)
        .height(48)
        .type(ButtonType.Normal)
        .buttonStyle(ButtonStyleMode.NORMAL)
        .borderRadius(AppTheme.radius.button)
        .clip(true)
        .backgroundColor(AppTheme.colors.primary)
        .fontColor('#FFFFFF')
        .enabled(!this.isLoadingPreview && this.code.length === CODE_LENGTH)
        .opacity(!this.isLoadingPreview && this.code.length === CODE_LENGTH ? 1 : 0.55)
        .onClick(() => {
          void this.loadPreview();
        })
    }
    .width('100%')
    .padding({ top: 24 })
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildPreviewSection(): void {
    if (this.preview !== null) {
      Column({ space: 14 }) {
        Column({ space: 12 }) {
          Row() {
            Text('识别结果')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.primary)

            Blank()

            Text(this.code)
              .fontSize(13)
              .fontColor(AppTheme.colors.textMuted)
              .letterSpacing(2)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Column({ space: 6 }) {
            Text(this.preview.title)
              .fontSize(18)
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
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(AppTheme.colors.surface)
        .borderRadius(AppTheme.radius.lg)

        Column({ space: 8 }) {
          Text('我的任务名称（可选）')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')

          TextInput({
            text: this.myTitle,
            placeholder: this.preview.title.length > 0
              ? this.preview.title
              : '不填则与发起方相同'
          })
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(AppTheme.colors.textPrimary)
            .placeholderColor(AppTheme.colors.textMuted)
            .backgroundColor(AppTheme.colors.surface)
            .borderRadius(AppTheme.radius.lg)
            .padding({ left: 16, right: 16 })
            .onChange((value: string) => {
              this.myTitle = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

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

        if (this.preview.type !== 'scheduled') {
          Text('建议确认发起人已打开 App 后再加入，以便同时开始。')
            .fontSize(13)
            .fontColor(AppTheme.colors.warning)
            .width('100%')
        }

        Button(this.preview.type === 'scheduled' ? '确认加入' : '确认加入并开始')
          .width('100%')
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor('#FFFFFF')
          .enabled(!this.isSubmitting)
          .opacity(this.isSubmitting ? 0.55 : 1)
          .onClick(() => {
            void this.confirmJoin();
          })

        Text('口令不对？重新输入')
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 4, bottom: 4 })
          .onClick(() => {
            this.resetInput();
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildPageBody(): void {
    Column({ space: 14 }) {
      if (this.preview === null) {
        this.buildCodeInput()
      } else {
        this.buildPreviewSection()
      }
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
