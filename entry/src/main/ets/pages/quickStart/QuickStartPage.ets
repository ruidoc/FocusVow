import { common } from "@kit.AbilityKit";
import { router } from "@kit.ArkUI";
import { QuickFocusOptions } from "../../models/ActiveLockModel";
import { QuickTaskUpsertPayload } from "../../models/QuickTaskModel";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { FocusDurationCard } from "../../components/focus/FocusDurationCard";
import { TimerModeSegmented } from "../../components/focus/TimerModeSegmented";
import { AppTheme } from "../../constants/Theme";
import { backRoute, openQuickTaskTabOnce, returnToMainTab } from "../../router/PageRoutes";
import { applyScreenRestriction, chooseRestrictedApps } from "../../services/ScreenTimeService";
import { blockIfOverlapsScheduledPlan, conflictWindowMinutes } from "../../services/ScheduledPlanValidation";
import { ensureSoloFocusAccess } from "../../services/GuestSoloFocusService";
import { ensureTaskPermission } from "../../utils/TaskPermissionUtil";
import { AnalyticsService } from "../../services/AnalyticsService";
import {
  getQuickStartDelayOptions,
  getStartDelayHint,
  getStartDelayPickerLabel,
  hasPendingQuickStart,
  schedulePendingQuickStart,
} from "../../services/PendingQuickStartService";
import { LockStore } from "../../stores/LockStore";
import { QuickTaskStore } from "../../stores/QuickTaskStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";
import { TimerMode } from "../../utils/TimerMode";
import { getFocusCount } from "../../utils/UserActivationUtil";
import {
  clearMembershipUrgencyCountdown,
  expireMembershipUrgencyIfNeeded,
  hasSkippedMembershipSignup,
  isOnboardingMembershipBenefitActive,
  shouldShowOnboardingActivationBanner,
  startMembershipUrgencyCountdown,
} from "../../utils/OnboardingMembershipUtil";
import {
  ensureQuickTaskQuota,
  ensureDelayStartAllowed,
  normalizeDelayMinutes,
} from "../../services/ProQuotaService";
import { FIRST_FOCUS_TITLE } from "../../services/FirstFocusPromptService";

bootstrapStores();

interface QuickStartRouteParams {
  title?: string;
  minute?: string;
  from_onboarding?: string;
  delay?: string;
}

@Entry
@Component
struct QuickStartPage {
  @StorageLink(StoreKeys.SettingsHasAuthorized) hasAuthorized: boolean = false;
  @StorageLink(StoreKeys.SettingsSelectedTokens) selectedTokens: string[] = [];
  @StorageLink(StoreKeys.SettingsSelectedAppCount) selectedAppCount: number = 0;
  @State durationMinutes: number = 15;
  @State startDelayMinutes: number = 0;
  @State timerMode: TimerMode = "countdown";
  @State mode: "shield" | "allow" = "allow";
  @State title: string = "";
  @State saveToQuickTask: boolean = false;
  @State private membershipUiTick: number = 0;
  private isDelayedEntry: boolean = false;
  private fromOnboarding: boolean = false;
  private focusStarted: boolean = false;
  private membershipTimerId: number = -1;

