import { common } from '@kit.AbilityKit';
import { copyDuoInviteText, shareDuoInviteText } from '../../services/DuoInviteShareService';
import { showErrorToast, showToast } from '../../common/Toast';
import { SystemNavPage } from '../../components/common/SystemNavPage';
import { AppTheme } from '../../constants/Theme';
import {
  DuoScheduledUpdatePayload,
  DuoSessionView,
  getScheduleRepeatDays,
  getScheduledSessionStatusLabel,
  isScheduledSessionActivationOpen
} from '../../models/DuoModel';
import { PLAN_REPEAT_DAY_OPTIONS, getRepeatDayShortLabel, summarizeRepeatDays, validateScheduledStartTime } from '../../models/PlanModel';
import { PageRoutes, backRoute, navigateToMainTab } from '../../router/PageRoutes';
import { DuoApiService } from '../../services/DuoApiService';
import {
  getGuardSyncIssue,
  removeGuardForSession,
  reconcileStaleScheduledWindows,
  syncGuardForSession
} from '../../services/ScheduledCovenantService';
import { validateScheduledPlanTime } from '../../services/ScheduledPlanValidation';
import { ScheduledListStore } from '../../stores/ScheduledListStore';
import {
  chooseRestrictedApps,
  ensureScreenTimeAuthorization
} from '../../services/ScreenTimeService';
import { SettingsStore } from '../../stores/SettingsStore';
import { UserStore } from '../../stores/UserStore';
import { bootstrapStores } from '../../stores/StoreBootstrap';
import { StoreKeys } from '../../stores/StoreKeys';

bootstrapStores();

/** 与 TimePicker.onChange 入参结构对齐 */
interface PlanTimePickerResult {
  hour: number;
  minute: number;
}

@Entry
@Component
struct PlanDetailPage {
  @State sessionId: string = '';
  @State session: DuoSessionView | null = null;
  @State isLoading: boolean = true;
  @State isEditing: boolean = false;
  @State isSaving: boolean = false;
  @State statusMessage: string = '';

  @State planName: string = '';
  @State startTime: string = '09:00';
  @State endTime: string = '18:00';
  @State repeatDays: number[] = [1, 2, 3, 4, 5];
  @State selectedTokens: string[] = [];
  @State mode: 'shield' | 'allow' = 'allow';
  @State timePickerVisible: boolean = false;
  @State timePickerTarget: 'start' | 'end' = 'start';
  @State timePickerDraft: Date = new Date();

