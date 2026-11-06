import { common } from "@kit.AbilityKit";
import { router } from "@kit.ArkUI";
import { showErrorToast, showToast } from "../../common/Toast";
import { SystemNavPage } from "../../components/common/SystemNavPage";
import { ProQuickPayHost } from "../../components/paywall/ProQuickPayDialog";
import { AppTheme } from "../../constants/Theme";
import {
  DEFAULT_PLAN_REPEAT_DAYS,
  PLAN_REPEAT_DAY_OPTIONS,
  getRepeatDayShortLabel,
  validateScheduledStartTime,
} from "../../models/PlanModel";
import {
  DuoScheduledCreatePayload,
  DuoScheduledUpdatePayload,
  DuoParticipationMode,
  DuoSessionView,
  getScheduleRepeatDays,
  getSessionApps,
  mergeSessionAppsForHarmony,
} from "../../models/DuoModel";
import {
  PageRoutes,
  backRoute,
  pushDuoPickFriend,
  pushRoute,
  replaceRoute,
} from "../../router/PageRoutes";
import { chooseRestrictedApps } from "../../services/ScreenTimeService";
import { DuoApiService } from "../../services/DuoApiService";
import { DuoInviteClipboardService } from "../../services/DuoInviteClipboardService";
import { takeDuoPartnerPick } from "../../services/DuoPartnerPickService";
import { setScheduledDuoWait } from "../../services/DuoWaitContextService";
import { markGuardSyncIssue, syncGuardForSession } from "../../services/ScheduledCovenantService";
import {
  DEFAULT_SCHEDULED_PLAN_MINUTES,
  MIN_SCHEDULED_PLAN_MINUTES,
  getScheduledDurationMinutes,
  validateScheduledPlanTime,
} from "../../services/ScheduledPlanValidation";
import { ScheduledListStore } from "../../stores/ScheduledListStore";
import { SettingsStore } from "../../stores/SettingsStore";
import { UserStore } from "../../stores/UserStore";
import { ensureProMembership, markQuickPayForeground } from "../../utils/PaywallNavigationUtil";
import { ensureTaskPermission } from "../../utils/TaskPermissionUtil";
import { promptSlotUpsellIfDisabled, upsellIfProSlotQuota } from "../../services/ProQuotaService";
import {
  SLEEP_DEFAULT_END_CLOCK,
  SLEEP_DEFAULT_START_CLOCK,
  SLEEP_WEEKLY_REPEAT,
  isSleepSchedule,
  validateSleepClockWindow,
} from "../../utils/ScheduledClockUtil";
import { bootstrapStores } from "../../stores/StoreBootstrap";

bootstrapStores();

/** 创建契约暂不展示履约方式，默认单人；改 true 可恢复 */
const SHOW_PARTICIPATION_MODE: boolean = false;

/** 与 TimePicker.onChange 入参结构对齐 */
interface PlanTimePickerResult {
  hour: number;
  minute: number;
}

interface PlanAddRouteParams {
  presetName?: string;
  presetStart?: string;
  presetEnd?: string;
  presetRepeat?: string;
  kind?: string;
}

@Entry
@Component
struct PlanAddPage {
  @State planName: string = "";
  @State startTime: string = "09:00";
  @State endTime: string = "09:30";
  @State repeatDays: number[] = [...DEFAULT_PLAN_REPEAT_DAYS];
  @State selectedTokens: string[] = [];
  @State mode: "shield" | "allow" = "allow";
  @State participationMode: DuoParticipationMode = "solo";
  @State isSaving: boolean = false;
  @State hasInitializedDefaultTime: boolean = false;
  @State timePickerVisible: boolean = false;
  @State timePickerTarget: "start" | "end" = "start";
  @State timePickerDraft: Date = new Date();
  @State statusMessage: string = "";
  @State duoTargetId: string = "";
  @State duoTargetName: string = "";
  @State planKind: string = "";
  @State private editingSession: DuoSessionView | null = null;

  private readonly dayOptions: number[] = PLAN_REPEAT_DAY_OPTIONS;
  private nameInputController: TextInputController = new TextInputController();

