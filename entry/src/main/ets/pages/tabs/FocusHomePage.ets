import { common } from "@kit.AbilityKit";
import { window } from "@kit.ArkUI";
import { showToast } from "../../common/Toast";
import { InputConfirmSheet } from "../../components/common/InputConfirmSheet";
import { DuoFocusHeader } from "../../components/focus/DuoFocusHeader";
import { FocusTimeRing } from "../../components/focus/FocusTimeRing";
import { AppTheme } from "../../constants/Theme";
import { ApiConfig } from "../../config/ApiConfig";
import { TEAR_CONFIRM_REQUIRED_TEXT, TEAR_CONFIRM_REQUIRED_TEXT_DUO } from "../../constants/TearConfirm";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { UsersIcon } from "../../components/common/UsersIcon";
import {
  ActiveLockState,
  createIdleLockState,
  getElapsedSeconds,
  getRemainingSeconds,
  isCountupLock,
  isLocked,
  minutesToHours,
  normalizeActiveLockState,
  resolveDuoSessionIdFromLock,
} from "../../models/ActiveLockModel";
import { isPastCountupMinimum } from "../../utils/TimerMode";
import { inboxBadgeLabel } from "../../models/InboxModel";
import { FocusPlan } from "../../models/PlanModel";
import { isDuoWaitPartnerJoined, resolveDuoCounterpartName } from "../../models/DuoModel";
import { PageRoutes, pushLogin, pushQuickStart, pushRoute } from "../../router/PageRoutes";
import {
  endCycleGuardLock,
  endQuickFocus,
  tearCovenantWindow,
  tearQuickFocus,
} from "../../services/ActiveLockLifecycleService";
import { DuoApiService } from "../../services/DuoApiService";
import {
  queueHonorCertificate,
  queueShameCertificate,
  tryPresentCertificateGuide,
} from "../../services/CertificatePendingService";
import { clearDuoWaitContext, openDuoWaitPage } from "../../services/DuoWaitContextService";
import {
  DuoInstantLockOptions,
  startOrAlignInstantDuoFocus,
} from "../../services/DuoInstantLockService";
import {
  afterGuestSoloFocusEnded,
  ensureSoloFocusAccess,
  onCertificateGuideDismissed,
} from "../../services/GuestSoloFocusService";
import {
  exitOrgClassroomFocus,
  getOrgClassroomExitCopy,
  isOrgClassroomLockPlanId,
  loadOrgClassroomMeta,
  reconcileOrgClassroomOnForeground,
} from "../../services/OrgClassroomService";
import { ensureDailyFocusQuota } from "../../services/DailyFocusQuotaService";
import { ensureNotifyOnLaunch } from "../../services/NotifyLaunchService";
import { reconcileOnboardingOnLaunch } from "../../services/OnboardingApiService";
import {
  cancelPendingQuickStart,
  hasPendingQuickStart,
  hydratePendingQuickStart,
  reconcilePendingQuickStart as runPendingQuickStartReconcile,
} from "../../services/PendingQuickStartService";
import {
  FIRST_FOCUS_MINUTES,
  FIRST_FOCUS_TITLE,
  markFirstFocusPromptDone,
  shouldShowFirstFocusPrompt
} from "../../services/FirstFocusPromptService";
import { getPendingReferralCode } from "../../utils/ReferralUtil";
import { isSignupTrialEligible } from "../../utils/SignupTrialUtil";
import { openTrustListAppForm } from "../../services/ScreenTimeService";
import { BenefitStore } from "../../stores/BenefitStore";
import { LockStore } from "../../stores/LockStore";
import { PlanStore } from "../../stores/PlanStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { InboxStore } from "../../stores/InboxStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";

bootstrapStores();
@Component
export struct FocusHomePage {
  onSelectTab?: (tab: "plans") => void;
  @StorageLink(StoreKeys.LockActiveState) activeLock: ActiveLockState = createIdleLockState();
  @StorageLink(StoreKeys.PlanCollection) planCollection: FocusPlan[] = [];
  @StorageLink(StoreKeys.DuoWaitSessionId) duoWaitSessionId: string = "";
  @StorageLink(StoreKeys.DuoWaitTitle) duoWaitTitle: string = "";
  @StorageLink(StoreKeys.DuoWaitIsScheduled) duoWaitIsScheduled: boolean = false;
  @StorageLink(StoreKeys.DuoWaitScheduleLabel) duoWaitScheduleLabel: string = "";
  @StorageLink(StoreKeys.PendingQuickStartTitle) pendingQuickStartTitle: string = "";
  @StorageLink(StoreKeys.PendingQuickStartDelayMin) pendingQuickStartDelayMin: number = 0;
  @StorageLink(StoreKeys.PendingQuickStartStartAtMs) pendingQuickStartStartAtMs: number = 0;
  @StorageLink(StoreKeys.InboxUnread) inboxUnread: number = 0;
  @StorageLink(StoreKeys.InboxImportantUnread) inboxImportant: number = 0;
  @State remainingLabel: string = LockStore.getRemainingLabel();
  @State pendingRemainTick: number = 0;
  @State showTearConfirm: boolean = false;
  @State topSafeInsetVp: number = 0;
  /** 单人入口按压缩放透明度，对齐 iOS activeOpacity=0.7 */
  @State soloLinkPressed: boolean = false;