  private readonly dayOptions: number[] = PLAN_REPEAT_DAY_OPTIONS;
  private nameInputController: TextInputController = new TextInputController();

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    this.sessionId = AppStorage.get<string>(StoreKeys.ScheduledSessionCurrentId) ?? '';
    if (this.sessionId.length === 0 || !UserStore.isLoggedIn()) {
      navigateToMainTab('plans');
    }
  }

  onPageShow(): void {
    if (this.sessionId.length === 0 || !UserStore.isLoggedIn()) {
      return;
    }
    void this.loadSession();
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
    const guardIssue = getGuardSyncIssue(hostContext, nextSession.session_id);
    this.statusMessage = guardIssue?.message ?? '';
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
    this.selectedTokens = [...(session.my_apps ?? [])];
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
    return getScheduledSessionStatusLabel(this.session);
  }

  private getParticipationLabel(): string {
    if (this.session?.expects_duo) {
      return '搭子互督';
    }
    return '单人专注';
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
    return !this.isLoading && !this.isEditing && this.canShowEditEntry();
  }

  private shouldShowDestructiveFooter(): boolean {
    if (this.isLoading || this.isEditing) {
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
    if (this.isEditing) {
      return '编辑契约';
    }
    return this.planName.length > 0 ? this.planName : '契约详情';
  }

  private enterEditMode(): void {
    if (!this.canShowEditEntry() || this.session === null) {
      return;
    }
    this.fillFormFromSession(this.session);
    this.isEditing = true;
  }

  private cancelEditMode(): void {
    if (this.session !== null) {
      this.fillFormFromSession(this.session);
    }
    this.isEditing = false;
    this.statusMessage = '';
  }

  private timeToMinutes(time: string): number {
    const parts = time.split(':');
    return Math.floor(Number(parts[0]) || 0) * 60 + Math.floor(Number(parts[1]) || 0);
  }

  private padTimePart(value: number): string {
    return value.toString().padStart(2, '0');
  }

  private formatTime(date: Date): string {
    return `${this.padTimePart(date.getHours())}:${this.padTimePart(date.getMinutes())}`;
  }

  private timeStringToDate(time: string): Date {
    const normalized = time.trim();
    const result = new Date();
    if (!normalized.includes(':')) {
      return result;
    }
    const parts = normalized.split(':');
    const hour = Math.min(23, Math.max(0, Math.floor(Number(parts[0]) || 0)));
    const minute = Math.min(59, Math.max(0, Math.floor(Number(parts[1]) || 0)));
    result.setHours(hour, minute, 0, 0);
    return result;
  }

  private minutesToTime(totalMinutes: number): string {
    const hour = Math.floor(totalMinutes / 60);
    const minute = totalMinutes % 60;
    return `${this.padTimePart(hour)}:${this.padTimePart(minute)}`;
  }

  private blurNameInput(): void {
    this.nameInputController.stopEditing();
  }

  private openTimePicker(target: 'start' | 'end'): void {
    this.blurNameInput();
    this.timePickerTarget = target;
    this.timePickerDraft = this.timeStringToDate(target === 'start' ? this.startTime : this.endTime);
    this.timePickerVisible = true;
  }

  private confirmTimePicker(): void {
    const nextTime = this.formatTime(this.timePickerDraft);
    const uiContext = this.getUIContext();
    if (this.timePickerTarget === 'start') {
      const startMin = this.timeToMinutes(nextTime);
      const endMin = startMin + 20;
      if (endMin > 24 * 60 - 1) {
        showErrorToast('暂不支持跨日，请改早一点的开始时间', uiContext);
        this.timePickerVisible = false;
        return;
      }
      this.startTime = nextTime;
      this.endTime = this.minutesToTime(endMin);
    } else {
      const startMin = this.timeToMinutes(this.startTime);
      const endMin = this.timeToMinutes(nextTime);
      if (endMin <= startMin) {
        showErrorToast('暂不支持跨日，请将结束时间设在当天内', uiContext);
        this.timePickerVisible = false;
        return;
      }
      if (endMin - startMin < 20) {
        showErrorToast('时长至少20分钟', uiContext);
        this.timePickerVisible = false;
        return;
      }
      this.endTime = nextTime;
    }
    this.timePickerVisible = false;
  }

  private cancelTimePicker(): void {
    this.timePickerVisible = false;
  }

  private toggleRepeatDay(day: number): void {
    if (!this.canEditAll()) {
      return;
    }
    if (this.repeatDays.includes(day)) {
      this.repeatDays = this.repeatDays.filter((item: number) => item !== day);
      return;
    }
    this.repeatDays = [...this.repeatDays, day].sort((left: number, right: number) => left - right);
  }

  private appCardTitle(): string {
    return this.mode === 'allow' ? '允许使用的应用' : '要锁定的应用';
  }

  private shouldShowStatusLine(): boolean {
    if (this.statusMessage.length === 0) {
      return false;
    }
    const m = /^已选择 (\d+) 个应用$/.exec(this.statusMessage);
    if (m !== null && Number(m[1]) === this.selectedTokens.length) {
      return false;
    }
    return true;
  }

  private async chooseApps(): Promise<void> {
    if (!this.canEditApps()) {
      return;
    }
    this.blurNameInput();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    this.blurNameInput();
    if (result.data) {
      this.selectedTokens = [...result.data];
      this.statusMessage = result.message;
    }
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

  private async saveChanges(): Promise<void> {
    if (!this.session || this.isSaving) {
      return;
    }

    if (this.isInitiator()) {
      const startTimeError = validateScheduledStartTime(this.startTime, this.repeatDays);
      if (startTimeError.length > 0) {
        showErrorToast(startTimeError, this.getUIContext());
        return;
      }
      ScheduledListStore.hydrate();
      const scheduleTimeError = validateScheduledPlanTime(
        this.startTime,
        this.endTime,
        this.repeatDays,
        ScheduledListStore.getAllSessions(),
        this.session.session_id
      );
      if (scheduleTimeError.length > 0) {
        showErrorToast(scheduleTimeError, this.getUIContext());
        return;
      }
    }

    this.isSaving = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const authResult = await ensureScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, authResult.ok, authResult.message);
    if (!authResult.ok) {
      showErrorToast('未完成系统授权，无法同步本机屏时策略', this.getUIContext());
      this.isSaving = false;
      return;
    }

    const payload: DuoScheduledUpdatePayload = this.isInitiator()
      ? {
        title: this.planName,
        start: this.startTime,
        start_min: this.timeToMinutes(this.startTime),
        end: this.endTime,
        end_min: this.timeToMinutes(this.endTime),
        repeat: this.repeatDays.join(','),
        mode: this.mode,
        initiator_apps: this.selectedTokens
      }
      : {
        partner_apps: this.selectedTokens
      };

    const response = await DuoApiService.scheduledUpdate(this.session.session_id, payload);
    const nextSession = DuoApiService.parseSession(response);
    if (!nextSession) {
      showErrorToast(response.message ?? '保存失败', this.getUIContext());
      this.isSaving = false;
      return;
    }

    const guardResult = await syncGuardForSession(hostContext, nextSession);
    this.statusMessage = guardResult.ok ? '' : '已保存，但本机屏时策略未同步，请稍后重试';

    this.session = nextSession;
    this.fillFormFromSession(nextSession);
    this.isEditing = false;
    this.isSaving = false;
    ScheduledListStore.patchSession(nextSession);
    const listResponse = await DuoApiService.getScheduledList();
    const list = DuoApiService.parseScheduledList(listResponse);
    if (listResponse.statusCode === 200) {
      ScheduledListStore.setAllSessions(list.items);
      ScheduledListStore.clearDirty();
    } else {
      ScheduledListStore.markDirty();
    }
    if (guardResult.ok) {
      showToast('已保存', this.getUIContext());
    } else {
      showErrorToast(this.statusMessage, this.getUIContext());
    }
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

          Text(this.getDisplayStatusLabel())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.primary)
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor(AppTheme.colors.primarySoft)
            .borderRadius(AppTheme.radius.pill)
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

        if (this.statusMessage.length > 0) {
          Text(this.statusMessage)
            .fontSize(12)
            .fontColor(AppTheme.colors.warning)
            .width('100%')
        }
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(AppTheme.radius.lg)

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
  private buildNameCard(): void {
    Row() {
      Text('契约名称')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)

      TextInput({
        text: this.planName,
        placeholder: '请输入',
        controller: this.nameInputController
      })
        .layoutWeight(1)
        .height(40)
        .fontSize(15)
        .fontColor(AppTheme.colors.textPrimary)
        .placeholderColor(AppTheme.colors.textMuted)
        .backgroundColor(Color.Transparent)
        .borderRadius(0)
        .border({ width: 0 })
        .showUnderline(false)
        .cancelButton({ style: CancelButtonStyle.INVISIBLE })
        .defaultFocus(false)
        .textAlign(TextAlign.End)
        .padding({ left: 12, right: 8 })
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.planName = value;
        })
        .onSubmit(() => {
          this.blurNameInput();
        })
    }
    .width('100%')
    .constraintSize({ minHeight: 54 })
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(12)
  }

  @Builder
  private buildTimeCard(): void {
    Row() {
      Text('起始时间')
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)

      Blank()

      Row({ space: 8 }) {
        Text(this.startTime)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.openTimePicker('start');
          })

        Text('至')
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)

        Text(this.endTime)
          .fontSize(15)
          .fontColor(AppTheme.colors.textPrimary)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(8)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.openTimePicker('end');
          })
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 15, bottom: 15 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(12)
  }

  @Builder
  private buildAppCard(): void {
    Column() {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)

        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
          Text('选择')
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .onClick(() => {
          void this.chooseApps();
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 15, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      Text(this.selectedTokens.length === 0 ? '未选择应用' : `已选 ${this.selectedTokens.length} 个应用`)
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width('100%')
        .padding({ left: 16, right: 16, bottom: this.shouldShowStatusLine() ? 8 : 16 })

      if (this.shouldShowStatusLine()) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private buildRepeatDaysCard(): void {
    Column() {
      Row() {
        Text('每周几重复')
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(`已选${this.repeatDays.length}天`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 15, bottom: 8 })

      Row({ space: 8 }) {
        ForEach(this.dayOptions, (item: number) => {
          Stack() {
            Text(getRepeatDayShortLabel(item))
              .fontSize(15)
              .fontColor(this.repeatDays.includes(item) ? '#FFFFFF' : AppTheme.colors.textPrimary)
          }
          .width(38)
          .height(38)
          .borderRadius(19)
          .clip(true)
          .backgroundColor(this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.border)
          .onClick(() => {
            this.toggleRepeatDay(item);
          })
        }, (item: number) => item.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 20 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(12)
    .clip(true)
  }

  @Builder
  private buildEditBody(): void {
    Column({ space: 16 }) {
      if (this.canEditAll()) {
        this.buildNameCard()
        this.buildTimeCard()
      }
      if (this.canEditApps()) {
        this.buildAppCard()
      }
      if (this.canEditAll()) {
        this.buildRepeatDaysCard()
      }

      Button(this.isSaving ? '保存中...' : '保存修改')
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
        .enabled(!this.isSaving)
        .opacity(this.isSaving ? 0.7 : 1)
        .margin({ top: 8 })
        .onClick(() => {
          void this.saveChanges();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private buildTimePickerSheet(): void {
    Column({ space: 18 }) {
      Text(this.timePickerTarget === 'start' ? '选择开始时间' : '选择结束时间')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width('100%')
        .textAlign(TextAlign.Center)

      TimePicker({
        selected: this.timePickerDraft,
        format: TimePickerFormat.HOUR_MINUTE
      })
        .width('100%')
        .useMilitaryTime(true)
        .onChange((value: PlanTimePickerResult) => {
          const next = new Date(this.timePickerDraft);
          next.setHours(value.hour, value.minute, 0, 0);
          this.timePickerDraft = next;
        })

      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(16)
          .fontColor(AppTheme.colors.textSecondary)
          .backgroundColor(AppTheme.colors.surfaceRaised)
          .onClick(() => {
            this.cancelTimePicker();
          })

        Button('确定')
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            this.confirmTimePicker();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding({
      left: 20,
      right: 20,
      top: 20,
      bottom: 28
    })
  }

  @Builder
  private buildBody(): void {
    if (this.isLoading) {
      Text('加载中...')
        .fontColor(AppTheme.colors.textSecondary)
    } else if (this.isEditing) {
      this.buildEditBody()
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
          this.enterEditMode();
        },
        onBack: () => {
          if (this.isEditing) {
            this.cancelEditMode();
            return;
          }
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

      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.timePickerVisible, this.buildTimePickerSheet(), {
          height: SheetSize.FIT_CONTENT,
          preferType: SheetType.BOTTOM,
          showClose: false,
          dragBar: true,
          backgroundColor: AppTheme.colors.backgroundSoft
        })
    }
    .width('100%')
    .height('100%')
  }
}
