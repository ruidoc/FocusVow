import { common } from "@kit.AbilityKit";
import { router } from "@kit.ArkUI";
import { QuickFocusOptions } from "../../models/ActiveLockModel";
import { QuickTaskUpsertPayload } from "../../models/QuickTaskModel";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { TimerModeSegmented } from "../../components/focus/TimerModeSegmented";
import { AppTheme } from "../../constants/Theme";
import { ApiConfig } from "../../config/ApiConfig";
import { backRoute, openQuickTaskTabOnce, returnToMainTab } from "../../router/PageRoutes";
import {
  applyScreenRestriction,
  chooseRestrictedApps,
  requestScreenTimeAuthorization,
} from "../../services/ScreenTimeService";
import { ensureSoloFocusAccess } from "../../services/GuestSoloFocusService";
import { ensureDailyFocusQuota } from "../../services/DailyFocusQuotaService";
import { AnalyticsService } from "../../services/AnalyticsService";
import {
  hasPendingQuickStart,
  getQuickStartDelayOptions,
  schedulePendingQuickStart,
} from "../../services/PendingQuickStartService";
import { LockStore } from "../../stores/LockStore";
import { QuickTaskStore } from "../../stores/QuickTaskStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { bootstrapStores } from "../../stores/StoreBootstrap";
import { StoreKeys } from "../../stores/StoreKeys";
import { TimerMode } from "../../utils/TimerMode";

bootstrapStores();

