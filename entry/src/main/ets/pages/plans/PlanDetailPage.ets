import { common } from '@kit.AbilityKit';
import { copyDuoInviteText, shareDuoInviteText } from '../../services/DuoInviteShareService';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledListStatusLabel,
  getScheduledParticipationLabel,
  getSessionApps,
  getTornTodayResumeHint,
  isInactiveScheduledListSession,
  isScheduledSessionActivationOpen,
} from '../../models/DuoModel';
import { summarizeRepeatDays } from '../../models/PlanModel';
import { PageRoutes, backRoute, navigateToMainTab, pushRoute } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  removeGuardForSession,
  reconcileStaleScheduledWindows,
} from '../../services/ScheduledCovenantService';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import { LockStore } from '../../stores/LockStore';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';
import { loadExitPlanIds } from '../../services/ExitPlanIdsService';

bootstrapStores();

interface ScheduledStatusTagStyle {
  textColor: string;
  backgroundColor: string;
}

@Entry
@Component
struct PlanDetailPage {
  @State sessionId: string = '';
  @State session: DuoSessionView | null = null;
  @State isLoading: boolean = true;

  @State planName: string = '';
  @State startTime: string = '09:00';
  @State endTime: string = '18:00';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'allow';
  @State private statusTick: number = 0;