  private readonly durationMin: number = 5;
  private readonly durationMax: number = 180;
  private readonly durationStep: number = 5;

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    LockStore.hydrate(hostContext);
    const params = router.getParams() as QuickStartRouteParams;
    if (params) {
      this.fromOnboarding = params.from_onboarding === "1" || params.from_onboarding === "true";
      const presetTitle = String(params.title ?? "").trim();
      if (presetTitle.length > 0) {
        this.title = presetTitle;
      } else if (this.shouldShowMembershipTip()) {
        this.title = FIRST_FOCUS_TITLE;
      }
      const presetMinutes = Number(params.minute ?? 0);
      if (presetMinutes >= this.durationMin) {
        const normalizedPreset = this.normalizeDurationMinutes(presetMinutes);
        this.durationMinutes = normalizedPreset;
        LockStore.setQuickFocusDurationMinutes(hostContext, normalizedPreset);
      } else {
        const rawDuration = LockStore.getQuickFocusDurationMinutes();
        const normalized = this.normalizeDurationMinutes(rawDuration);
        this.durationMinutes = normalized;
        if (normalized !== rawDuration) {
          LockStore.setQuickFocusDurationMinutes(hostContext, normalized);
        }
      }
      const presetDelayRaw = Number(params.delay ?? 0);
      if (presetDelayRaw > 0) {
        this.isDelayedEntry = true;
        const delay = normalizeDelayMinutes(presetDelayRaw);
        const options = getQuickStartDelayOptions(true);
        if (options.indexOf(delay) >= 0) {
          this.startDelayMinutes = delay;
        } else if (options.length > 0) {
          this.startDelayMinutes = options[0];
        }
      }
    } else {
      if (this.shouldShowMembershipTip()) {
        this.title = FIRST_FOCUS_TITLE;
      }
      const rawDuration = LockStore.getQuickFocusDurationMinutes();
      const normalized = this.normalizeDurationMinutes(rawDuration);
      this.durationMinutes = normalized;
      if (normalized !== rawDuration) {
        LockStore.setQuickFocusDurationMinutes(hostContext, normalized);
      }
    }
    this.focusStarted = false;
    const viewedProps: Record<string, Object> = {};
    viewedProps["is_first_focus"] = getFocusCount(hostContext) === 0;
    viewedProps["from_onboarding"] = this.fromOnboarding;
    viewedProps["entry_source"] = this.fromOnboarding ? "onboarding" : "quick_start";
    viewedProps["screen_name"] = "quick_start";
    AnalyticsService.trackEvent("quick_start_viewed", viewedProps);
    this.startMembershipUiTimer();
  }

  onPageShow(): void {
    this.startMembershipUiTimer();
  }

  onPageHide(): void {
    this.clearMembershipUiTimer();
    if (!this.fromOnboarding || this.focusStarted) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!isOnboardingMembershipBenefitActive(hostContext)) {
      return;
    }
    if (getFocusCount(hostContext) > 0) {
      return;
    }
    if (hasPendingQuickStart(hostContext) || LockStore.isLocked()) {
      return;
    }
    startMembershipUrgencyCountdown(hostContext);
  }

  private startMembershipUiTimer(): void {
    this.clearMembershipUiTimer();
    this.membershipUiTick += 1;
    this.membershipTimerId = setInterval(() => {
      const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      expireMembershipUrgencyIfNeeded(hostContext);
      this.membershipUiTick += 1;
    }, 1000);
  }

  private clearMembershipUiTimer(): void {
    if (this.membershipTimerId !== -1) {
      clearInterval(this.membershipTimerId);
      this.membershipTimerId = -1;
    }
  }

  private isMembershipSimplified(): boolean {
    const _tick = this.membershipUiTick;
    return this.shouldShowMembershipTip();
  }

  private shouldShowMembershipTip(): boolean {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    expireMembershipUrgencyIfNeeded(hostContext);
    return (
      (this.fromOnboarding || shouldShowOnboardingActivationBanner(hostContext)) &&
      isOnboardingMembershipBenefitActive(hostContext)
    );
  }

  private isGuestMembershipPath(): boolean {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    return hasSkippedMembershipSignup(hostContext) && !UserStore.isLoggedIn();
  }

  private normalizeDurationMinutes(raw: number): number {
    let d = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    d = Math.round(d / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, d));
  }

  private appCardTitle(): string {
    return this.mode === "shield" ? "要锁定的应用" : "允许使用的应用";
  }

  private getPageTitle(): string {
    return this.isDelayedEntry ? "延时专注" : "立即专注";
  }

  private shouldShowStartDelayCard(): boolean {
    return !this.isMembershipSimplified() && this.isDelayedEntry;
  }

  private getStartDelayOptions(): number[] {
    return getQuickStartDelayOptions(this.isDelayedEntry);
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (
      !(await ensureTaskPermission(hostContext, this.getUIContext(), {
        entry_source: this.fromOnboarding ? "onboarding" : "quick_start",
        screen_name: "quick_start",
      }))
    ) {
      return;
    }
    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    if (result.data) {
      SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      return;
    }
    this.toastError(result.message);
  }

  private async startFocus(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const uiContext = this.getUIContext();

    if (
      !(await ensureTaskPermission(hostContext, uiContext, {
        entry_source: this.fromOnboarding ? "onboarding" : "quick_start",
        screen_name: "quick_start",
      }))
    ) {
      return;
    }

    if (this.saveToQuickTask) {
      if (!UserStore.isLoggedIn()) {
        showErrorToast("登录后才能保存到快捷任务", this.getUIContext());
        return;
      }
      if (this.title.trim().length === 0) {
        showErrorToast("请先填写本次契约要做什么", this.getUIContext());
        return;
      }
      if (QuickTaskStore.isDirty()) {
        await QuickTaskStore.loadAll();
      }
      if (!ensureQuickTaskQuota()) {
        return;
      }
      if (QuickTaskStore.titleExists(this.title.trim())) {
        showErrorToast("已有同名快捷任务，请修改名称", this.getUIContext());
        return;
      }
      const payload: QuickTaskUpsertPayload = {
        title: this.title.trim(),
        duration_min: this.durationMinutes,
        timer_mode: this.timerMode,
        mode: this.mode,
        delay_min: this.startDelayMinutes,
        no_stop: false,
        apps: [...this.selectedTokens],
      };
      try {
        const response = await QuickTaskStore.createTask(payload);
        if (response.statusCode !== 200) {
          const errMsg =
            typeof response.message === "string" && response.message.length > 0
              ? response.message
              : "保存快捷任务失败";
          showErrorToast(errMsg, this.getUIContext());
          return;
        }
        showToast("已保存到快捷任务", this.getUIContext());
        openQuickTaskTabOnce();
      } catch (_error) {
        showErrorToast("保存快捷任务失败", this.getUIContext());
      }
      return;
    }

    if (!ensureSoloFocusAccess(hostContext)) {
      return;
    }
    if (hasPendingQuickStart(hostContext)) {
      showErrorToast("已有预约中的专注，请等待开始", this.getUIContext());
      return;
    }
    if (this.title.trim().length === 0) {
      showErrorToast("请先填写本次契约要做什么");
      return;
    }

    if (LockStore.isLocked()) {
      this.toastError("当前已有进行中的锁定，请先回首页结束后再开始新的专注");
      return;
    }

    if (this.startDelayMinutes > 0) {
      if (!ensureDelayStartAllowed(hostContext, this.startDelayMinutes)) {
        return;
      }
      clearMembershipUrgencyCountdown(hostContext);
      const scheduled = await schedulePendingQuickStart(hostContext, {
        title: this.title.trim(),
        durationMinutes: this.durationMinutes,
        timerMode: this.timerMode,
        mode: this.mode,
        delayMinutes: this.startDelayMinutes,
        fromOnboarding: this.fromOnboarding,
      });
      if (!scheduled) {
        this.toastError("预约失败，请稍后重试");
        return;
      }
      showToast(`${this.startDelayMinutes} 分钟后开始专注`, this.getUIContext());
      returnToMainTab("focus");
      return;
    }

    if (blockIfOverlapsScheduledPlan(conflictWindowMinutes(this.timerMode, this.durationMinutes))) {
      return;
    }

    const result = await applyScreenRestriction(this.selectedTokens, this.mode);
    if (!result.ok) {
      this.toastError(result.message);
      return;
    }

    const taskTitle = this.title.trim();
    this.focusStarted = true;
    clearMembershipUrgencyCountdown(hostContext);
    const focusOptions: QuickFocusOptions = {
      title: taskTitle,
      duoSessionId: "",
      recordId: "",
      participationMode: "solo",
      timerMode: this.timerMode,
      minDurationMin: this.timerMode === "countup" ? this.durationMinutes : 0,
    };
    LockStore.startQuickFocus(
      hostContext,
      this.selectedTokens,
      this.durationMinutes,
      this.mode,
      focusOptions,
    );
    const sessionProps: Record<string, Object> = {};
    sessionProps["plan_id"] = LockStore.getState().planId;
    sessionProps["focus_type"] = "once";
    sessionProps["duration_minutes"] = this.durationMinutes;
    sessionProps["mode"] = this.mode;
    sessionProps["entry_source"] = this.fromOnboarding ? "onboarding" : "quick_start";
    sessionProps["is_first_focus"] = this.fromOnboarding;
    AnalyticsService.trackEvent("session_started", sessionProps);
    returnToMainTab("focus");
  }

  private onDurationSliderChange(value: number): void {
    const next = this.normalizeDurationMinutes(value);
    this.durationMinutes = next;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    LockStore.setQuickFocusDurationMinutes(hostContext, next);
  }

  private getStartDelayPickerLabels(): string[] {
    const labels: string[] = [];
    this.getStartDelayOptions().forEach((minutes: number) => {
      labels.push(getStartDelayPickerLabel(minutes));
    });
    return labels;
  }

  private getStartDelayPickerSelectedIndex(): number {
    const options = this.getStartDelayOptions();
    const idx = options.indexOf(this.startDelayMinutes);
    return idx >= 0 ? idx : 0;
  }

  private resolvePickerIndex(raw: number | number[]): number {
    if (raw instanceof Array) {
      if (raw.length > 0) {
        return raw[0];
      }
      return -1;
    }
    return raw;
  }

  private openStartDelayPicker(): void {
    this.getUIContext().showTextPickerDialog({
      range: this.getStartDelayPickerLabels(),
      selected: this.getStartDelayPickerSelectedIndex(),
      canLoop: false,
      onAccept: (value: TextPickerResult) => {
        const index = this.resolvePickerIndex(value.index);
        const options = this.getStartDelayOptions();
        if (index >= 0 && index < options.length) {
          this.startDelayMinutes = options[index];
        }
      },
    });
  }

  @Builder
  buildStartDelayCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text("开始时间")
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text(getStartDelayPickerLabel(this.startDelayMinutes))
          .fontSize(14)
          .fontColor(AppTheme.colors.textSecondary)
          .margin({ right: 4 })
        SymbolGlyph($r("sys.symbol.chevron_right"))
          .fontSize(14)
          .fontColor([AppTheme.colors.textMuted])
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.openStartDelayPicker();
      })

      if (this.startDelayMinutes > 0) {
        Text(getStartDelayHint(this.startDelayMinutes))
          .fontSize(13)
          .fontColor(AppTheme.colors.warning)
          .width("100%");
      }
    }
    .width("100%")
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  buildModeSegment(): void {
    Row({ space: 0 }) {
      Text("锁定模式")
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(
          this.mode === "shield" ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary,
        )
        .fontWeight(this.mode === "shield" ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === "shield" ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = "shield";
        })
      Text("放行模式")
        .layoutWeight(1)
        .fontSize(15)
        .fontColor(
          this.mode === "allow" ? AppTheme.colors.textPrimary : AppTheme.colors.textSecondary,
        )
        .fontWeight(this.mode === "allow" ? FontWeight.Medium : FontWeight.Regular)
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })
        .borderRadius(20)
        .backgroundColor(this.mode === "allow" ? AppTheme.colors.surfaceRaised : Color.Transparent)
        .onClick(() => {
          this.mode = "allow";
        })
    }
    .width("80%")
    .padding(4)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(999);
  }

  @Builder
  buildAppCard(): void {
    Column({ space: 14 }) {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.textPrimary)
        Text("+ 选择")
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppTheme.colors.primary)
          .onClick(() => {
            this.chooseApps();
          })
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)

      if (this.isMembershipSimplified()) {
        Text("默认全部禁用，可以选择可用的应用")
          .fontSize(13)
          .fontColor(AppTheme.colors.warning)
          .lineHeight(18)
          .width("100%");
      }

      if (this.selectedAppCount === 0) {
        Text("未选择应用").fontSize(15).fontColor(AppTheme.colors.textMuted).width("100%");
      } else {
        Text(`已选 ${this.selectedAppCount} 个应用`)
          .fontSize(15)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%");
      }
    }
    .width("100%")
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  buildMembershipTip(): void {
    Column({ space: 6 }) {
      Text(
        this.isGuestMembershipPath()
          ? "完成本次专注后登录，领取 7 天会员"
          : "完成本次专注，7 天会员立即到账！",
      )
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.accentGreen)
        .width("100%")
      Text(
        this.isGuestMembershipPath()
          ? "坚持完成锁机专注，登录后本次计入会员"
          : "开始专注后，大部分APP会被暂时禁用，请坚持完成。",
      )
        .fontSize(13)
        .fontColor(AppTheme.colors.textSecondary)
        .lineHeight(20)
        .width("100%")
    }
    .width("100%")
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor("#ECFDF5")
    .border({ width: 1, color: "rgba(16,185,129,0.22)" })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  buildQuickBody(): void {
    Column({ space: 18 }) {
      if (this.shouldShowMembershipTip()) {
        this.buildMembershipTip();
      }
      if (!this.isMembershipSimplified()) {
        Row() {
          Blank()
          TimerModeSegmented({
            value: this.timerMode,
            onChange: (mode: TimerMode) => {
              this.timerMode = mode;
            },
          })
          Blank()
        }.width("100%");
      }
      // 锁定/放行模式切换暂时隐藏
      // this.buildModeSegment()
      TextInput({ text: this.title, placeholder: "今天要完成什么？" })
        .width("100%")
        .height(44)
        .enterKeyType(EnterKeyType.Done)
        .onChange((value: string) => {
          this.title = value;
        })
        .onSubmit(() => {
          focusControl.requestFocus("");
        })

      this.buildAppCard()
      FocusDurationCard({
        timerMode: this.timerMode,
        durationMinutes: this.durationMinutes,
        onDurationChange: (value: number) => {
          this.onDurationSliderChange(value);
        },
      })
      if (this.shouldShowStartDelayCard()) {
        this.buildStartDelayCard();
      }
      Column({ space: 6 }) {
        if (!this.isMembershipSimplified()) {
          Row({ space: 4 }) {
            Checkbox()
              .select(this.saveToQuickTask)
              .selectedColor(AppTheme.colors.primary)
              .onChange((checked: boolean) => {
                this.saveToQuickTask = checked;
              })
            Text("保存到快捷任务，下次一键开启专注")
              .fontSize(14)
              .fontColor(AppTheme.colors.textSecondary)
              .layoutWeight(1)
          }
          .width("100%")
          .alignItems(VerticalAlign.Center);
        }
        Button(
          this.isMembershipSimplified()
            ? "开始专注"
            : this.saveToQuickTask
              ? "保存到快捷任务"
              : this.startDelayMinutes > 0
                ? "预约开始"
                : "开始专注",
        )
          .width("100%")
          .height(52)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .backgroundColor(AppTheme.colors.primary)
          .fontColor("#FFFFFF")
          .onClick(() => {
            this.startFocus();
          })
      }
      .width("100%")
      .margin({ top: 14 })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  build() {
    Stack() {
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => backRoute(),
        content: (): void => {
          this.buildQuickBody();
        },
      })
    }
    .width("100%")
    .height("100%");
  }
}