  private isEditing(): boolean {
    return this.editingSession !== null;
  }

  private isPartnerEdit(): boolean {
    return this.isEditing() && this.editingSession?.viewer_role === "partner";
  }

  private isSleepPlan(): boolean {
    if (this.planKind === "sleep") {
      return true;
    }
    if (this.editingSession !== null && isSleepSchedule(this.editingSession.schedule_json)) {
      return true;
    }
    return false;
  }

  private canEditAll(): boolean {
    return (
      Boolean(this.editingSession?.editable) && this.editingSession?.viewer_role === "initiator"
    );
  }

  private canEditApps(): boolean {
    return Boolean(this.editingSession?.editable);
  }

  private getPageTitle(): string {
    if (this.isSleepPlan()) {
      return this.isEditing() ? "编辑早睡契约" : "创建早睡契约";
    }
    return this.isEditing() ? "编辑契约" : "创建契约";
  }

  private getSubmitLabel(): string {
    if (this.isSaving) {
      return this.isEditing() ? "保存中..." : "生效中...";
    }
    return this.isEditing() ? "保存修改" : "签定契约";
  }

  private hasScheduleFieldsChanged(session: DuoSessionView): boolean {
    const repeat = session.schedule_repeat ?? "";
    return (
      (session.schedule_start || "") !== this.startTime ||
      (session.schedule_end || "") !== this.endTime ||
      repeat !== this.repeatDays.join(",")
    );
  }

  private hasStartScheduleChanged(session: DuoSessionView): boolean {
    const repeat = session.schedule_repeat ?? "";
    return (
      (session.schedule_start || "") !== this.startTime || repeat !== this.repeatDays.join(",")
    );
  }