  private statusTimerId: number = -1;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    this.sessionId = AppStorage.get<string>(StoreKeys.ScheduledSessionCurrentId) ?? '';
    if (this.sessionId.length === 0 || !UserStore.isLoggedIn()) {
      navigateToMainTab('plans');
    }
  }

  onPageShow(): void {
    this.startStatusTimer();
    if (this.sessionId.length === 0 || !UserStore.isLoggedIn()) {
      return;
    }
    void this.loadSession();
  }

  onPageHide(): void {
    this.clearStatusTimer();
  }

  private startStatusTimer(): void {
    this.clearStatusTimer();
    this.statusTimerId = setInterval(() => {
      this.statusTick += 1;
    }, 60_000);
  }

  private clearStatusTimer(): void {
    if (this.statusTimerId !== -1) {
      clearInterval(this.statusTimerId);
      this.statusTimerId = -1;
    }
  }

  private async loadSession(): Promise<void> {
    this.isLoading = true;
    const response = await DuoApiService.getSession(this.sessionId);
    let nextSession = DuoApiService.parseSession(response);
    if (!nextSession) {
      showErrorToast(response.message ?? '无法加载契约', this.getUIContext());
      navigateToMainTab('plans');
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const reconciled = await reconcileStaleScheduledWindows([nextSession], hostContext);
    nextSession = reconciled[0] ?? nextSession;
    this.session = nextSession;
    this.fillFormFromSession(nextSession);
    ScheduledListStore.patchSession(nextSession);
    this.isLoading = false;
  }

  private fillFormFromSession(session: DuoSessionView): void {
    this.planName = session.title;
    this.startTime = session.schedule_start && session.schedule_start.length > 0
      ? session.schedule_start
      : '09:00';
    this.endTime = session.schedule_end && session.schedule_end.length > 0
      ? session.schedule_end
      : '18:00';
    this.repeatDays = getScheduleRepeatDays(session.schedule_repeat ?? '');
    this.selectedTokens = getSessionApps(session);
    this.mode = session.mode === 'shield' ? 'shield' : 'allow';
  }

  private isInitiator(): boolean {
    return this.session?.viewer_role === 'initiator';
  }

  private isPartner(): boolean {
    return this.session?.viewer_role === 'partner';
  }

  private canEditAll(): boolean {
    return Boolean(this.session?.editable) && this.isInitiator();
  }

  private canEditApps(): boolean {
    return Boolean(this.session?.editable);
  }

  private canShowEditEntry(): boolean {
    return this.canEditAll() || this.canEditApps();
  }

  private showInviteEntry(): boolean {
    return Boolean(this.session?.expects_duo) && this.session?.status === 'scheduled';
  }

  private getDisplayStatusLabel(): string {
    if (this.session === null) {
      return '';
    }
    const _tick = this.statusTick;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return getScheduledListStatusLabel(this.session, loadExitPlanIds(hostContext));
  }

  @Builder
  private buildStatusTag(label: string): void {
    Text(label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.getStatusTagStyleForLabel(label).textColor)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.getStatusTagStyleForLabel(label).backgroundColor)
      .borderRadius(AppTheme.radius.pill)
  }

  private getStatusTagStyleForLabel(label: string): ScheduledStatusTagStyle {
    if (label === '今日已撕毁') {
      const style: ScheduledStatusTagStyle = {
        textColor: AppTheme.colors.danger,
        backgroundColor: AppTheme.colors.dangerSoft
      };
      return style;
    }
    if (label === '今日已完成') {
      const style: ScheduledStatusTagStyle = {
        textColor: AppTheme.colors.success,
        backgroundColor: AppTheme.colors.successSoft
      };
      return style;
    }
    if (label === '今日不生效') {
      const style: ScheduledStatusTagStyle = {
        textColor: AppTheme.colors.textMuted,
        backgroundColor: AppTheme.colors.surfaceRaised
      };
      return style;
    }
    if (this.session?.status === 'active') {
      const style: ScheduledStatusTagStyle = {
        textColor: AppTheme.colors.primary,
        backgroundColor: AppTheme.colors.primarySoft
      };
      return style;
    }
    const style: ScheduledStatusTagStyle = {
      textColor: '#2563EB',
      backgroundColor: '#EEF5FF'
    };
    return style;
  }

  private getTornTodayResumeHintText(): string {
    if (this.session === null) {
      return '';
    }
    const _tick = this.statusTick;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const hint = getTornTodayResumeHint(this.session, loadExitPlanIds(hostContext));
    return hint ?? '';
  }

  private getParticipationLabel(): string {
    if (this.session === null) {
      return '单人专注';
    }
    return getScheduledParticipationLabel(this.session);
  }

  private getModeLabel(): string {
    return this.mode === 'shield' ? '锁定模式' : '放行模式';
  }

  private getPartnerNickname(): string {
    return this.session?.partner?.nickname ?? '';
  }

  private hasJoinedPartner(): boolean {
    return this.getPartnerNickname().length > 0;
  }

  private getInviteCode(): string {
    if (this.session?.invite_text && this.session.invite_text.length > 0) {
      return this.session.invite_text;
    }
    return this.session?.token ?? '';
  }

  private shouldShowEditAction(): boolean {
    return !this.isLoading && this.canShowEditEntry();
  }

  private shouldShowDestructiveFooter(): boolean {
    if (this.isLoading) {
      return false;
    }
    // 真正履约中（窗口内 active）隐藏作废/退出；滞留 active 允许操作
    if (this.session !== null && isScheduledSessionActivationOpen(this.session)) {
      return false;
    }
    return this.isPartner() || this.isInitiator();
  }

  private getBottomSpacerHeight(): number {
    return this.shouldShowDestructiveFooter() ? 84 : 28;
  }

  private confirmLeaveSession(): void {
    this.getUIContext().showAlertDialog({
      title: '退出契约',
      message: '退出后将不再参与这条契约，确认退出吗？',
      autoCancel: true,
      primaryButton: {
        value: '确认退出',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.leaveSession();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private confirmCancelSession(): void {
    this.getUIContext().showAlertDialog({
      title: '作废契约',
      message: '作废后契约将无法恢复，双方都会从列表中移除，确认作废吗？',
      autoCancel: true,
      primaryButton: {
        value: '确认作废',
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.cancelSession();
        }
      },
      secondaryButton: {
        value: '取消',
        action: () => {
        }
      }
    });
  }

  private getPageTitle(): string {
    return this.planName.length > 0 ? this.planName : '契约详情';
  }

  private goToEdit(): void {
    if (!this.session || !this.canShowEditEntry()) {
      return;
    }
    if (isInactiveScheduledListSession(this.session)) {
      return;
    }
    if (this.session.editable === false) {
      showToast('当前契约不可编辑', this.getUIContext());
      return;
    }
    if (LockStore.isLocked()) {
      showToast('专注进行中，不可以修改契约', this.getUIContext());
      return;
    }
    if (isScheduledSessionActivationOpen(this.session)) {
      showToast('当前处于契约执行时间内，无法修改', this.getUIContext());
      return;
    }
    ScheduledListStore.setEditingSession(this.session);
    pushRoute(PageRoutes.PlanAdd);
  }

  private async copyInvite(): Promise<void> {
    if (!this.session?.token) {
      return;
    }
    const inviteText = this.session.invite_text && this.session.invite_text.length > 0
      ? this.session.invite_text
      : this.session.token;
    await copyDuoInviteText(this.getUIContext(), inviteText);
  }

  private async shareInvite(): Promise<void> {
    if (!this.session?.token) {
      return;
    }
    const inviteText = this.session.invite_text && this.session.invite_text.length > 0
      ? this.session.invite_text
      : this.session.token;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await shareDuoInviteText(hostContext, this.getUIContext(), inviteText);
  }

  private async leaveSession(): Promise<void> {
    if (!this.session) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const response = await DuoApiService.scheduledLeave(this.session.session_id);
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '退出失败', this.getUIContext());
      return;
    }
    await removeGuardForSession(hostContext, this.session.session_id);
    ScheduledListStore.markDirty();
    showToast('已退出契约', this.getUIContext());
    navigateToMainTab('plans');
  }

  private async cancelSession(): Promise<void> {
    if (!this.session) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const response = await DuoApiService.scheduledCancel(this.session.session_id);
    if (response.statusCode !== 200) {
      showErrorToast(response.message ?? '作废失败', this.getUIContext());
      return;
    }
    await removeGuardForSession(hostContext, this.session.session_id);
    ScheduledListStore.markDirty();
    showToast('契约已作废', this.getUIContext());
    navigateToMainTab('plans');
  }

  @Builder
  private buildViewRow(label: string, value: string): void {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(AppTheme.colors.textMuted)
        .width(88)
      Text(value)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private buildViewBody(): void {
    Column({ space: 18 }) {
      Column({ space: 14 }) {
        Row() {
          Text(this.planName.length > 0 ? this.planName : '定时契约')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .layoutWeight(1)

          this.buildStatusTag(this.getDisplayStatusLabel())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Column({ space: 12 }) {
          this.buildViewRow('专注时段', `${this.startTime} - ${this.endTime}`)
          this.buildViewRow('每周重复', summarizeRepeatDays(this.repeatDays))
          this.buildViewRow('应用数量', `${this.selectedTokens.length} 个`)
          this.buildViewRow('锁机模式', this.getModeLabel())
          this.buildViewRow('履约方式', this.getParticipationLabel())
          if (this.getPartnerNickname().length > 0 && !this.showInviteEntry()) {
            this.buildViewRow('搭子', this.getPartnerNickname())
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)

      if (this.getTornTodayResumeHintText().length > 0) {
        Text(this.getTornTodayResumeHintText())
          .fontSize(14)
          .fontColor(AppTheme.colors.warning)
          .lineHeight(22)
          .textAlign(TextAlign.Center)
          .width('100%')
          .padding({ left: 8, right: 8 })
      }

      this.buildInviteCard()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildInviteCard(): void {
    if (this.showInviteEntry() && this.isInitiator()) {
      Column({ space: 12 }) {
        Text('邀请搭子')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .width('100%')

        if (this.hasJoinedPartner()) {
          Text('搭子已加入')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
          Row({ space: 10 }) {
            Text(this.getPartnerNickname().length > 0 ? this.getPartnerNickname().charAt(0) : '搭')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppTheme.colors.primary)
              .textAlign(TextAlign.Center)
              .width(40)
              .height(40)
              .borderRadius(20)
              .backgroundColor(AppTheme.colors.primarySoft)
            Column({ space: 4 }) {
              Text(this.getPartnerNickname())
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(AppTheme.colors.textPrimary)
                .width('100%')
              Text('已接受邀请')
                .fontSize(12)
                .fontColor(AppTheme.colors.textMuted)
                .width('100%')
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .borderRadius(12)
        } else {
          Text('邀请内容')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
          Text(this.getInviteCode().length > 0 ? this.getInviteCode() : '生成中…')
            .fontSize(14)
            .lineHeight(22)
            .fontColor(AppTheme.colors.textPrimary)
            .width('100%')
          Text('发给搭子或复制口令，对方加入后会出现在双方契约列表。')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
            .width('100%')
          Row({ space: 12 }) {
            Button('发给搭子')
              .layoutWeight(2)
              .height(42)
              .type(ButtonType.Normal)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .borderRadius(AppTheme.radius.button)
              .clip(true)
              .backgroundColor(AppTheme.colors.primary)
              .fontColor('#FFFFFF')
              .onClick(() => {
                void this.shareInvite();
              })
            Button('复制口令')
              .layoutWeight(1)
              .height(42)
              .type(ButtonType.Normal)
              .buttonStyle(ButtonStyleMode.NORMAL)
              .borderRadius(AppTheme.radius.button)
              .clip(true)
              .fontSize(14)
              .backgroundColor(AppTheme.colors.primarySoft)
              .fontColor(AppTheme.colors.primary)
              .onClick(() => {
                void this.copyInvite();
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(20)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)
      .alignItems(HorizontalAlign.Start)
    }
  }

  @Builder
  private buildDestructiveFooter(): void {
    Column({ space: 8 }) {
      if (this.isPartner()) {
        Text('退出契约')
          .fontSize(13)
          .fontColor(AppTheme.colors.danger)
          .opacity(0.85)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.confirmLeaveSession();
          })
      }
      if (this.isInitiator()) {
        Text('作废契约')
          .fontSize(13)
          .fontColor(AppTheme.colors.textMuted)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 8, bottom: 8 })
          .onClick(() => {
            this.confirmCancelSession();
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    .backgroundColor(AppTheme.colors.background)
  }

  @Builder
  private buildBody(): void {
    if (this.isLoading) {
      Text('加载中...')
        .fontColor(AppTheme.colors.textSecondary)
    } else {
      this.buildViewBody()
    }
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: this.getBottomSpacerHeight(),
        showAction: this.shouldShowEditAction(),
        actionLabel: '编辑',
        actionIcon: $r('sys.symbol.square_and_pencil'),
        onAction: () => {
          this.goToEdit();
        },
        onBack: () => {
          backRoute();
        },
        content: (): void => {
          this.buildBody();
        }
      })

      if (this.shouldShowDestructiveFooter()) {
        Stack({ alignContent: Alignment.Bottom }) {
          this.buildDestructiveFooter()
        }
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }
}