  private timerId: number = -1;
  private postOnboardingFlowStarted: boolean = false;
  private isEndingLock: boolean = false;
  private duoWaitPollTick: number = 0;
  private duoPartnerSyncSessionId: string = "";

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    PlanStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    BenefitStore.hydrate(hostContext);
    hydratePendingQuickStart(hostContext);
    this.syncRemainingLabel();
    this.pendingRemainTick += 1;
    void this.reconcileDuoWait();
    void this.reconcilePendingQuickStart();
    void this.syncDuoPartnerDisplay();
    void reconcileOrgClassroomOnForeground(hostContext);
    if (UserStore.isLoggedIn()) {
      void BenefitStore.refresh();
      void InboxStore.fetchUnread();
    } else {
      InboxStore.reset();
    }
    this.startTimer();
    this.loadTopSafeInset(hostContext);
    void this.runPostOnboardingHomeFlow(hostContext);
  }

  onPageShow(): void {
    // 引导结束 returnToMainTab 时首页可能早已 aboutToAppear，需在回显时再申请
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    void this.runPostOnboardingHomeFlow(hostContext);
    void reconcileOrgClassroomOnForeground(hostContext);
    if (UserStore.isLoggedIn()) {
      void InboxStore.fetchUnread();
    } else if (!this.isActiveLocked()) {
      onCertificateGuideDismissed(this.getUIContext());
    }
  }

  private async runPostOnboardingHomeFlow(hostContext: common.UIAbilityContext): Promise<void> {
    if (this.postOnboardingFlowStarted) {
      return;
    }
    this.postOnboardingFlowStarted = true;
    await reconcileOnboardingOnLaunch(hostContext);
    await ensureNotifyOnLaunch(hostContext);
    if (this.isActiveLocked() || !shouldShowFirstFocusPrompt(hostContext)) {
      return;
    }
    this.presentFirstFocusPrompt();
  }

  private presentFirstFocusPrompt(): void {
    const loggedIn = UserStore.isLoggedIn();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const hasInvite = getPendingReferralCode(hostContext).length > 0;
    let message = '时长 5 分钟，可选放行应用，即刻开始';
    if (loggedIn) {
      message = hasInvite
        ? '完成首次专注后领取 7 天会员，邀请码再 +15 天。时长 5 分钟。'
        : '完成首次专注后领取 7 天会员。时长 5 分钟，可选放行应用。';
    }
    this.getUIContext().showAlertDialog({
      title: '开启你的第一次专注',
      message: message,
      autoCancel: false,
      primaryButton: {
        value: '立即开始',
        fontColor: AppTheme.colors.primary,
        action: () => {
          this.onFirstFocusStart();
        }
      },
      secondaryButton: {
        value: '稍后再说',
        action: () => {
          this.onFirstFocusDismiss();
        }
      }
    });
  }

  private onFirstFocusStart(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    markFirstFocusPromptDone(hostContext);
    pushQuickStart(FIRST_FOCUS_TITLE, FIRST_FOCUS_MINUTES);
  }

  private onFirstFocusDismiss(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    markFirstFocusPromptDone(hostContext);
  }

  private loadTopSafeInset(hostContext: common.UIAbilityContext): void {
    const ui = this.getUIContext();
    window.getLastWindow(hostContext, (err, win) => {
      if (err.code) {
        return;
      }
      const systemAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topSafeInsetVp = ui.px2vp(systemAvoid.topRect.height);
    });
  }

  aboutToDisappear(): void {
    this.clearTimer();
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private startTimer(): void {
    this.clearTimer();
    this.timerId = setInterval(() => {
      this.syncRemainingLabel();
      this.pendingRemainTick += 1;
      if (this.hasPendingQuickStart()) {
        void this.reconcilePendingQuickStart();
      }
      // 倒计时到点自动履约解锁（此前只在 MainTab onPageShow 检查，会卡在 00:00）
      if (
        this.activeLock.kind === "quick_focus" &&
        !isCountupLock(this.activeLock) &&
        LockStore.shouldAutoFinish()
      ) {
        void this.performCompleteLock();
      }
      this.duoWaitPollTick += 1;
      if (this.duoWaitSessionId.length > 0 && this.duoWaitPollTick % 5 === 0) {
        void this.reconcileDuoWait();
      }
      if (this.isDuoFocus() && this.duoWaitPollTick % 5 === 0) {
        void this.syncDuoPartnerDisplay();
      }
    }, 1000);
  }

  private hasPendingQuickStart(): boolean {
    return this.pendingQuickStartStartAtMs > 0 && this.pendingQuickStartTitle.length > 0;
  }

  private formatPendingRemainLabel(): string {
    // 引用 tick，保证每秒刷新；不要用独立 00:00 初始值，避免回首页先闪一下
    const _tick = this.pendingRemainTick;
    let remainSec = 0;
    if (this.pendingQuickStartStartAtMs > 0) {
      remainSec = Math.max(0, Math.ceil((this.pendingQuickStartStartAtMs - Date.now()) / 1000));
    } else if (this.pendingQuickStartDelayMin > 0) {
      remainSec = this.pendingQuickStartDelayMin * 60;
    }
    const minutes = Math.floor(remainSec / 60);
    const seconds = remainSec % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  private async reconcilePendingQuickStart(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await runPendingQuickStartReconcile(hostContext);
  }

  private hasPendingDuoWait(): boolean {
    return this.duoWaitSessionId.length > 0;
  }

  private shouldShowOrgEntry(): boolean {
    return !this.isActiveLocked() && !this.hasPendingDuoWait();
  }

  private onOrgEntryPress(): void {
    if (!UserStore.isLoggedIn()) {
      showToast("请先登录", this.getUIContext());
      pushLogin();
      return;
    }
    pushRoute(PageRoutes.OrgList);
  }

  private onInboxPress(): void {
    if (!UserStore.isLoggedIn()) {
      showToast("请先登录", this.getUIContext());
      pushLogin();
      return;
    }
    pushRoute(PageRoutes.InboxList);
  }

  private getDuoWaitEntryDetail(): string {
    if (this.duoWaitIsScheduled) {
      if (this.duoWaitScheduleLabel.length > 0) {
        return `定时契约 · ${this.duoWaitScheduleLabel}`;
      }
      return "定时契约 · 等待搭子加入后可发给搭子";
    }
    const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : "搭子互督";
    return `${title} · 点击进入发给搭子`;
  }

  private async reconcileDuoWait(): Promise<void> {
    if (this.duoWaitSessionId.length === 0) {
      return;
    }

    const response = await DuoApiService.getSession(this.duoWaitSessionId);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      if (response.statusCode === 400 || response.statusCode === 404) {
        clearDuoWaitContext();
      }
      return;
    }

    if (
      session.status === "expired" ||
      session.status === "cancelled" ||
      session.status === "breached"
    ) {
      clearDuoWaitContext();
      return;
    }

    // 即时契约已激活：首页直接按服务端 end_at 补锁，不再只清等待态
    if (!this.duoWaitIsScheduled && session.status === "active" && session.type !== "scheduled") {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      SettingsStore.hydrate(hostContext);
      const tokens = SettingsStore.getState().selectedTokens;
      const title = this.duoWaitTitle.length > 0 ? this.duoWaitTitle : session.title;
      const lockOptions: DuoInstantLockOptions = {
        title,
        navigateHome: false,
        clearWait: true,
        alignToServerEnd: true,
      };
      await startOrAlignInstantDuoFocus(hostContext, session, tokens, lockOptions);
      return;
    }

    if (isDuoWaitPartnerJoined(session, this.duoWaitIsScheduled)) {
      clearDuoWaitContext();
    }
  }

  private async syncDuoPartnerDisplay(): Promise<void> {
    if (!this.isDuoFocus()) {
      this.duoPartnerSyncSessionId = "";
      return;
    }

    const sessionId = resolveDuoSessionIdFromLock(this.activeLock);
    if (sessionId.length === 0) {
      return;
    }

    if (
      this.duoPartnerSyncSessionId === sessionId &&
      this.activeLock.partnerNickname.trim().length > 0
    ) {
      return;
    }

    const response = await DuoApiService.getSession(sessionId);
    const session = DuoApiService.parseSession(response);
    if (!session) {
      return;
    }

    const partnerNickname = resolveDuoCounterpartName(session);
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const currentState = LockStore.getState();
    const nextTitle =
      currentState.title.length > 0
        ? currentState.title
        : session.title.length > 0
          ? session.title
          : "搭子互督";

    LockStore.setState(
      hostContext,
      normalizeActiveLockState({
        kind: currentState.kind,
        strategyName: currentState.strategyName,
        title: nextTitle,
        planId: currentState.planId,
        selectedTokens: currentState.selectedTokens,
        selectedCount: currentState.selectedCount,
        mode: currentState.mode,
        startedAt: currentState.startedAt,
        endAt: currentState.endAt,
        updatedAt: currentState.updatedAt,
        duoSessionId: currentState.duoSessionId,
        recordId: currentState.recordId,
        participationMode: currentState.participationMode,
        partnerNickname,
        timerMode: currentState.timerMode,
        minDurationMin: currentState.minDurationMin,
      }),
    );
    this.duoPartnerSyncSessionId = sessionId;
  }

  private syncRemainingLabel(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    this.remainingLabel = LockStore.getRemainingLabel();
  }

  private isActiveLocked(): boolean {
    return isLocked(this.activeLock);
  }

  private shouldWarnSignupTrialOnTear(): boolean {
    if (!UserStore.isLoggedIn()) {
      return false;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!isSignupTrialEligible(hostContext)) {
      return false;
    }
    return this.activeLock.title === FIRST_FOCUS_TITLE;
  }

  private getTearConfirmMessage(): string {
    if (this.activeLock.participationMode === "duo") {
      return "撕毁后本次立即失败，搭子也会连坐失败，且无法撤销。";
    }
    return "撕毁后将生成耻辱证，本次专注记为违约，且无法撤销。";
  }

  private getTearExtraWarning(): string {
    if (this.shouldWarnSignupTrialOnTear()) {
      return "撕毁后将无法领取 7 天会员。";
    }
    return "";
  }

  private getTearRequiredText(): string {
    if (this.activeLock.participationMode === "duo") {
      return TEAR_CONFIRM_REQUIRED_TEXT_DUO;
    }
    return TEAR_CONFIRM_REQUIRED_TEXT;
  }

  private getTearCancelText(): string {
    if (this.activeLock.participationMode === "duo") {
      return "继续专注";
    }
    return "我再坚持一下";
  }

  private confirmOrgClassroomExit(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const meta = loadOrgClassroomMeta(hostContext);
    if (meta && meta.exitRequestPending) {
      showToast('退出申请审核中，请等待发起人处理', this.getUIContext());
      return;
    }
    const copy = getOrgClassroomExitCopy(meta);
    this.getUIContext().showAlertDialog({
      title: copy.title,
      message: copy.message,
      primaryButton: {
        value: copy.confirmText,
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.performOrgClassroomExit();
        },
      },
      secondaryButton: {
        value: "继续上课",
        fontColor: "#0A59F7",
        action: () => {},
      },
    });
  }

  private async performOrgClassroomExit(): Promise<void> {
    if (this.isEndingLock) {
      return;
    }
    this.isEndingLock = true;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const message = await exitOrgClassroomFocus(hostContext);
    showToast(message, this.getUIContext());
    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
  }

  private isPastCountupMin(): boolean {
    return (
      isCountupLock(this.activeLock) &&
      isPastCountupMinimum(this.activeLock.startedAt, this.activeLock.minDurationMin)
    );
  }

  private async endCurrentLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    if (isOrgClassroomLockPlanId(this.activeLock.planId)) {
      this.confirmOrgClassroomExit();
      return;
    }

    // 正计时过最短：正常结束
    if (this.activeLock.kind === "quick_focus" && this.isPastCountupMin()) {
      this.confirmCompleteFocus();
      return;
    }

    if (this.activeLock.kind === "quick_focus" || this.activeLock.kind === "covenant") {
      this.showTearConfirm = true;
      return;
    }

    await this.performEndLock();
  }

  private confirmCompleteFocus(): void {
    const isDuo = this.activeLock.participationMode === "duo";
    this.getUIContext().showAlertDialog({
      title: "结束专注？",
      message: isDuo
        ? "已满最短时长。结束后你与搭子都将记为成功完成。"
        : "已满最短时长，确认结束本次专注？",
      primaryButton: {
        value: "确认结束",
        fontColor: AppTheme.colors.danger,
        action: () => {
          void this.performCompleteLock();
        },
      },
      secondaryButton: {
        value: "继续专注",
        fontColor: "#0A59F7",
        action: () => {},
      },
    });
  }

  private async performCompleteLock(): Promise<void> {
    if (this.isEndingLock || this.activeLock.kind !== "quick_focus") {
      return;
    }
    const lockSnapshot = normalizeActiveLockState(this.activeLock);
    const endedAt = Date.now();
    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const endResult = await endQuickFocus(
      hostContext,
      lockSnapshot,
      "契约已履行",
      "专注已结束，但解除限制失败",
      true,
    );
    if (endResult.ok && !endResult.tooShort && UserStore.isLoggedIn()) {
      queueHonorCertificate(lockSnapshot, endedAt);
      tryPresentCertificateGuide(this.getUIContext());
    } else {
      afterGuestSoloFocusEnded(this.getUIContext(), lockSnapshot, hostContext, false);
    }
    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
    this.startTimer();
  }

  private async performTearLock(): Promise<void> {
    if (this.isEndingLock) {
      return;
    }
    const lockSnapshot = normalizeActiveLockState(this.activeLock);
    const endedAt = Date.now();
    if (this.activeLock.kind === "quick_focus") {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const endResult = await tearQuickFocus(hostContext, lockSnapshot);
      if (endResult.ok && !endResult.tooShort && UserStore.isLoggedIn()) {
        // 已登录：弹耻辱证；游客单人只走登录引导
        queueShameCertificate(lockSnapshot, endedAt, "violator", "tear");
        tryPresentCertificateGuide(this.getUIContext());
      } else {
        afterGuestSoloFocusEnded(this.getUIContext(), lockSnapshot, hostContext, false);
      }
      this.remainingLabel = LockStore.getRemainingLabel();
      this.isEndingLock = false;
      this.startTimer();
      return;
    }
    if (this.activeLock.kind === "covenant") {
      this.isEndingLock = true;
      this.clearTimer();
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const endResult = await tearCovenantWindow(hostContext, lockSnapshot);
      if (endResult.ok && !endResult.tooShort) {
        queueShameCertificate(lockSnapshot, endedAt, "violator", "tear");
        tryPresentCertificateGuide(this.getUIContext());
      }
      this.remainingLabel = LockStore.getRemainingLabel();
      this.isEndingLock = false;
      this.startTimer();
    }
  }

  private async performEndLock(): Promise<void> {
    if (this.isEndingLock || !this.isActiveLocked()) {
      return;
    }

    this.isEndingLock = true;
    this.clearTimer();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

    if (this.activeLock.kind === "cycle_guard") {
      await endCycleGuardLock(hostContext);
    }

    this.remainingLabel = LockStore.getRemainingLabel();
    this.isEndingLock = false;
    this.startTimer();
  }

  private isDuoFocus(): boolean {
    return this.activeLock.participationMode === "duo";
  }

  private getSelfDisplayName(): string {
    const username = UserStore.getUserInfo().username.trim();
    return username.length > 0 ? username : "我";
  }

  private getPartnerDisplayName(): string {
    const nickname = this.activeLock.partnerNickname.trim();
    return nickname.length > 0 ? nickname : "搭子";
  }

  private getFocusKindLabel(): string {
    if (this.isDuoFocus()) {
      return isCountupLock(this.activeLock) ? "搭子互督 · 正计时" : "搭子互督";
    }
    if (this.activeLock.kind === "covenant") {
      return "单人定时契约";
    }
    if (this.activeLock.kind === "quick_focus") {
      if (isOrgClassroomLockPlanId(this.activeLock.planId)) {
        return "组织课堂";
      }
      if (this.activeLock.isDelayedSolo) {
        return isCountupLock(this.activeLock) ? "单人延时 · 正计时" : "单人延时契约";
      }
      return isCountupLock(this.activeLock) ? "单人即时 · 正计时" : "单人即时契约";
    }
    return "专注中";
  }

  private getLockStatusText(): string {
    const count = this.activeLock.selectedCount;
    const modeLabel = this.activeLock.mode === "allow" ? "白名单模式" : "黑名单模式";
    if (this.activeLock.mode === "allow") {
      return `已放行 ${count} 个应用 · ${modeLabel}`;
    }
    return `已限制 ${count} 个应用 · ${modeLabel}`;
  }

  private getTotalDurationMinutes(): number {
    if (this.activeLock.endAt <= 0 || this.activeLock.startedAt <= 0) {
      return 0;
    }
    return Math.max(Math.floor((this.activeLock.endAt - this.activeLock.startedAt) / 60000), 0);
  }

  private getFocusSubtitle(): string {
    const kindLabel = this.getFocusKindLabel();
    if (isCountupLock(this.activeLock)) {
      // 正计时：对齐 RN，副标题只保留类型，不挂「最短 xx」
      return kindLabel;
    }
    const totalMinutes = this.getTotalDurationMinutes();
    if (totalMinutes > 0) {
      return `${kindLabel} · 共 ${minutesToHours(totalMinutes)}`;
    }
    return kindLabel;
  }

  private getProgressValue(): number {
    if (this.activeLock.startedAt <= 0) {
      return 0;
    }
    if (isCountupLock(this.activeLock)) {
      const totalMs = Math.max(1, this.activeLock.minDurationMin) * 60 * 1000;
      const elapsedMs = Math.max(0, Date.now() - this.activeLock.startedAt);
      return Math.min(Math.max((elapsedMs / totalMs) * 100, 0), 100);
    }
    if (this.activeLock.endAt <= 0) {
      return 0;
    }
    const totalMs = this.activeLock.endAt - this.activeLock.startedAt;
    if (totalMs <= 0) {
      return 0;
    }
    const remainingMs = Math.max(this.activeLock.endAt - Date.now(), 0);
    const elapsedMs = totalMs - remainingMs;
    return Math.min(Math.max((elapsedMs / totalMs) * 100, 0), 100);
  }

  private getElapsedMinutes(): number {
    if (this.activeLock.startedAt <= 0) {
      return 0;
    }
    if (isCountupLock(this.activeLock)) {
      return Math.max(Math.floor(getElapsedSeconds(this.activeLock, Date.now()) / 60), 0);
    }
    if (this.activeLock.endAt <= 0) {
      return 0;
    }
    const totalSeconds = Math.floor((this.activeLock.endAt - this.activeLock.startedAt) / 1000);
    const remainingSeconds = getRemainingSeconds(this.activeLock, Date.now());
    return Math.max(Math.floor((totalSeconds - remainingSeconds) / 60), 0);
  }

  private shouldUseCompactTime(): boolean {
    return this.remainingLabel.length > 5;
  }

  private canShowTearButton(): boolean {
    return (
      this.activeLock.kind === "quick_focus" ||
      this.activeLock.kind === "covenant" ||
      this.activeLock.kind === "cycle_guard"
    );
  }

  /** 开发环境：跳过输入确认，方便调试撕毁流程 */
  private canShowInstantTearButton(): boolean {
    if (!ApiConfig.isDevEnvironment() || this.isEndingLock) {
      return false;
    }
    if (this.activeLock.kind === "quick_focus" && this.isPastCountupMin()) {
      return false;
    }
    return this.activeLock.kind === "quick_focus" || this.activeLock.kind === "covenant";
  }

  private getEndLockButtonLabel(): string {
    if (isOrgClassroomLockPlanId(this.activeLock.planId)) {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const meta = loadOrgClassroomMeta(hostContext);
      if (meta && meta.exitRequestPending) {
        return "等待审批";
      }
      return meta && meta.allowExit ? "申请退出" : "退出";
    }
    if (this.activeLock.kind === "quick_focus" && this.isPastCountupMin()) {
      return "结束专注";
    }
    if (this.activeLock.kind === "quick_focus" || this.activeLock.kind === "covenant") {
      return "撕毁契约";
    }
    if (this.activeLock.kind === "cycle_guard") {
      return "结束当前锁定";
    }
    return "结束";
  }

  @Builder
  private buildStatusIcon(isLockedState: boolean): void {
    Stack() {
      if (!isLockedState) {
        Column()
          .width(112)
          .height(112)
          .borderRadius(56)
          .backgroundColor(AppTheme.colors.primarySoft)
          .opacity(0.22)
          .blur(40);
      }
      Column()
        .width(72)
        .height(72)
        .borderRadius(36)
        .backgroundColor(AppTheme.colors.primarySoft)
        .opacity(1)
      if (isLockedState) {
        SymbolGlyph($r("sys.symbol.lock_fill"))
          .fontSize(40)
          .fontColor([AppTheme.colors.primary])
          .fontWeight(500);
      } else {
        UsersIcon({ iconSize: 40, color: AppTheme.colors.primary });
      }
    }
    .width(120)
    .height(120)
    .alignContent(Alignment.Center);
  }

  @Builder
  private buildWeakTearButton(): void {
    Row() {
      Text(this.getEndLockButtonLabel())
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isPastCountupMin() ? AppTheme.colors.primary : AppTheme.colors.textMuted)
    }
    .height(40)
    .padding({ left: 20, right: 20 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({
      width: 1,
      color: this.isPastCountupMin() ? AppTheme.colors.primary : AppTheme.colors.border,
    })
    .borderRadius(AppTheme.radius.button)
    .clip(true)
    .opacity(this.isEndingLock ? 0.5 : 1)
    .enabled(!this.isEndingLock)
    .onClick(() => {
      void this.endCurrentLock();
    });
  }

  @Builder
  private buildInstantTearButton(): void {
    Row() {
      Text("立即撕毁")
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.danger)
    }
    .height(40)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.danger })
    .borderRadius(AppTheme.radius.button)
    .clip(true)
    .opacity(this.isEndingLock ? 0.5 : 1)
    .enabled(!this.isEndingLock)
    .onClick(() => {
      void this.performTearLock();
    });
  }

  @Builder
  private buildTearActions(): void {
    if (this.canShowInstantTearButton()) {
      Row({ space: 10 }) {
        this.buildWeakTearButton();
        this.buildInstantTearButton();
      }
    } else if (this.canShowTearButton()) {
      this.buildWeakTearButton();
    }
  }

  @Builder
  private buildLockStatusChip(): void {
    Row({ space: 6 }) {
      SymbolGlyph(
        this.activeLock.mode === "allow"
          ? $r("sys.symbol.checkmark_circle")
          : $r("sys.symbol.lock_fill"),
      )
        .fontSize(14)
        .fontColor([AppTheme.colors.primary])
      Text(this.getLockStatusText())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.primary)
    }
    .padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .backgroundColor(AppTheme.colors.primarySoft)
    .borderRadius(AppTheme.radius.pill)
    .margin({ bottom: 10 });
  }

  private canOpenWhitelist(): boolean {
    return this.activeLock.mode === "allow";
  }

  private async openWhitelistApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await openTrustListAppForm(
      hostContext,
      this.activeLock.selectedTokens,
      "点击图标打开应用",
    );
    if (!result.ok) {
      showToast(result.message, this.getUIContext());
    }
  }

  @Builder
  private buildOpenWhitelistButton(): void {
    Row({ space: 6 }) {
      SymbolGlyph($r("sys.symbol.square_grid_2x2"))
        .fontSize(15)
        .fontColor([AppTheme.colors.primary])
      Text("打开白名单应用")
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.primary)
    }
    .padding({ top: 8, bottom: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      void this.openWhitelistApps();
    });
  }

  @Builder
  private buildLockedState(): void {
    Column({ space: 24 }) {
      FocusTimeRing({
        remainingLabel: this.remainingLabel,
        elapsedMinutes: this.getElapsedMinutes(),
        progressValue: this.getProgressValue(),
        isDuo: this.isDuoFocus(),
        useCompactTime: this.shouldUseCompactTime(),
        isCountup: isCountupLock(this.activeLock),
        minDurationMinutes: this.activeLock.minDurationMin,
      })

      this.buildLockStatusChip()
      Column({ space: 4 }) {
        Text(this.activeLock.title)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getFocusSubtitle())
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .textAlign(TextAlign.Center)
          .lineHeight(22)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Center)

      Column({ space: 12 }) {
        if (this.canOpenWhitelist()) {
          this.buildOpenWhitelistButton();
        }
        if (this.canShowTearButton() || this.canShowInstantTearButton()) {
          this.buildTearActions();
        }
      }
      .margin({ top: 48 })
      .alignItems(HorizontalAlign.Center)
    }
    .width("100%")
    .padding({
      left: 24,
      right: 24,
      top: this.isDuoFocus() ? 48 : 0,
    })
    .alignItems(HorizontalAlign.Center);
  }

  private ensureLoginThen(route: string): void {
    if (!UserStore.isLoggedIn()) {
      pushLogin();
      return;
    }
    // 仅发起互督进页前校验；加入互督放宽不校验
    if (route === PageRoutes.DuoCreate) {
      void this.ensureQuotaThenNavigate(route);
      return;
    }
    pushRoute(route);
  }

  private async ensureQuotaThenNavigate(route: string): Promise<void> {
    if (!(await ensureDailyFocusQuota(this.getUIContext()))) {
      return;
    }
    pushRoute(route);
  }

  @Builder
  private buildDuoActionButton(
    label: string,
    symbol: Resource,
    iconColor: string,
    onPress: () => void,
  ): void {
    Button() {
      Column({ space: 8 }) {
        Row() {
          SymbolGlyph(symbol)
            .fontSize(20)
            .fontColor([iconColor])
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .borderRadius(18)
        Text(label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
      }
      .width("100%")
      .alignItems(HorizontalAlign.Center)
    }
    .layoutWeight(1)
    .height(88)
    .type(ButtonType.Normal)
    .buttonStyle(ButtonStyleMode.NORMAL)
    .padding({ left: 8, right: 8, top: 12, bottom: 12 })
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(18)
    .clip(true)
    .onClick(() => {
      onPress();
    });
  }

  @Builder
  private buildSoloFocusLink(): void {
    Row({ space: 4 }) {
      SymbolGlyph($r("sys.symbol.bolt"))
        .fontSize(15)
        .fontColor([AppTheme.colors.primary])
      Text("先自己练练？单人专注")
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.primary)
    }
    .justifyContent(FlexAlign.Center)
    .height(40)
    .padding({ left: 12, right: 12 })
    .opacity(this.soloLinkPressed ? 0.7 : 1)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.soloLinkPressed = true;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.soloLinkPressed = false;
      }
    })
    .onClick(() => {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (!ensureSoloFocusAccess(hostContext)) {
        return;
      }
      void this.openSoloQuickStart();
    });
  }

  private async openSoloQuickStart(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (hasPendingQuickStart(hostContext)) {
      showToast("已有预约中的专注，请等待开始或先取消", this.getUIContext());
      return;
    }
    if (UserStore.isLoggedIn()) {
      if (!(await ensureDailyFocusQuota(this.getUIContext()))) {
        return;
      }
    }
    pushRoute(PageRoutes.QuickStart);
  }

  @Builder
  private buildScheduledLink(): void {
    Row({ space: 4 }) {
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(15)
        .fontColor([AppTheme.colors.textSecondary])
      Text('定时契约 · 到点自动开始')
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([AppTheme.colors.textMuted])
    }
    .justifyContent(FlexAlign.Center)
    .height(40)
    .margin({ top: 8 })
    .onClick(() => {
      this.onSelectTab?.('plans');
    })
  }

  @Builder
  private buildPendingQuickStartState(): void {
    Column({ space: 0 }) {
      Row({ space: 4 }) {
        SymbolGlyph($r("sys.symbol.clock"))
          .fontSize(18)
          .fontColor([AppTheme.colors.primary])
        Text("等待开始")
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textSecondary)
      }
      .margin({ bottom: 20 })

      Text(this.formatPendingRemainLabel())
        .fontSize(64)
        .fontWeight(FontWeight.Lighter)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)

      Text(this.pendingQuickStartTitle)
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .textAlign(TextAlign.Center)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 40 })
        .constraintSize({ maxWidth: 280 })

      Text(`${this.pendingQuickStartDelayMin} 分钟后自动锁机`)
        .fontSize(15)
        .fontColor(AppTheme.colors.textSecondary)
        .textAlign(TextAlign.Center)
        .margin({ top: 12 })

      Text("取消预约")
        .fontSize(15)
        .fontColor(AppTheme.colors.warning)
        .textAlign(TextAlign.Center)
        .margin({ top: 64 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .onClick(() => {
          const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          void cancelPendingQuickStart(hostContext);
        })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private buildEmptyState(): void {
    Column({ space: 24 }) {
      Column({ space: 12 }) {
        this.buildStatusIcon(false)
        Column({ space: 10 }) {
          Text('和搭子一起专注')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppTheme.colors.textPrimary)
            .textAlign(TextAlign.Center)
          Text('双人互督，连坐机制，一人毁约两人失败')
            .fontSize(16)
            .fontColor(AppTheme.colors.textSecondary)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Row({ space: 12 }) {
        this.buildDuoActionButton(
          '发起互督',
          $r('sys.symbol.person_badge_plus'),
          AppTheme.colors.accentBlue,
          () => {
            this.ensureLoginThen(PageRoutes.DuoCreate);
          },
        )

        this.buildDuoActionButton(
          '加入互督',
          $r('sys.symbol.link'),
          AppTheme.colors.accentOrange,
          () => {
            this.ensureLoginThen(PageRoutes.DuoJoin);
          },
        )
      }.width('100%')

      Column({ space: 4 }) {
        this.buildSoloFocusLink()
        this.buildScheduledLink()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .alignItems(HorizontalAlign.Center);
  }

  @Builder
  private buildOrgEntryButton(): void {
    Row({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        UsersIcon({ iconSize: 22, color: AppTheme.colors.textPrimary })
      }
      .width(42)
      .height(42)
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.border })
      .borderRadius(21)
      .onClick(() => {
        this.onOrgEntryPress();
      })

      Stack() {
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.bell'))
            .fontSize(22)
            .fontColor([AppTheme.colors.textPrimary])
        }
        .width(42)
        .height(42)
        .backgroundColor(AppTheme.colors.surface)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(21)
        .onClick(() => {
          this.onInboxPress();
        })

        if (this.inboxImportant > 0) {
          Row() {
            Text(inboxBadgeLabel(this.inboxImportant))
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
          }
          .height(16)
          .padding({ left: 4, right: 4 })
          .borderRadius(8)
          .backgroundColor(AppTheme.colors.danger)
          .justifyContent(FlexAlign.Center)
          .position({ x: 24, y: 2 })
        } else if (this.inboxUnread > 0) {
          Circle()
            .width(8)
            .height(8)
            .fill(AppTheme.colors.danger)
            .position({ x: 28, y: 6 })
        }
      }
      .width(42)
      .height(42)
    }
    .width("100%")
    .padding({ left: 20, right: 20, top: this.topSafeInsetVp + 8 })
    .justifyContent(FlexAlign.End)
  }

  @Builder
  private buildDuoWaitBanner(): void {
    Column() {
      Row({ space: 12 }) {
        Row() {
          UsersIcon({ iconSize: 18, color: AppTheme.colors.primary })
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(AppTheme.colors.primarySoft)
        .borderRadius(18)
        Column({ space: 2 }) {
          Text("等待搭子加入")
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppTheme.colors.textPrimary)
            .width("100%")
          Text(this.getDuoWaitEntryDetail())
            .fontSize(12)
            .fontColor(AppTheme.colors.textSecondary)
            .width("100%")
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width("100%")
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor(AppTheme.colors.surface)
      .border({ width: 1, color: AppTheme.colors.primarySoft })
      .borderRadius(28)
      // 对齐 iOS：轻阴影（低透明度 + 大模糊），避免 Button 默认材质阴影发硬
      .shadow({
        radius: 16,
        color: "#14000000",
        offsetX: 0,
        offsetY: 4,
      })
      .onClick(() => {
        openDuoWaitPage();
      })
    }
    .width("100%")
    .padding({
      left: 20,
      right: 20,
      top: this.topSafeInsetVp + 6,
    });
  }

  @Builder
  private buildHomeContent(): void {
    if (this.isActiveLocked()) {
      Column() {
        this.buildLockedState()
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center);
    } else if (this.hasPendingQuickStart()) {
      Column() {
        this.buildPendingQuickStartState()
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 24, right: 24 })
      .offset({ y: -20 });
    } else {
      Column() {
        this.buildEmptyState()
      }
      .width("100%")
      .height("100%")
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .offset({ y: -20 });
    }
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      SystemNavPage({
        title: "专注",
        showTitleBar: false,
        usePageScroll: false,
        content: (): void => {
          this.buildHomeContent();
        },
      })

      if (!this.isActiveLocked() && this.hasPendingDuoWait()) {
        this.buildDuoWaitBanner();
      }

      if (this.shouldShowOrgEntry()) {
        this.buildOrgEntryButton();
      }

      if (this.isActiveLocked() && this.isDuoFocus()) {
        DuoFocusHeader({
          selfName: this.getSelfDisplayName(),
          partnerName: this.getPartnerDisplayName(),
        }).padding({
          left: 24,
          right: 24,
          top: this.topSafeInsetVp + 16,
        });
      }
      InputConfirmSheet({
        visible: this.showTearConfirm,
        title: "撕毁契约",
        message: this.getTearConfirmMessage(),
        extraWarning: this.getTearExtraWarning(),
        requiredText: this.getTearRequiredText(),
        confirmText: "确认撕毁",
        cancelText: this.getTearCancelText(),
        inputHint: "请输入以下文字确认：",
        onConfirm: () => {
          void this.performTearLock();
        },
        onCancel: () => {},
      })
    }
    .width("100%")
    .height("100%");
  }
}