  private fillFormFromSession(session: DuoSessionView): void {
    this.planName = session.title;
    this.startTime =
      session.schedule_start && session.schedule_start.length > 0
        ? session.schedule_start
        : "09:00";
    this.endTime =
      session.schedule_end && session.schedule_end.length > 0 ? session.schedule_end : "18:00";
    this.repeatDays = getScheduleRepeatDays(session.schedule_repeat ?? "");
    this.selectedTokens = getSessionApps(session);
    this.mode = session.mode === "shield" ? "shield" : "allow";
    this.participationMode = session.participation_mode === "duo" ? "duo" : "solo";
    this.hasInitializedDefaultTime = true;
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

  private padTimePart(value: number): string {
    return value.toString().padStart(2, "0");
  }

  private formatTime(date: Date): string {
    return `${this.padTimePart(date.getHours())}:${this.padTimePart(date.getMinutes())}`;
  }

  private initDefaultTimeRange(): void {
    const now = new Date();
    const start = new Date(now.getTime());
    const end = new Date(start.getTime() + DEFAULT_SCHEDULED_PLAN_MINUTES * 60 * 1000);
    this.startTime = this.formatTime(start);
    this.endTime = this.formatTime(end);
    this.hasInitializedDefaultTime = true;
  }

  private minutesToTime(totalMinutes: number): string {
    const hour = Math.floor(totalMinutes / 60);
    const minute = totalMinutes % 60;
    return `${this.padTimePart(hour)}:${this.padTimePart(minute)}`;
  }

  private timeStringToDate(time: string): Date {
    const normalized = time.trim();
    const result = new Date();
    if (!normalized.includes(":")) {
      return result;
    }
    const parts = normalized.split(":");
    const hour = Math.min(23, Math.max(0, Math.floor(Number(parts[0]) || 0)));
    const minute = Math.min(59, Math.max(0, Math.floor(Number(parts[1]) || 0)));
    result.setHours(hour, minute, 0, 0);
    return result;
  }

  private openTimePicker(target: "start" | "end"): void {
    this.blurNameInput();
    this.timePickerTarget = target;
    this.timePickerDraft = this.timeStringToDate(
      target === "start" ? this.startTime : this.endTime,
    );
    this.timePickerVisible = true;
  }

  private confirmTimePicker(): void {
    const nextTime = this.formatTime(this.timePickerDraft);
    const uiContext = this.getUIContext();
    if (this.timePickerTarget === "start") {
      const startMin = this.timeToMinutes(nextTime);
      let endMin = startMin + DEFAULT_SCHEDULED_PLAN_MINUTES;
      if (endMin >= 24 * 60) {
        endMin -= 24 * 60;
      }
      this.startTime = nextTime;
      this.endTime = this.minutesToTime(endMin);
    } else {
      const startMin = this.timeToMinutes(this.startTime);
      const endMin = this.timeToMinutes(nextTime);
      if (endMin === startMin) {
        showErrorToast("开始时间和结束时间不能相同", uiContext);
        this.timePickerVisible = false;
        return;
      }
      if (getScheduledDurationMinutes(startMin, endMin) < MIN_SCHEDULED_PLAN_MINUTES) {
        showErrorToast(`时长至少${MIN_SCHEDULED_PLAN_MINUTES}分钟`, uiContext);
        this.timePickerVisible = false;
        return;
      }
      if (this.isSleepPlan()) {
        const sleepError = validateSleepClockWindow(startMin, endMin);
        if (sleepError.length > 0) {
          showErrorToast(sleepError, uiContext);
          this.timePickerVisible = false;
          return;
        }
      }
      this.endTime = nextTime;
    }
    this.timePickerVisible = false;
  }

  private cancelTimePicker(): void {
    this.timePickerVisible = false;
  }

  private appCardTitle(): string {
    return this.mode === "allow" ? "允许使用的应用" : "要锁定的应用";
  }

  private applyPresetFromParams(): void {
    const params = router.getParams() as PlanAddRouteParams;
    this.planKind = String(params?.kind ?? "").trim();
    const presetName = params?.presetName?.trim() ?? "";
    if (presetName.length === 0) {
      return;
    }
    this.planName = presetName;
    const presetStart = params?.presetStart?.trim() ?? "";
    const presetEnd = params?.presetEnd?.trim() ?? "";
    if (presetStart.length > 0) {
      this.startTime = presetStart;
    }
    if (presetEnd.length > 0) {
      this.endTime = presetEnd;
    }
    const presetRepeat = params?.presetRepeat?.trim() ?? "";
    if (presetRepeat.length > 0) {
      try {
        const parsed = JSON.parse(presetRepeat) as number[];
        if (Array.isArray(parsed) && parsed.length > 0) {
          this.repeatDays = [...parsed].sort((left: number, right: number) => left - right);
        }
      } catch (_error) {}
    }
    this.hasInitializedDefaultTime = true;
  }

  aboutToAppear(): void {
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    SettingsStore.hydrate(hostContext);
    UserStore.hydrate(hostContext);
    ScheduledListStore.hydrate();
    const editing = ScheduledListStore.getEditingSession();
    if (editing) {
      this.editingSession = editing;
      this.fillFormFromSession(editing);
      if (isSleepSchedule(editing.schedule_json)) {
        this.planKind = "sleep";
      }
      this.statusMessage = "";
      return;
    }
    this.editingSession = null;
    this.statusMessage = "";
    const settingsState = SettingsStore.getState();
    this.selectedTokens = [...settingsState.selectedTokens];
    this.applyPresetFromParams();
    if (this.planKind === "sleep" && !this.hasInitializedDefaultTime) {
      this.startTime = SLEEP_DEFAULT_START_CLOCK;
      this.endTime = SLEEP_DEFAULT_END_CLOCK;
      this.repeatDays = [...SLEEP_WEEKLY_REPEAT];
      this.participationMode = "solo";
      this.mode = "allow";
      if (this.planName.trim().length === 0) {
        this.planName = "早睡契约";
      }
      this.hasInitializedDefaultTime = true;
    }
    if (!this.hasInitializedDefaultTime) {
      this.initDefaultTimeRange();
    }
    this.applyDuoPartnerPick();
  }

  onPageShow(): void {
    markQuickPayForeground("plan_add");
    this.applyDuoPartnerPick();
  }

  private applyDuoPartnerPick(): void {
    const pick = takeDuoPartnerPick();
    if (!pick) {
      return;
    }
    this.duoTargetId = pick.target.trim();
    this.duoTargetName = pick.name.trim();
  }

  aboutToDisappear(): void {
    ScheduledListStore.clearEditingSession();
    this.editingSession = null;
  }

  private toggleRepeatDay(day: number): void {
    if (this.isEditing() && !this.canEditAll()) {
      return;
    }
    if (this.repeatDays.includes(day)) {
      this.repeatDays = this.repeatDays.filter((item: number) => item !== day);
      return;
    }

    this.repeatDays = [...this.repeatDays, day].sort((left, right) => left - right);
  }

  private blurNameInput(): void {
    this.nameInputController.stopEditing();
  }

  private async chooseApps(): Promise<void> {
    if (this.isEditing() && !this.canEditApps()) {
      return;
    }
    this.blurNameInput();
    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (
      !(await ensureTaskPermission(hostContext, this.getUIContext(), {
        entry_source: "scheduled_task",
        screen_name: "plans_add",
      }))
    ) {
      return;
    }

    const result = await chooseRestrictedApps(hostContext, this.selectedTokens);
    this.blurNameInput();
    if (result.data) {
      let tokens = [...result.data];
      if (this.isSleepPlan() && tokens.length > 1) {
        tokens = tokens.slice(0, 1);
        showToast("早睡契约最多选择 1 个应用", this.getUIContext());
      }
      this.selectedTokens = tokens;
      if (this.isEditing()) {
        this.statusMessage = result.message;
      } else {
        SettingsStore.updateSelectedTokens(hostContext, result.data, result.message);
      }
      return;
    }

    if (result.message.length > 0) {
      showErrorToast(result.message, this.getUIContext());
    }
  }

  private timeToMinutes(time: string): number {
    const parts = time.split(":");
    const hour = Math.floor(Number(parts[0]) || 0);
    const minute = Math.floor(Number(parts[1]) || 0);
    return hour * 60 + minute;
  }

  private async savePlan(): Promise<void> {
    if (this.isSaving) {
      return;
    }

    if (this.isEditing()) {
      await this.saveEditingSession();
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const uiContext = this.getUIContext();
    if (!UserStore.isLoggedIn()) {
      showErrorToast("请先登录后再创建契约", uiContext);
      return;
    }
    if (this.planName.trim().length === 0) {
      showErrorToast("请输入契约名称", uiContext);
      return;
    }
    ScheduledListStore.hydrate();
    if (
      !(await ensureTaskPermission(hostContext, uiContext, {
        entry_source: "scheduled_task",
        screen_name: "plans_add",
      }))
    ) {
      return;
    }
    if (!this.isSleepPlan() && this.participationMode === "duo") {
      if (
        !ensureProMembership("scheduled_duo", {
          proUnlock: true,
        })
      ) {
        return;
      }
    }

    const startMin = this.timeToMinutes(this.startTime);
    const endMin = this.timeToMinutes(this.endTime);
    if (this.isSleepPlan()) {
      const sleepError = validateSleepClockWindow(startMin, endMin);
      if (sleepError.length > 0) {
        showErrorToast(sleepError, uiContext);
        return;
      }
      if (this.selectedTokens.length > 1) {
        this.selectedTokens = this.selectedTokens.slice(0, 1);
      }
    }

    const startTimeError = validateScheduledStartTime(
      this.startTime,
      this.repeatDays,
      this.endTime,
    );
    if (!this.isSleepPlan() && startTimeError.length > 0) {
      showErrorToast(startTimeError, uiContext);
      return;
    }

    const scheduleTimeError = validateScheduledPlanTime(
      this.startTime,
      this.endTime,
      this.repeatDays,
      ScheduledListStore.getAllSessions(),
    );
    if (scheduleTimeError.length > 0) {
      showErrorToast(scheduleTimeError, uiContext);
      return;
    }

    this.isSaving = true;

    const title = this.planName.trim();
    const apps = this.isSleepPlan()
      ? this.selectedTokens.length > 0
        ? [this.selectedTokens[0]]
        : []
      : [...this.selectedTokens];
    const schedulePayload: DuoScheduledCreatePayload = {
      title,
      start: this.startTime,
      start_min: startMin,
      end: this.endTime,
      end_min: endMin,
      repeat: this.isSleepPlan() ? SLEEP_WEEKLY_REPEAT.join(",") : this.repeatDays.join(","),
      participation_mode: this.isSleepPlan() ? "solo" : this.participationMode,
      initiator_apps: apps,
      mode: this.isSleepPlan() ? "allow" : this.mode,
      kind: this.isSleepPlan() ? "sleep" : undefined,
      friend_invite_user_id:
        !this.isSleepPlan() && this.participationMode === "duo" && this.duoTargetId.length > 0
          ? this.duoTargetId
          : undefined,
    };
    const scheduleResponse = await DuoApiService.scheduledCreate(schedulePayload);
    const session = DuoApiService.parseSession(scheduleResponse);
    if (!session) {
      const failMessage = scheduleResponse.message ?? "创建契约失败";
      if (!upsellIfProSlotQuota(failMessage, "scheduled")) {
        showErrorToast(failMessage, uiContext);
      }
      this.isSaving = false;
      return;
    }
    if (!this.isSleepPlan()) {
      promptSlotUpsellIfDisabled(session.enabled, "scheduled");
    }

    const guardResult = await syncGuardForSession(hostContext, session, apps);
    if (!guardResult.ok) {
      const warningMessage =
        guardResult.message.length > 0
          ? `契约已创建，但屏时策略未挂上：${guardResult.message}`
          : "契约已创建，但屏时策略未挂上，请到「任务」页点「同步定时任务」";
      markGuardSyncIssue(hostContext, session, warningMessage);
      SettingsStore.updateStatusMessage(hostContext, warningMessage);
      showErrorToast(warningMessage, uiContext);
    } else {
      SettingsStore.updateStatusMessage(hostContext, guardResult.message);
    }

    if (session.token.length > 0) {
      DuoInviteClipboardService.dismissToken(session.token);
    }

    ScheduledListStore.markDirty();
    ScheduledListStore.setFilter("initiated");

    if (this.isSleepPlan()) {
      if (guardResult.ok) {
        showToast("早睡契约已签订", uiContext);
      }
      this.isSaving = false;
      replaceRoute(PageRoutes.SleepPlan);
      return;
    }

    if (this.participationMode === "duo") {
      const scheduleLabel = `${this.startTime} - ${this.endTime}`;
      setScheduledDuoWait(session, scheduleLabel);
      if (guardResult.ok) {
        showToast("创建成功，请邀请搭子加入", uiContext);
      }
      this.isSaving = false;
      replaceRoute(PageRoutes.DuoWait);
      return;
    }

    if (guardResult.ok) {
      showToast("契约已签订，请务必遵守", uiContext);
    }
    this.isSaving = false;
    backRoute();
  }

  private async saveEditingSession(): Promise<void> {
    const session = this.editingSession;
    if (!session) {
      return;
    }

    const hostContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const uiContext = this.getUIContext();
    if (!UserStore.isLoggedIn()) {
      showErrorToast("请先登录", uiContext);
      return;
    }

    if (session.viewer_role === "initiator") {
      if (this.planName.trim().length === 0) {
        showErrorToast("请输入契约名称", uiContext);
        return;
      }
      if (this.hasStartScheduleChanged(session)) {
        const startTimeError = validateScheduledStartTime(
          this.startTime,
          this.repeatDays,
          this.endTime,
        );
        if (startTimeError.length > 0) {
          showErrorToast(startTimeError, uiContext);
          return;
        }
      }
      if (this.hasScheduleFieldsChanged(session)) {
        ScheduledListStore.hydrate();
        if (this.isSleepPlan()) {
          const sleepError = validateSleepClockWindow(
            this.timeToMinutes(this.startTime),
            this.timeToMinutes(this.endTime),
          );
          if (sleepError.length > 0) {
            showErrorToast(sleepError, uiContext);
            return;
          }
        }
        const scheduleTimeError = validateScheduledPlanTime(
          this.startTime,
          this.endTime,
          this.repeatDays,
          ScheduledListStore.getAllSessions(),
          session.session_id,
        );
        if (scheduleTimeError.length > 0) {
          showErrorToast(scheduleTimeError, uiContext);
          return;
        }
      }
    }

    this.isSaving = true;
    if (
      !(await ensureTaskPermission(hostContext, uiContext, {
        entry_source: "scheduled_task",
        screen_name: "plans_add",
      }))
    ) {
      this.isSaving = false;
      return;
    }

    const mergedApps = mergeSessionAppsForHarmony(
      session.my_apps ?? [],
      this.isSleepPlan() && this.selectedTokens.length > 1
        ? this.selectedTokens.slice(0, 1)
        : this.selectedTokens,
    );
    const payload: DuoScheduledUpdatePayload =
      session.viewer_role === "initiator"
        ? {
            title: this.planName,
            start: this.startTime,
            start_min: this.timeToMinutes(this.startTime),
            end: this.endTime,
            end_min: this.timeToMinutes(this.endTime),
            repeat: this.isSleepPlan() ? SLEEP_WEEKLY_REPEAT.join(",") : this.repeatDays.join(","),
            mode: this.isSleepPlan() ? "allow" : this.mode,
            initiator_apps: mergedApps,
          }
        : {
            partner_apps: mergedApps,
          };

    const response = await DuoApiService.scheduledUpdate(session.session_id, payload);
    const nextSession = DuoApiService.parseSession(response);
    if (!nextSession) {
      showErrorToast(response.message ?? "保存失败", uiContext);
      this.isSaving = false;
      return;
    }

    const guardResult = await syncGuardForSession(hostContext, nextSession, this.selectedTokens);
    this.editingSession = nextSession;
    this.fillFormFromSession(nextSession);
    ScheduledListStore.patchSession(nextSession);
    const listResponse = await DuoApiService.getScheduledList();
    const list = DuoApiService.parseScheduledList(listResponse);
    if (listResponse.statusCode === 200) {
      ScheduledListStore.setAllSessions(list.items);
      ScheduledListStore.clearDirty();
    } else {
      ScheduledListStore.markDirty();
    }
    this.isSaving = false;
    ScheduledListStore.clearEditingSession();
    if (!guardResult.ok) {
      const warningMessage =
        guardResult.message.length > 0
          ? `已保存，但屏时策略未挂上：${guardResult.message}`
          : "已保存，但屏时策略未挂上，请到「任务」页点「同步定时任务」";
      markGuardSyncIssue(hostContext, nextSession, warningMessage);
      this.statusMessage = warningMessage;
      showErrorToast(warningMessage, uiContext);
    } else {
      this.statusMessage = "";
      showToast("已保存", uiContext);
    }
    if (this.isSleepPlan()) {
      replaceRoute(PageRoutes.SleepPlan);
      return;
    }
    backRoute();
  }

  @Builder
  buildParticipationCard(): void {
    Column() {
      Row() {
        Text("履约方式")
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Row({ space: 0 }) {
          Text("单人专注")
            .fontSize(13)
            .fontColor(
              this.participationMode === "solo"
                ? AppTheme.colors.textPrimary
                : AppTheme.colors.textSecondary,
            )
            .fontWeight(this.participationMode === "solo" ? FontWeight.Medium : FontWeight.Regular)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(8)
            .backgroundColor(
              this.participationMode === "solo" ? AppTheme.colors.surfaceRaised : Color.Transparent,
            )
            .onClick(() => {
              this.participationMode = "solo";
            })
          Text("搭子互督")
            .fontSize(13)
            .fontColor(
              this.participationMode === "duo"
                ? AppTheme.colors.textPrimary
                : AppTheme.colors.textSecondary,
            )
            .fontWeight(this.participationMode === "duo" ? FontWeight.Medium : FontWeight.Regular)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(8)
            .backgroundColor(
              this.participationMode === "duo" ? AppTheme.colors.surfaceRaised : Color.Transparent,
            )
            .onClick(() => {
              this.participationMode = "duo";
            })
        }
        .padding(2)
        .border({ width: 1, color: AppTheme.colors.border })
        .borderRadius(10)
        .backgroundColor(AppTheme.colors.surface)
      }
      .width("100%")
      .padding({ left: 18, right: 18, top: 18, bottom: 12 })
      .alignItems(VerticalAlign.Center)
      Text(
        this.participationMode === "duo"
          ? "保存后邀请搭子，到点双方一起履约。"
          : "仅自己按时段履约，适合固定学习节奏。",
      )
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .width("100%")
        .padding({ left: 18, right: 18, bottom: 18 })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true);
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
  buildNameCard(): void {
    Row() {
      Text("契约名称")
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
      TextInput({
        text: this.planName,
        placeholder: "请输入",
        controller: this.nameInputController,
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
    .width("100%")
    .constraintSize({ minHeight: 58 })
    .padding({ left: 18, right: 18, top: 8, bottom: 8 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true);
  }

  @Builder
  buildTimeCard(): void {
    Column({ space: 10 }) {
      Row() {
        Text("起始时间")
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
              this.openTimePicker("start");
            })
          Text("至")
            .fontSize(14)
            .fontColor(AppTheme.colors.textSecondary)
          Text(this.endTime)
            .fontSize(15)
            .fontColor(AppTheme.colors.textPrimary)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(8)
            .backgroundColor(AppTheme.colors.surfaceRaised)
            .onClick(() => {
              this.openTimePicker("end");
            })
        }.alignItems(VerticalAlign.Center)
      }
      .width("100%")
      .alignItems(VerticalAlign.Center)

      if (this.isSleepPlan()) {
        Text("入睡 21:00–23:30，起床 05:00–08:30")
          .fontSize(13)
          .lineHeight(19)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%");
      }
    }
    .width("100%")
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true);
  }

  @Builder
  buildAppCard(): void {
    Column() {
      Row() {
        Text(this.appCardTitle())
          .layoutWeight(1)
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Row({ space: 4 }) {
          SymbolGlyph($r("sys.symbol.plus"))
            .fontSize(14)
            .fontColor([AppTheme.colors.textMuted])
          Text("选择")
            .fontSize(13)
            .fontColor(AppTheme.colors.textSecondary)
        }
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor(AppTheme.colors.surfaceRaised)
        .onClick(() => {
          this.chooseApps();
        })
      }
      .width("100%")
      .padding({ left: 18, right: 18, top: 18, bottom: 8 })
      .alignItems(VerticalAlign.Center)
      Text(
        this.selectedTokens.length === 0
          ? "未选择应用"
          : `已选 ${this.selectedTokens.length} 个应用`,
      )
        .fontSize(14)
        .fontColor(AppTheme.colors.textMuted)
        .width("100%")
        .padding({
          left: 18,
          right: 18,
          bottom: this.shouldShowStatusLine() ? 8 : 18,
        })

      if (this.shouldShowStatusLine()) {
        Text(this.statusMessage)
          .fontSize(12)
          .fontColor(AppTheme.colors.textSecondary)
          .width("100%")
          .padding({ left: 18, right: 18, bottom: 18 });
      }
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true);
  }

  @Builder
  buildRepeatDaysCard(): void {
    Column() {
      Row() {
        Text("每周几重复")
          .fontSize(16)
          .fontColor(AppTheme.colors.textPrimary)
        Blank()
        Text(`已选${this.repeatDays.length}天`)
          .fontSize(14)
          .fontColor(AppTheme.colors.textMuted)
      }
      .width("100%")
      .padding({ left: 18, right: 18, top: 18, bottom: 8 })
      Row({ space: 8 }) {
        ForEach(
          this.dayOptions,
          (item: number) => {
            Stack() {
              Text(getRepeatDayShortLabel(item))
                .fontSize(15)
                .fontColor(this.repeatDays.includes(item) ? "#FFFFFF" : AppTheme.colors.textPrimary)
            }
            .width(38)
            .height(38)
            .borderRadius(19)
            .clip(true)
            .backgroundColor(
              this.repeatDays.includes(item) ? AppTheme.colors.primary : AppTheme.colors.border,
            )
            .onClick(() => {
              this.toggleRepeatDay(item);
            });
          },
          (item: number) => item.toString(),
        )
      }
      .width("100%")
      .padding({ left: 18, right: 18, top: 8, bottom: 20 })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .clip(true);
  }

  @Builder
  buildPartnerPickCard(): void {
    Row() {
      Text("指定搭子")
        .fontSize(16)
        .fontColor(AppTheme.colors.textPrimary)
      Blank()
      Text(this.duoTargetName.length > 0 ? this.duoTargetName : "邀请码 / 链接邀请")
        .fontSize(14)
        .fontColor(AppTheme.colors.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      SymbolGlyph($r("sys.symbol.chevron_right"))
        .fontSize(16)
        .fontColor([AppTheme.colors.textMuted])
    }
    .width("100%")
    .height(56)
    .padding({ left: 18, right: 18 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(AppTheme.colors.surface)
    .borderRadius(AppTheme.radius.lg)
    .border({ width: 1, color: AppTheme.colors.border })
    .onClick(() => {
      pushDuoPickFriend(this.duoTargetId);
    });
  }

  @Builder
  buildContractBody(): void {
    Column({ space: 18 }) {
      if (!this.isPartnerEdit()) {
        this.buildNameCard();
        if (!this.isEditing() && SHOW_PARTICIPATION_MODE) {
          this.buildParticipationCard();
        }
        if (!this.isEditing() && SHOW_PARTICIPATION_MODE && this.participationMode === "duo") {
          this.buildPartnerPickCard();
        }
        this.buildTimeCard();
      }
      this.buildAppCard()
      if (!this.isPartnerEdit() && !this.isSleepPlan()) {
        this.buildRepeatDaysCard();
      }
      Button(this.getSubmitLabel())
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
        .enabled(!this.isSaving)
        .opacity(this.isSaving ? 0.7 : 1)
        .margin({ top: 12 })
        .onClick(() => {
          void this.savePlan();
        })
    }
    .width("100%")
    .alignItems(HorizontalAlign.Start);
  }

  @Builder
  private buildTimePickerSheet(): void {
    Column({ space: 18 }) {
      Text(this.timePickerTarget === "start" ? "选择开始时间" : "选择结束时间")
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppTheme.colors.textPrimary)
        .width("100%")
        .textAlign(TextAlign.Center)
      TimePicker({
        selected: this.timePickerDraft,
        format: TimePickerFormat.HOUR_MINUTE,
      })
        .width("100%")
        .useMilitaryTime(true)
        .onChange((value: PlanTimePickerResult) => {
          const next = new Date(this.timePickerDraft);
          next.setHours(value.hour, value.minute, 0, 0);
          this.timePickerDraft = next;
        })
      Row({ space: 12 }) {
        Button("取消")
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
        Button("确定")
          .layoutWeight(1)
          .height(48)
          .type(ButtonType.Normal)
          .buttonStyle(ButtonStyleMode.NORMAL)
          .borderRadius(AppTheme.radius.button)
          .clip(true)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor("#FFFFFF")
          .backgroundColor(AppTheme.colors.primary)
          .onClick(() => {
            this.confirmTimePicker();
          })
      }.width("100%")
    }
    .width("100%")
    .padding({
      left: 20,
      right: 20,
      top: 20,
      bottom: 28,
    });
  }

  build() {
    Stack() {
      ProQuickPayHost({ hostId: "plan_add" })
      SystemNavPage({
        title: this.getPageTitle(),
        showBack: true,
        usePageScroll: true,
        bottomSpacerHeight: 28,
        onBack: () => {
          ScheduledListStore.clearEditingSession();
          backRoute();
        },
        content: (): void => {
          this.buildContractBody();
        },
      })
      Column()
        .width(0)
        .height(0)
        .bindSheet($$this.timePickerVisible, this.buildTimePickerSheet(), {
          height: SheetSize.FIT_CONTENT,
          preferType: SheetType.BOTTOM,
          showClose: false,
          dragBar: true,
          backgroundColor: AppTheme.colors.backgroundSoft,
        })
    }
    .width("100%")
    .height("100%");
  }
}