interface QuickStartRouteParams {
  title?: string;
  minute?: string;
  from_onboarding?: string;
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
  private fromOnboarding: boolean = false;

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
      this.fromOnboarding =
        params.from_onboarding === '1' || params.from_onboarding === 'true';
      const presetTitle = String(params.title ?? '').trim();
      if (presetTitle.length > 0) {
        this.title = presetTitle;
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
    } else {
      const rawDuration = LockStore.getQuickFocusDurationMinutes();
      const normalized = this.normalizeDurationMinutes(rawDuration);
      this.durationMinutes = normalized;
      if (normalized !== rawDuration) {
        LockStore.setQuickFocusDurationMinutes(hostContext, normalized);
      }
    }
    AnalyticsService.trackEvent('quick_start_viewed', {
      'is_first_focus': this.fromOnboarding,
      'from_onboarding': this.fromOnboarding,
      'entry_source': this.fromOnboarding ? 'onboarding' : 'quick_start',
      'screen_name': 'quick_start'
    });
  }

  private normalizeDurationMinutes(raw: number): number {
    let d = Math.max(this.durationMin, Math.min(this.durationMax, Math.floor(raw)));
    d = Math.round(d / this.durationStep) * this.durationStep;
    return Math.max(this.durationMin, Math.min(this.durationMax, d));
  }

  private durationLabel(): string {
    if (this.durationMinutes >= 60) {
      const h = Math.floor(this.durationMinutes / 60);
      const m = this.durationMinutes % 60;
      if (m === 0) {
        return `${h} 小时`;
      }
      return `${h} 小时 ${m} 分钟`;
    }
    return `${this.durationMinutes} 分钟`;
  }

  private appCardTitle(): string {
    return this.mode === "shield" ? "要锁定的应用" : "要放行的应用";
  }

  private durationCardTitle(): string {
    if (this.timerMode === "countup") {
      return "最短时长";
    }
    return this.mode === "shield" ? "锁定时长" : "放行时长";
  }

  private toastError(message: string): void {
    showErrorToast(message, this.getUIContext());
  }

  private async authorize(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const result = await requestScreenTimeAuthorization(hostContext);
    SettingsStore.updateAuthorization(hostContext, result.ok, result.message);
    if (!result.ok) {
      this.toastError(result.message);
    }
  }

  private async chooseApps(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!this.hasAuthorized) {
      await this.authorize();
      if (!SettingsStore.getState().hasAuthorized) {
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

  private async startFocus(): Promise<void> {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;

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
          const errMsg = typeof response.message === 'string' && response.message.length > 0
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

    const needMinutes = this.timerMode === 'countup' ? 0 : this.durationMinutes;
    if (!(await ensureDailyFocusQuota(this.getUIContext(), needMinutes))) {
      return;
    }
    if (LockStore.isLocked()) {
      this.toastError("当前已有进行中的锁定，请先回首页结束后再开始新的专注");
      return;
    }

    if (!this.hasAuthorized) {
      await this.authorize();
      if (!SettingsStore.getState().hasAuthorized) {
        return;
      }
    }

    if (this.startDelayMinutes > 0) {
      const scheduled = await schedulePendingQuickStart(hostContext, {
        title: this.title.trim(),
        durationMinutes: this.durationMinutes,
        timerMode: this.timerMode,
        mode: this.mode,
        delayMinutes: this.startDelayMinutes,
        fromOnboarding: this.fromOnboarding,
      });
      if (!scheduled) {
        this.toastError("预约失败，请检查健康使用设备权限");
        return;
      }
      showToast(`${this.startDelayMinutes} 分钟后开始专注`, this.getUIContext());
      returnToMainTab("focus");
      return;
    }

    const result = await applyScreenRestriction(this.selectedTokens, this.mode);
    if (!result.ok) {
      this.toastError(result.message);
      return;
    }

    const taskTitle = this.title.trim();
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
    AnalyticsService.trackEvent('session_started', {
      'plan_id': LockStore.getState().planId,
      'focus_type': 'once',
      'duration_minutes': this.durationMinutes,
      'mode': this.mode,
      'entry_source': this.fromOnboarding ? 'onboarding' : 'quick_start',
      'is_first_focus': this.fromOnboarding
    });
    returnToMainTab("focus");
  }

  private onDurationSliderChange(value: number): void {
    const next = this.normalizeDurationMinutes(value);
    this.durationMinutes = next;
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    LockStore.setQuickFocusDurationMinutes(hostContext, next);
  }

  private getStartDelayPickerLabel(minutes: number): string {
    if (minutes === 0) {
      return "立即";
    }
    if (minutes === 1 && ApiConfig.isDevEnvironment()) {
      return "1 分钟";
    }
    if (minutes === 60) {
      return "1 小时后";
    }
    return `${minutes} 分钟后`;
  }

  private getStartDelayPickerLabels(): string[] {
    const labels: string[] = [];
    getQuickStartDelayOptions().forEach((minutes: number) => {
      labels.push(this.getStartDelayPickerLabel(minutes));
    });
    return labels;
  }

  private getStartDelayPickerSelectedIndex(): number {
    const options = getQuickStartDelayOptions();
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
        const options = getQuickStartDelayOptions();
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

        Text(this.getStartDelayPickerLabel(this.startDelayMinutes))
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
        Text(`可以玩一会手机，${this.startDelayMinutes}分钟后自动进入专注`)
          .fontSize(13)
          .fontColor(AppTheme.colors.warning)
          .width("100%")
      }
    }
    .width("100%")
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
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
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  buildDurationCard(): void {
    Column({ space: 16 }) {
      Text(this.durationCardTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")

      if (this.timerMode === "countup") {
        Text("满最短时长后可随时正常结束。")
          .fontSize(13)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%");
      }
      Text(this.durationLabel())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.colors.primary)
        .width("100%")
        .textAlign(TextAlign.Center)
      Slider({
        value: this.durationMinutes,
        min: this.durationMin,
        max: this.durationMax,
        step: this.durationStep,
        style: SliderStyle.OutSet,
      })
        .width("100%")
        .blockColor(AppTheme.colors.primary)
        .trackColor(AppTheme.colors.border)
        .selectedColor(AppTheme.colors.primary)
        .showSteps(false)
        .showTips(false)
        .onChange((v: number) => {
          this.onDurationSliderChange(v);
        })
      Row() {
        Text("5 分钟")
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
        Blank()
        Text("3 小时")
          .fontSize(12)
          .fontColor(AppTheme.colors.textMuted)
      }.width("100%")
    }
    .width("100%")
    .padding(20)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .border({ width: 1, color: AppTheme.colors.border })
    .borderRadius(AppTheme.radius.lg);
  }

  @Builder
  buildQuickBody(): void {
    Column({ space: 18 }) {
      Row() {
        Blank()
        TimerModeSegmented({
          value: this.timerMode,
          onChange: (mode: TimerMode) => {
            this.timerMode = mode;
          },
        })
        Blank()
      }.width("100%")
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
      this.buildDurationCard()
      this.buildStartDelayCard()

      Column({ space: 6 }) {
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
        .alignItems(VerticalAlign.Center)

        Button(this.saveToQuickTask
          ? "保存到快捷任务"
          : (this.startDelayMinutes > 0 ? "预约开始" : "开始单人专注"))
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
        title: "单人专注",
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
